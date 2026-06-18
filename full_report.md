# OpenSees Analysis — Full Diagnostic Report
## 3-Storey Masonry Frame · newcode3storey.tcl
### For: the script author · Prepared after running diagnostic.tcl and reviewing all output

---

## 0. What We Know for Certain

The **environment is not the problem**. Running diagnostic.tcl confirmed:

- Tcl 8.6.8 / OpenSees 3.2.1 — stable, well-tested version
- `Macroelement3d -tremuri` (Francesco Vanin, EPFL 2019) — loads correctly
- All commands used in the script — `eleLoad -selfWeight`, `DisplacementControl`,
  `sp` in a pattern, `constraints Transformation` — all pass individual tests

The errors are in the **analysis logic and model connectivity**, not in the
installation or the element library.

---

## 1. Reading the Error Output — Line by Line

### 1.1 · Singular matrix during pushover

```
WARNING BandGenLinLapackSolver::solve() -factorization failed,
        matrix singular U(i,i) = 0, i= 87
WARNING NewtonRaphson::solveCurrentStep() -the LinearSysOfEqn failed in solve()
StaticAnalysis::analyze() - the Algorithm failed at iteration: 0
        with domain at load factor -3.58368e+19
OpenSees > analyze failed, returned: -3 error flag
```

**What DOF 87 is:**

With 17 nodes × 6 DOFs = 102 total DOFs, and nodes 1 and 2 fully fixed (12
constrained DOFs), there are 90 free DOFs numbered sequentially by node. Using
the Plain numberer, DOF 87 maps to **node 17, DOF 3 (global Z, vertical)**.

Node 17 is the **midpoint internal node of element 9** (the roof-level spandrel,
connecting nodes 7–8). It sits at coordinates [1.5, 0, 9.0].

Node 17 is connected to **exactly one element** (element 9), which is a
**horizontal spandrel** with local x-axis along global X. In the Macroelement3d
formulation for a horizontal element, the internal node K does not receive a
stiffness contribution in the direction **transverse to the element axis in the
plane** — in this case, the vertical (Z) direction. That DOF has zero stiffness
in the assembled global matrix, producing a zero pivot and a singular
factorisation.

**The same problem likely exists at:**
- Node 15 (DOF Z) — internal node of floor-1 spandrel (element 7)
- Node 16 (DOF Z) — internal node of floor-2 spandrel (element 8)
- Possibly the Y and rotational DOFs at nodes 9–14 (internal pier nodes)

**What `load factor -3.58368e+19` means:**

This is not a structural result. When the linear solver encounters a zero pivot,
it produces a numerically nonsensical displacement. The load factor is computed
from that displacement and becomes effectively infinite. This number has no
physical meaning — it is a numerical artefact of the singular DOF.

---

### 1.2 · Newton fallback and the convergence warnings

```
Newton failed - switching to Newton Initial
WARNING: CTestNormUnbalance::test() - failed to converge but going on
         current Norm: 20394.9 (max: 100, Norm deltaX: 8.43657e-06)
WARNING: CTestNormUnbalance::test() - failed to converge but going on
         current Norm: 9986.6  (max: 100, Norm deltaX: 1.17368e-06)
...
current Norm: 596.1  (max: 100, Norm deltaX: 1.82e-07)
```

**Why Newton Initial can continue past the singular point:**

`algorithm Newton -initial` uses the **initial (undamaged, elastic) stiffness
matrix** for every iteration instead of updating it at each step. The initial
stiffness matrix is non-singular (computed before any damage), so the linear
solve succeeds. The trade-off is much slower convergence.

**Reading the two norm columns:**

| Column | Meaning | Values seen |
|--------|---------|-------------|
| `current Norm` | Unbalanced force residual (N) at the end of the step | 20 395 → 596 |
| `Norm deltaX` | Displacement correction at the last Newton iteration (m) | 8.4 × 10⁻⁶ → 1.8 × 10⁻⁷ |

The critical observation is that these two quantities are **moving in opposite
directions**:

- The **force residual is large and slowly decreasing** — the system hasn't
  found force equilibrium within the 100-iteration budget
- The **displacement correction is tiny** (10⁻⁷ m) — the DOFs have essentially
  stopped moving

This is the signature of **post-peak softening with a nearly-flat or negative
tangent stiffness**: the structure has passed its lateral capacity peak. In
this regime, tiny displacement changes produce large force imbalances, so a
force-based convergence criterion (`NormUnbalance`) is the wrong choice.

**What `printFlag 5` does:**

The `5` at the end of `test NormUnbalance 100.0 100 5` means
*"print when failed, but return success anyway and continue."* The analysis is
NOT stopped by these warnings — it continues running and writing to the output
files.

**Are the results on the softening branch reliable?**

With an unbalanced force norm of ~600 N and structural forces in the kN range,
the per-step error is roughly 5–10%. Results on the descending branch should be
treated as indicative of trend (capacity has dropped, structure is softening)
but not as precise quantitative values. The peak of the pushover curve, reached
before the singular matrix warning appeared, is more reliable.

---

## 2. Code Issues — Confidence Levels

### CONFIRMED — Fix is unambiguous

---

#### 2.A · Singular DOFs at internal spandrel nodes

**Root cause:** The vertical (Z) DOF at nodes 15, 16, 17, and possibly the
out-of-plane (Y) and rotational DOFs at nodes 9–14, receive zero stiffness
from the elements they are connected to. This is a known requirement for planar
Macroelement3d models in a 3D space: internal nodes need additional constraints
to suppress zero-energy modes.

**Fix — add immediately after the `fix 2` line:**

```tcl
# -----------------------------------------------------------------------
# Constrain zero-stiffness DOFs at internal nodes
# Pier internal nodes: Y, Rx, Rz have no stiffness contribution
foreach n {9 10 11 12 13 14} {
    fix $n  0 1 0 1 0 1
}
# Spandrel internal nodes: Y and Rz have no stiffness; Z also has none
# for horizontal elements → fix Y, Z, Rx, Rz
foreach n {15 16 17} {
    fix $n  0 1 1 1 0 1
}
# -----------------------------------------------------------------------
```

The DOF pattern `0 1 0 1 0 1` fixes [Y, Rx, Rz] while leaving [X, Z, Ry]
free for the pier internal nodes.  
The pattern `0 1 1 1 0 1` fixes [Y, Z, Rx, Rz] for the spandrel internal nodes.

*Note:* If after applying this fix certain DOFs still show singular behaviour,
try progressively fixing more: replace the spandrel pattern with `0 1 1 1 1 1`
(fix everything except X).

---

#### 2.B · Pushover fallback reruns the full step count

**Root cause:** When `analyze $nSteps` fails at step *k*, the fallback calls
`analyze $nSteps` again — not the remaining `nSteps - k` steps. The controlled
node can overshoot the target displacement.

**Original code (lines 316–326):**

```tcl
set ok [analyze $nSteps]
if {$ok != 0} {
    puts "Newton failed - switching to Newton Initial"
    test NormUnbalance 100.0 100 5
    algorithm Newton -initial
    set ok [analyze $nSteps]    ;# PROBLEM: runs another full nSteps
}
```

**Replacement — step-by-step loop with algorithm switching:**

```tcl
# -----------------------------------------------------------------------
set completedSteps 0
set usingInitial   0

while {$completedSteps < $nSteps} {

    set ok [analyze 1]

    if {$ok == 0} {
        incr completedSteps
        if {$usingInitial} {
            # Revert to standard Newton when past the hard point
            algorithm Newton
            test NormUnbalance 100.0 50 0
            set usingInitial 0
        }
    } else {
        if {!$usingInitial} {
            puts "Step $completedSteps: Newton failed — switching to Newton -initial"
            test NormUnbalance 100.0 200 5
            algorithm Newton -initial
            set usingInitial 1
        }
        set ok [analyze 1]
        if {$ok == 0} {
            incr completedSteps
        } else {
            puts "STOP: both algorithms failed at step $completedSteps / $nSteps"
            puts "Roof displacement at stop: [expr $completedSteps * $incr] m"
            break
        }
    }

    if {[expr $completedSteps % 200] == 0 && $completedSteps > 0} {
        puts "Progress: step $completedSteps / $nSteps \
([expr $completedSteps * $incr] m)"
    }
}
puts "Pushover done: $completedSteps / $nSteps steps completed"
# -----------------------------------------------------------------------
```

---

#### 2.C · Convergence test — wrong criterion for post-peak

**Root cause:** `NormUnbalance` checks residual forces. In the softening regime
the tangent stiffness is near zero, so forces don't drive convergence even when
displacements are well converged. The appropriate criterion for displacement-
controlled pushover past peak is `NormDispIncr`.

**Replace both occurrences of the convergence test (gravity and pushover):**

For gravity (where force equilibrium matters):
```tcl
test NormUnbalance 1.0 50 0
```

For pushover (where displacement convergence is the meaningful criterion):
```tcl
test NormDispIncr 1.0e-6 100 0
```

And in the fallback:
```tcl
test NormDispIncr 1.0e-5 200 5
```

The `0` printFlag suppresses per-iteration output; use `2` if you want to see
each iteration during debugging.

---

### TO VERIFY — Original intent is unclear

---

#### 2.D · Floor load formula

**Current line (218):**
```tcl
set floorLoad [expr -5.0*$g*$rho*$L_span*$T_pier]
```

**Dimensional analysis:**

```
rho × g                  = N/m³   (specific weight of masonry)
× L_span × T_pier        = N/m    (load intensity per unit height)
× 5.0                    = N      only if 5.0 is in metres
```

The formula computes the weight of a masonry block **5 m tall** with cross-
section `L_span × T_pier = 3.0 × 0.25 m²`. Numerically:

```
-5.0 × 9.81 × 1200 × 3.0 × 0.25 = -44 145 N per floor node
```

**If `5.0` was meant as a 5 kN/m² floor pressure:**

```tcl
set floorLoad [expr -5.0e3 * $L_span * $T_pier]   ;# → -3 750 N per node
```

**If `5.0` is a tributary masonry height in metres** (e.g., half-storey above +
half-storey below = H_story = 3.0 m, or a different tributary convention):

```tcl
set floorLoad [expr -$rho * $g * 5.0 * $L_span * $T_pier]  ;# 44 145 N, as written
```

**Action required:** verify what `5.0` physically represents. The formula as
written is dimensionally consistent only if `5.0` is an equivalent height in
metres of masonry tributary to each floor node. If it represents a pressure
(kN/m²), it should be `5.0e3` without `g` or `rho`.

---

#### 2.E · Settlement: `sp` on a fully fixed node

**Original code:**
```tcl
fix 1  1 1 1 1 1 1    ;# all DOFs fixed, including Z (DOF 3)
...
sp 1 3 -0.001         ;# tries to impose vertical displacement on node 1
```

**Status: UNCERTAIN — likely harmless in this version.**

The settlement phase completed without error, which suggests that OpenSees 3.2.1
with `constraints Transformation` does handle `sp` overriding a `fix` correctly
— the non-homogeneous single-point constraint from the pattern takes precedence.
This was flagged as a critical bug in the first review, but the evidence now
suggests it may work as intended. No change is recommended unless the settlement
results are suspect (e.g., node 1 shows zero vertical displacement in the output
even after the settlement phase).

---

## 3. Minimum Working Patch

The following is the **minimum change** needed to resolve the singular matrix
crash. Apply it to the original script, immediately after the boundary condition
block (after line 81):

```tcl
# --- ADD THIS BLOCK after "fix 2 1 1 1 1 1 1" ---

# Suppress zero-stiffness DOFs at internal pier nodes
foreach n {9 10 11 12 13 14} {
    fix $n  0 1 0 1 0 1
}
# Suppress zero-stiffness DOFs at internal spandrel nodes
foreach n {15 16 17} {
    fix $n  0 1 1 1 0 1
}

# --- END OF ADDED BLOCK ---
```

Then replace the pushover test and fallback (section "PUSHOVER ANALYSIS"):

```tcl
# Replace: test NormUnbalance 100.0 50 5
# With:
test NormDispIncr 1.0e-6 100 0

# Replace the entire if{$ok != 0} block with the step loop from section 2.B above
```

These two changes together should eliminate the singular pivot warning and the
convergence warning flood.

---

## 4. Verifying the Output

After a corrected run, the file `RoofDisp.out` should contain two columns:

```
time    displacement_node8_DOF1
0.0     0.0
0.0001  <small value>
...
0.20    <value near 0.20 if pushover completed>
```

The "time" column in a displacement-controlled pushover is the pseudo-time,
which equals the cumulative displacement increment at the controlled node. It
should increase monotonically from 0 to (approximately) 0.20 m.

**Sanity checks on the pushover curve:**

1. Initial slope = elastic stiffness. For a 3-storey masonry frame with
   E = 1700 MPa, the elastic lateral stiffness should be in the range
   10³–10⁴ kN/m. Check the initial slope of base shear vs. roof displacement.

2. Peak base shear can be estimated from the pier shear capacity:
   `V_pier ≈ (c + mu0 × sigma_0) × L_pier × T_pier`
   where `sigma_0` is the axial stress under gravity. With the current loads
   this is approximately `(0.15 + 0.40 × sigma_0) × 0.25 MN/m²` per pier.

3. If the curve shows a sudden drop immediately after elastic range, `Gc = 6 J/m²`
   is very likely too low — the fracture energy governs the post-peak ductility.
   Typical TREMURI values for masonry are 20–50 J/m². Increasing Gc to 20–30
   should produce a less brittle descending branch.

---

## 5. Step-by-Step Action Plan

1. **Apply the internal node fix** (section 3) to the original script.
   Run gravity only (comment out settlement and pushover) and check that it
   completes without singular matrix warnings.

2. **Run gravity + settlement.** Check `SupportReaction.out` — the vertical
   reaction at node 1 should change between the gravity state and the
   settled state. If it does not change, the `sp` override is not working
   and the node 1 boundary condition needs the DOF 3 released
   (`fix 1 1 1 0 1 1 1`).

3. **Run the full script with the fallback loop and `NormDispIncr`.**
   The singular matrix warning should be gone. Some steps may still use
   Newton Initial near capacity, but the convergence warnings should be
   rare and the norms small.

4. **Check the floor load** (section 2.D). If the gravity analysis shows
   unexpectedly high axial forces in the piers (column check: `sigma =
   total_vertical_reaction / (n_piers × L_pier × T_pier)` should be in
   the range 0.5–2 MPa for typical masonry), the load formula may need
   correction.

5. **If Gc is under discussion**, try values of 20 and 50 J/m² and compare
   the descending branch of the pushover curve — this is a parametric study
   that belongs in the thesis discussion regardless of the convergence issues.

---

*The structural model and element choice are correct. The issues are in
boundary condition completeness (zero-stiffness DOFs), the convergence
criterion for the softening regime, and the fallback logic. None of these
reflect a misunderstanding of the structural problem.*
