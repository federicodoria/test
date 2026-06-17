# OpenSees Script Review — 3-Storey Masonry Frame
*Code review for: newcode3storey.tcl*

---

## Foreword

The structure of this script is solid and the modelling approach is correct —
Macroelement3d for piers and spandrels, three analysis phases (gravity →
settlement → pushover), displacement control with a Newton fallback. The issues
below are the kind of subtle traps that catch experienced OpenSees users too,
mostly because the framework is flexible enough to accept commands silently even
when they have no effect. Nothing here reflects a gap in understanding of the
structural problem — it is purely OpenSees bookkeeping.

The note on version and extensions matters: two of the items below may or may
not apply depending on the exact Macroelement3d implementation in use, and
those are flagged explicitly.

---

## Critical Issues

These three items will either produce silently wrong results or cause the
pushover to run past its intended target.

---

### 1 — Foundation Settlement Is Never Applied
**Lines 80–81 and 258**

```tcl
fix 1  1 1 1 1 1 1    ;# node 1: ALL six DOFs locked, including vertical (DOF 3)
...
pattern Plain 20 Linear {
    sp 1 3 -0.001     ;# tries to impose a vertical displacement on node 1
}
```

With the `Transformation` constraint handler (used throughout the script), fixed
DOFs are eliminated from the system of equations before the solver runs. The
`sp` command inside the pattern therefore has nothing to act on — the settlement
is accepted without error but never actually applied.

The fix is to leave the vertical DOF of node 1 free, while keeping everything
else locked:

```tcl
fix 1  1 1 0 1 1 1    ;# DOF 3 (Z, vertical) is now free for settlement
fix 2  1 1 1 1 1 1    ;# node 2 remains fully fixed
```

After the settlement phase, if a permanent settlement is desired, the vertical
DOF can be re-fixed or left free depending on the intended boundary condition
for the pushover.

---

### 2 — Floor Load Formula Produces Values ~12× Too Large
**Line 218**

```tcl
set floorLoad [expr -5.0*$g*$rho*$L_span*$T_pier]
```

Working through the units with SI (N, m, kg):

```
rho × g             →  N/m³   (specific weight of masonry)
× L_span × T_pier   →  N/m    (load per metre of height)
× 5.0               →  N      (only if 5.0 is a height in metres)
```

So the formula computes the weight of a masonry block **5 metres tall**, with
cross-section `L_span × T_pier`. Since `H_story = 3.0 m`, this is larger than
one full storey of masonry applied at every single floor node — approximately
44 100 N per node. The structure is therefore pre-loaded far beyond its
gravitational state before the pushover even begins.

If the intent was a **5 kN/m² floor live/dead load** (a common value), the
correct line is:

```tcl
set floorLoad [expr -5.0e3 * $L_span * $T_pier]
;# → -3 750 N per node
```

If the intent was the **self-weight of the masonry wall** above each floor
(tributary height = H_story/2 above + H_story/2 below = H_story), it should be:

```tcl
set floorLoad [expr -$rho * $g * $H_story * $L_span * $T_pier]
;# → -26 487 N per node  (one full storey of wall weight)
```

The right formula depends on what those nodal loads are meant to represent.
Either way, `5.0 * rho * g` in this context does not correspond to a standard
physical quantity.

---

### 3 — Pushover Fallback Overshoots the Target Displacement
**Lines 316–326**

```tcl
set nSteps [expr int($targetDisp/$incr)]   ;# = 2000 steps

set ok [analyze $nSteps]                   ;# runs up to 2000 steps, fails at step k

if {$ok != 0} {
    algorithm Newton -initial
    set ok [analyze $nSteps]               ;# runs ANOTHER 2000 steps from step k
}
```

If the first block fails after, say, 1 500 of 2 000 steps, the controlled node
is already at 0.15 m of displacement. The fallback then requests 2 000 more
steps, potentially driving the roof to 0.35 m — well past the 0.20 m target.
The output file will contain a trajectory that extends far beyond the intended
pushover range.

A step-by-step loop is more reliable and also allows the algorithm to switch
back to standard Newton once a difficult step is passed:

```tcl
set completedSteps 0

while {$completedSteps < $nSteps} {

    set ok [analyze 1]

    if {$ok == 0} {
        incr completedSteps
    } else {
        puts "Newton failed at step $completedSteps — trying Newton -initial"
        test  NormUnbalance 100.0 200 5
        algorithm Newton -initial
        set ok [analyze 1]

        if {$ok == 0} {
            incr completedSteps
            algorithm Newton            ;# revert to standard Newton
            test NormUnbalance 100.0 50 5
        } else {
            puts "Analysis stopped at step $completedSteps / $nSteps"
            break
        }
    }
}

puts "Pushover completed: $completedSteps of $nSteps steps."
```

---

## Significant Issues

These will not necessarily crash the analysis, but they affect the accuracy of
the results and should be checked.

---

### 4 — Possible Double-Counting of Self-Weight
**Line 223 — version-dependent**

```tcl
element Macroelement3d 1 ... -density $rho -cmass
...
eleLoad -ele $e -type -selfWeight 0.0 0.0 [expr -$g]
```

The `-density` flag tells the element its mass density (used to build the
consistent mass matrix via `-cmass`). The `eleLoad -selfWeight` separately
applies a body-force acceleration to each element.

In some Macroelement3d implementations, `-density` is used **only** for the
mass matrix (dynamic analysis), so `eleLoad -selfWeight` is the correct way to
apply static gravity. In others, the element automatically generates gravity
loads from its density, making the `eleLoad` redundant and the self-weight
double-counted.

**Action:** Check the documentation or source of the specific Macroelement3d
version in use. If self-weight appears as gravity reactions roughly twice the
expected value after the gravity phase, this is the cause.

---

### 5 — Internal Spandrel Nodes Receive No Floor Load
**Lines 226–233**

```tcl
load 3  0.0 0.0 $floorLoad 0.0 0.0 0.0
load 4  0.0 0.0 $floorLoad 0.0 0.0 0.0
;# nodes 15, 16, 17 (spandrel midpoints) receive nothing
```

Nodes 15, 16, and 17 are the midpoint internal nodes of the three spandrel
elements. If `-density` and `-cmass` are active, these nodes carry mass. The
`eleLoad -selfWeight` distributes gravity body forces to them through the
consistent mass matrix, but any **additional floor loads** (live load, slab
weight not included in self-weight) are missing at these nodes.

If the floor loads at nodes 3–8 represent only structural self-weight, this is
not an issue. If they represent superimposed loads from slabs or occupancy, a
proportional share should go to nodes 15–17 as well.

---

### 6 — Convergence Tolerance May Be Too Tight for Nonlinear Analysis
**Lines 240 and 296**

```tcl
test NormUnbalance 100.0 50 5
```

A tolerance of 100 N on the unbalanced force norm is an absolute criterion.
With axial pier capacities on the order of
`fc × A = 6×10⁶ × (1.0 × 0.25) = 1.5 MN`, this is extremely strict (0.007 %
of capacity). Near yield or after cracking, the Newton-Raphson iterations may
struggle to reach this tolerance within 50 iterations, causing premature
divergence even when the structural solution is physically well-behaved.

Consider loosening slightly, or switching to a relative criterion:

```tcl
test RelativeNormUnbalance 1.0e-4 100 5
```

This checks the ratio of current residual to initial residual, which is more
robust across the range of a pushover.

---

## Minor Points

---

### 7 — Shear Modulus Implies an Unusually High Poisson's Ratio
**Lines 24–26**

```tcl
set E  1700.0e6   ;# 1 700 MPa
set G   550.0e6   ;#   550 MPa
```

From the elastic relation `G = E / (2(1+ν))`, the implied Poisson's ratio is:

```
ν = E/(2G) − 1 = 1700 / (2 × 550) − 1 ≈ 0.55
```

Typical masonry values are `ν ≈ 0.15–0.20`, which for `E = 1 700 MPa` gives
`G ≈ 739 MPa`. A value of `G = 550 MPa` is sometimes used as a *cracked*
shear stiffness (roughly `0.3–0.4 × G_elastic`), which is a legitimate
modelling choice — but it is worth confirming this is intentional and consistent
with the reference source for these material properties.

---

### 8 — Fracture Energy `Gc = 6 J/m²` Is on the Low End
**Line 29**

```tcl
set Gc  6.0
```

Mode-II fracture energy for masonry in the Macroelement3d/TREMURI formulation is
typically in the range `20–100 J/m²`. A value of `6 J/m²` will produce a very
brittle post-peak response — a sharp, steep drop on the pushover curve
immediately after peak force. This is not necessarily wrong, but if the curve
shows an unrealistically abrupt capacity loss, `Gc` is the first parameter to
revisit.

---

### 9 — No Element Recorders Defined
**Lines 200–211**

Only nodal displacement and base reaction are recorded. Without element
recorders it is not possible to know which piers or spandrels have cracked or
yielded, or where in the structure damage concentrates. Adding at least:

```tcl
recorder Element -file PierForces.out  -time -ele 1 2 3 4 5 6  basicForce
recorder Element -file SpanForces.out  -time -ele 7 8 9        basicForce
```

will make it much easier to interpret the pushover curve and diagnose any
unusual behaviour.

---

## Summary Table

| # | Lines | Severity | Issue | Suggested fix |
|---|-------|----------|-------|---------------|
| 1 | 80, 258 | **Critical** | Fixed node: settlement never applied | Release DOF 3 on node 1 |
| 2 | 218 | **Critical** | Floor load ~12× too large (unit mismatch) | Use `5.0e3 * L_span * T_pier` or equivalent |
| 3 | 316–326 | **Critical** | Fallback reruns full step count, overshoots target | Replace with step-by-step loop |
| 4 | 223 | Significant | Possible double self-weight (version-dependent) | Check Macroelement3d docs |
| 5 | 226–233 | Significant | Spandrel midpoint nodes have no floor load | Add loads at nodes 15, 16, 17 |
| 6 | 240, 296 | Significant | Absolute tolerance may be too tight post-cracking | Switch to `RelativeNormUnbalance` |
| 7 | 24–26 | Minor | G/E implies ν ≈ 0.55 vs. typical 0.15–0.20 | Verify source of material data |
| 8 | 29 | Minor | `Gc = 6 J/m²` → very brittle post-peak | Check against experimental reference |
| 9 | 200–211 | Minor | No element recorders | Add `recorder Element` for piers and spandrels |

---

*Issues 1, 2, and 3 are the most likely explanation for incorrect or unexpected
results. Fixing these three will substantially change the output and should be
the first priority before revisiting material parameters or convergence settings.*
