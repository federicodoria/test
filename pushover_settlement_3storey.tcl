# ===========================================================================
# MASONRY FRAME — GRAVITY + SPRING SETTLEMENT + HORIZONTAL PUSHOVER
# Three-Storey Building
# ===========================================================================
#
# Sequence:
#  1. Gravity with ZeroLength spring at node 2 (right base free in Z).
#     Spring stiffness k = R2_estimated / targetSettlement.
#  2. Check settlement; adjust k iteratively until settlement ≈ target.
#  3. Freeze gravity (loadConst).  Remove spring.  Lock node 2 at settled
#     position with a Constant-series sp constraint.
#  4. Horizontal pushover (DisplacementControl on node 8 DOF 1).
# ===========================================================================

# ---------------------------------------------------------------------------
# PARAMETERS
# ---------------------------------------------------------------------------

set H_pier  3.0
set L_pier  1.0
set T_pier  0.25
set L_span  3.0
set H_span  0.80

set H1 $H_pier
set H2 [expr 2.0*$H_pier]
set H3 [expr 3.0*$H_pier]

set E       1700.0e+06
set G        550.0e+06
set fc         6.0e+06
set c        0.150e+06
set Gc         6.0
set mu0        0.40
set beta       0.30
set rho     1200.0
set g          9.81

set targetSettlement  0.005
set tolF              1.0
set tolF_grav      5000.0
set iter             200

set topLoad [expr -1.0*$g*$rho*$L_span*$T_pier]

# Initial spring stiffness: k = R2_estimated / targetSettlement
# R2 ≈ weight of 3 right piers + half of 3 spandrels + 3 floor loads
set R_est [expr   3.0*$rho*$g*$H_pier*$L_pier*$T_pier \
               + 1.5*$rho*$g*$H_span*$L_span*$T_pier \
               + 3.0*abs($topLoad)]
set k_spring [expr $R_est / $targetSettlement]
puts "Estimated reaction at node 2 : [format %.0f $R_est] N"
puts "Initial spring stiffness     : [format %.3e $k_spring] N/m"

# ---------------------------------------------------------------------------
# SPRING-GRAVITY ITERATION LOOP
# Rebuilds the full model with updated k until settlement ≈ targetSettlement
# ---------------------------------------------------------------------------

set settle_tol  0.00005   ;# 0.05 mm
set max_sit     5

for {set sit 0} {$sit < $max_sit} {incr sit} {

    wipe
    model basic -ndm 3 -ndf 6

    # ---- Nodes ----
    node  1   0.0                 0.0   0.0
    node  2   $L_span             0.0   0.0
    node  3   0.0                 0.0   $H1
    node  4   $L_span             0.0   $H1
    node  5   0.0                 0.0   $H2
    node  6   $L_span             0.0   $H2
    node  7   0.0                 0.0   $H3
    node  8   $L_span             0.0   $H3
    node  9   0.0                 0.0   [expr $H1/2.0]
    node 10   $L_span             0.0   [expr $H1/2.0]
    node 11   0.0                 0.0   [expr $H1+$H1/2.0]
    node 12   $L_span             0.0   [expr $H1+$H1/2.0]
    node 13   0.0                 0.0   [expr $H2+$H1/2.0]
    node 14   $L_span             0.0   [expr $H2+$H1/2.0]
    node 15   [expr $L_span/2.0]  0.0   $H1
    node 16   [expr $L_span/2.0]  0.0   $H2
    node 17   [expr $L_span/2.0]  0.0   $H3
    node 18   $L_span             0.0   0.0   ;# spring anchor (same XYZ as node 2)

    # ---- Boundary conditions ----
    fix  1  1 1 1 1 1 1   ;# left base  — fully fixed
    fix  2  1 1 0 1 1 1   ;# right base — free in Z (spring controls settlement)
    fix 18  1 1 1 1 1 1   ;# anchor     — fully fixed

    foreach n {3 4 5 6 7 8}               { fix $n  0 1 0 1 0 1 }
    foreach n {9 10 11 12 13 14 15 16 17} { fix $n  0 1 0 1 1 1 }

    # ---- Vertical spring (ZeroLength) ----
    uniaxialMaterial Elastic 1 $k_spring
    element zeroLength 10  2 18  -mat 1  -dir 3

    # ---- Macroelements (no -pDelta) ----
    element Macroelement3d 1 \
        1 3 9   0.0 0.0 1.0  0.0 1.0 0.0  -tremuri \
        $H_pier $L_pier $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass
    element Macroelement3d 2 \
        2 4 10  0.0 0.0 1.0  0.0 1.0 0.0  -tremuri \
        $H_pier $L_pier $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass
    element Macroelement3d 3 \
        3 5 11  0.0 0.0 1.0  0.0 1.0 0.0  -tremuri \
        $H_pier $L_pier $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass
    element Macroelement3d 4 \
        4 6 12  0.0 0.0 1.0  0.0 1.0 0.0  -tremuri \
        $H_pier $L_pier $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass
    element Macroelement3d 5 \
        5 7 13  0.0 0.0 1.0  0.0 1.0 0.0  -tremuri \
        $H_pier $L_pier $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass
    element Macroelement3d 6 \
        6 8 14  0.0 0.0 1.0  0.0 1.0 0.0  -tremuri \
        $H_pier $L_pier $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass
    element Macroelement3d 7 \
        3 4 15  1.0 0.0 0.0  0.0 1.0 0.0  -tremuri \
        $H_span $L_span $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass
    element Macroelement3d 8 \
        5 6 16  1.0 0.0 0.0  0.0 1.0 0.0  -tremuri \
        $H_span $L_span $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass
    element Macroelement3d 9 \
        7 8 17  1.0 0.0 0.0  0.0 1.0 0.0  -tremuri \
        $H_span $L_span $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass

    # ---- Gravity loads ----
    pattern Plain 10 Linear {
        eleLoad -ele 1 -type -selfWeight 0.0 0.0 [expr -$g]
        eleLoad -ele 2 -type -selfWeight 0.0 0.0 [expr -$g]
        eleLoad -ele 3 -type -selfWeight 0.0 0.0 [expr -$g]
        eleLoad -ele 4 -type -selfWeight 0.0 0.0 [expr -$g]
        eleLoad -ele 5 -type -selfWeight 0.0 0.0 [expr -$g]
        eleLoad -ele 6 -type -selfWeight 0.0 0.0 [expr -$g]
        eleLoad -ele 7 -type -selfWeight 0.0 0.0 [expr -$g]
        eleLoad -ele 8 -type -selfWeight 0.0 0.0 [expr -$g]
        eleLoad -ele 9 -type -selfWeight 0.0 0.0 [expr -$g]
        load 3  0.0 0.0 $topLoad 0.0 0.0 0.0
        load 4  0.0 0.0 $topLoad 0.0 0.0 0.0
        load 5  0.0 0.0 $topLoad 0.0 0.0 0.0
        load 6  0.0 0.0 $topLoad 0.0 0.0 0.0
        load 7  0.0 0.0 $topLoad 0.0 0.0 0.0
        load 8  0.0 0.0 $topLoad 0.0 0.0 0.0
    }

    # ---- Gravity analysis ----
    system      BandGeneral
    numberer    Plain
    constraints Transformation
    integrator  LoadControl 0.1
    test        NormUnbalance $tolF_grav $iter 0
    algorithm   Newton
    analysis    Static

    puts "--- Spring iter $sit  (k = [format %.3e $k_spring] N/m) ---"
    set ok 0
    for {set gi 0} {$gi < 10 && $ok == 0} {incr gi} {
        set ok [analyze 1]
        if {$ok != 0} {
            test      NormUnbalance $tolF_grav $iter 0
            algorithm Newton -initial
            set ok [analyze 1]
        }
        if {$ok != 0} {
            test      NormUnbalance $tolF_grav $iter 0
            algorithm ModifiedNewton
            set ok [analyze 1]
        }
        if {$ok != 0} { puts "Gravity failed at sub-step $gi"; break }
        algorithm Newton
        test      NormUnbalance $tolF_grav $iter 0
    }

    if {$ok != 0} { puts "Gravity failed — stopping."; break }
    puts "Gravity completed."

    set d_settle [nodeDisp 2 3]
    puts "Settlement = [format %.5f $d_settle] m  (target = [format %.5f [expr -$targetSettlement]] m)"

    if {abs(abs($d_settle) - $targetSettlement) <= $settle_tol} {
        puts "Settlement within tolerance."
        break
    }

    # Adjust k for next iteration: k_new = k * |d_actual| / d_target
    # (softer k → more settlement; stiffer k → less settlement)
    set k_spring [expr $k_spring * abs($d_settle) / $targetSettlement]
    puts "New spring stiffness: [format %.3e $k_spring] N/m"
}

# ---------------------------------------------------------------------------
# FREEZE GRAVITY STATE
# ---------------------------------------------------------------------------

loadConst -time 0.0
set d_final [nodeDisp 2 3]
puts "\nFinal settlement at node 2: [format %.5f $d_final] m"

# ---------------------------------------------------------------------------
# REPLACE SPRING WITH LOCKED-POSITION CONSTRAINT
# Remove the ZeroLength spring.  Add a Constant time-series sp that holds
# node 2 DOF 3 at its settled value throughout the pushover.
# ---------------------------------------------------------------------------

remove element 10

timeSeries Constant 99
pattern Plain 99 99 {
    sp 2 3 $d_final
}

wipeAnalysis

# ---------------------------------------------------------------------------
# RECORDERS
# ---------------------------------------------------------------------------

recorder Node -file TopDisp.out        -time -node 8      -dof 1   disp
recorder Node -file FloorDisp.out      -time -node 4 6 8  -dof 1   disp
recorder Node -file BaseReaction.out   -time -node 1 2    -dof 1 3 reaction
recorder Node -file SettlementDisp.out -time -node 2      -dof 3   disp

recorder Element -file Pier1Force.out     -time -ele 1 force
recorder Element -file Pier2Force.out     -time -ele 2 force
recorder Element -file Pier3Force.out     -time -ele 3 force
recorder Element -file Pier4Force.out     -time -ele 4 force
recorder Element -file Pier5Force.out     -time -ele 5 force
recorder Element -file Pier6Force.out     -time -ele 6 force
recorder Element -file Spandrel1Force.out -time -ele 7 force
recorder Element -file Spandrel2Force.out -time -ele 8 force
recorder Element -file Spandrel3Force.out -time -ele 9 force

# ---------------------------------------------------------------------------
# HORIZONTAL PUSHOVER
# Triangular pattern: floors 1/2/3 loaded at 1/6, 2/6, 3/6 per node
# ---------------------------------------------------------------------------

pattern Plain 30 Linear {
    load 3  [expr 1.0/6.0]  0.0 0.0 0.0 0.0 0.0
    load 4  [expr 1.0/6.0]  0.0 0.0 0.0 0.0 0.0
    load 5  [expr 2.0/6.0]  0.0 0.0 0.0 0.0 0.0
    load 6  [expr 2.0/6.0]  0.0 0.0 0.0 0.0 0.0
    load 7  [expr 3.0/6.0]  0.0 0.0 0.0 0.0 0.0
    load 8  [expr 3.0/6.0]  0.0 0.0 0.0 0.0 0.0
}

set targetDisp  0.2
set pushIncr    0.00005
set nSteps      [expr int($targetDisp / $pushIncr)]

system      BandGeneral
numberer    Plain
constraints Transformation
test        NormUnbalance $tolF $iter 0
algorithm   Newton
integrator  DisplacementControl 8 1 $pushIncr
analysis    Static

puts "Running horizontal pushover..."

set stepP 0
set ok    0
while {$stepP < $nSteps && $ok == 0} {
    test      NormUnbalance $tolF $iter 0
    algorithm Newton
    set ok [analyze 1]
    if {$ok != 0} {
        puts "Step $stepP: Newton failed → Newton -initial"
        test      NormUnbalance $tolF $iter 0
        algorithm Newton -initial
        set ok [analyze 1]
    }
    if {$ok != 0} {
        puts "Step $stepP: Newton -initial failed → ModifiedNewton"
        test      NormUnbalance $tolF $iter 0
        algorithm ModifiedNewton
        set ok [analyze 1]
    }
    if {$ok != 0} {
        puts "Pushover stopped at step $stepP (disp = [expr $stepP*$pushIncr] m)."
        break
    }
    incr stepP
}

if {$ok == 0} {
    puts "Pushover completed successfully ([format %.3f [expr $nSteps*$pushIncr]] m)."
}
puts "All analyses done."
