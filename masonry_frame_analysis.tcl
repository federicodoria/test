# --------------------------------------------------------------------------------------------------
# MASONRY FRAME ANALYSIS WITH SETTLEMENT AND PUSHOVER
# --------------------------------------------------------------------------------------------------

wipe;
model basic -ndm 3 -ndf 6;

# --- GEOMETRY ---
set H_pier 3.0
set L_pier 1.0
set T_pier 0.25
set L_span 3.0
set H_span 0.80

# --- MATERIALS ---
set E    1700.0e+06
set G     550.0e+06
set fc      6.0e+06
set c       0.150e+06
set Gc      6.0
set mu0     0.40
set beta    0.30
set rho  1200.0
set g       9.81

# --- NODES ---
# All nodes in the XZ plane (Y=0), except node 1 and 2 which are base nodes
node 1  0.0        0.0  0.0
node 2  $L_span    0.0  0.0
node 3  0.0        0.0  $H_pier
node 4  $L_span    0.0  $H_pier
node 5  0.0        0.0  [expr $H_pier/2.0]
node 6  $L_span    0.0  [expr $H_pier/2.0]
node 7  [expr $L_span/2.0]  0.0  $H_pier

# --- ELEMENTS ---
# Pier 1 (left):  base=1, top=3, internal=5  — local x along Z (vertical), local y along Y
element Macroelement3d 1  1 3 5  0.0 0.0 1.0  0.0 1.0 0.0  -tremuri $H_pier $L_pier $T_pier $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass -pDelta

# Pier 2 (right): base=2, top=4, internal=6
element Macroelement3d 2  2 4 6  0.0 0.0 1.0  0.0 1.0 0.0  -tremuri $H_pier $L_pier $T_pier $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass -pDelta

# Spandrel:       left=3, right=4, internal=7 — local x along X (horizontal), local y along Z
element Macroelement3d 3  3 4 7  1.0 0.0 0.0  0.0 0.0 1.0  -tremuri $H_span $L_span $T_pier $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass -pDelta

# --- STAGE 1: GRAVITY ANALYSIS ---
fix 1  1 1 1 1 1 1
fix 2  1 1 1 1 1 1

pattern Plain 10 Linear {
    load 3  0.0 0.0 [expr -5.0*$g*$rho*$L_span*$T_pier]  0.0 0.0 0.0
    load 4  0.0 0.0 [expr -5.0*$g*$rho*$L_span*$T_pier]  0.0 0.0 0.0
}
constraints Transformation
numberer    Plain
system      BandGeneral
algorithm   Newton
test        NormDispIncr 1.0e-6 50 0
integrator  LoadControl 1.0
analysis    Static
analyze     1
loadConst   -time 0.0

# --- STAGE 2: SETTLEMENT ---
wipeAnalysis

# Remove only DOF 3 (vertical) SP constraint from node 2 to allow imposed settlement
remove sp 2 3

set targetSettlement -0.005
set incrS            0.00005
set nStepsS          [expr int(abs($targetSettlement) / abs($incrS))]

constraints Transformation
numberer    Plain
system      BandGeneral
algorithm   Newton
test        NormDispIncr 1.0e-4 100 0
integrator  DisplacementControl 2 3 $incrS
analysis    Static

set ok   0
set step 0

while {$step < $nStepsS && $ok == 0} {

    # Attempt 1: Newton, engineering tolerance
    test      NormDispIncr 1.0e-4 100 0
    algorithm Newton
    integrator DisplacementControl 2 3 $incrS
    set ok [analyze 1]

    if {$ok != 0} {
        # Attempt 2: KrylovNewton, relaxed tolerance
        puts "Settlement Newton failed at step $step — trying KrylovNewton"
        reset
        test      NormDispIncr 1.0e-3 200 0
        algorithm KrylovNewton
        integrator DisplacementControl 2 3 $incrS
        set ok [analyze 1]
    }

    if {$ok != 0} {
        # Attempt 3: sub-stepping with EnergyIncr (robust near softening)
        puts "Settlement KrylovNewton failed at step $step — trying sub-stepping"
        reset
        test      EnergyIncr 1.0e-6 200 0
        algorithm ModifiedNewton -factoronce
        integrator DisplacementControl 2 3 [expr $incrS/10.0]
        set ok [analyze 10]
        integrator DisplacementControl 2 3 $incrS
    }

    if {$ok != 0} {
        puts "Settlement failed to converge at step $step — stopping."
        break
    }

    incr step
}

if {$ok != 0} {
    puts "Settlement stage did not complete — check material parameters or reduce increment."
    return
}

loadConst -time 0.0

# --- STAGE 3: HORIZONTAL PUSHOVER ---
wipeAnalysis

# Re-constrain DOF 3 only — DOFs 1,2,4,5,6 remain from Stage 1
sp 2 3 0.0

pattern Plain 30 Linear {
    load 4  1.0 0.0 0.0  0.0 0.0 0.0
}

set targetDisp 0.4
set incr       0.0001
set nSteps     [expr int($targetDisp / $incr)]

constraints Transformation
numberer    Plain
system      BandGeneral
algorithm   Newton
test        NormDispIncr 1.0e-4 100 0
integrator  DisplacementControl 4 1 $incr
analysis    Static

# Adaptive pushover loop with algorithm and step-size fallbacks
set ok   0
set step 0

while {$step < $nSteps && $ok == 0} {

    # Attempt 1: Newton, engineering tolerance (1e-4 avoids false failures)
    test      NormDispIncr 1.0e-4 100 0
    algorithm Newton
    integrator DisplacementControl 4 1 $incr
    set ok [analyze 1]

    if {$ok != 0} {
        # Attempt 2: KrylovNewton, relaxed tolerance
        puts "Newton failed at step $step — trying KrylovNewton"
        reset
        test      NormDispIncr 1.0e-3 200 0
        algorithm KrylovNewton
        integrator DisplacementControl 4 1 $incr
        set ok [analyze 1]
    }

    if {$ok != 0} {
        # Attempt 3: sub-stepping with EnergyIncr (robust near limit point)
        puts "KrylovNewton failed at step $step — trying sub-stepping with EnergyIncr"
        reset
        test      EnergyIncr 1.0e-6 200 0
        algorithm ModifiedNewton -factoronce
        integrator DisplacementControl 4 1 [expr $incr/10.0]
        set ok [analyze 10]
        integrator DisplacementControl 4 1 $incr
    }

    if {$ok != 0} {
        # Attempt 4: Arc-Length — traces post-peak descending branch past limit point
        puts "EnergyIncr failed at step $step — trying Arc-Length"
        reset
        test      NormDispIncr 1.0e-3 200 0
        algorithm KrylovNewton
        integrator ArcLength [expr $incr*5.0] 1.0
        set ok [analyze 1]
        # Restore DisplacementControl for subsequent steps
        integrator DisplacementControl 4 1 $incr
    }

    if {$ok != 0} {
        puts "Analysis failed to converge at step $step — structure has reached collapse."
        puts "Collapse displacement at node 4 DOF 1: [expr $step * $incr] m"
        puts "Drift ratio: [expr ($step * $incr) / $H_pier * 100.0] %"
        break
    }

    incr step
}

if {$ok == 0} {
    puts "Pushover analysis completed successfully."
} else {
    puts "Pushover stopped at step $step of $nSteps due to non-convergence."
}
