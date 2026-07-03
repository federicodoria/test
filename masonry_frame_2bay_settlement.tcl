# ===========================================================================
# MASONRY FRAME — GRAVITY + SPRING SETTLEMENT + HORIZONTAL PUSHOVER
# Three-Storey, Two-Bay Building
# Settlement is applied through a spring only under the RIGHT foundation pier.
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

set X1 0.0
set X2 $L_span
set X3 [expr 2.0*$L_span]

set E       1700.0e+06
set G        550.0e+06
set fc         6.0e+06
set c        0.150e+06
set Gc         6.0
set mu0        0.40
set beta       0.30
set rho     1200.0
set g          9.81

set targetSettlement  0.001
set tolF              0.001
set iter             1000

set topLoad [expr -1.0*$g*$rho*$L_span*$T_pier]

# Tributary estimate for the RIGHT pier only (own pier self-weight over the
# full building height, half of the adjacent bay's spandrel weight, and the
# direct nodal floor loads applied at its own 3 storeys).
set R_est [expr   3.0*$rho*$g*$H_pier*$L_pier*$T_pier \
               + 1.5*$rho*$g*$H_span*$L_span*$T_pier \
               + 3.0*abs($topLoad)]
set k_spring [expr $R_est / $targetSettlement]
puts "Estimated reaction at node 3 (right pier) : [format %.0f $R_est] N"
puts "Initial spring stiffness                   : [format %.3e $k_spring] N/m"

# ---------------------------------------------------------------------------
# SPRING-GRAVITY ITERATION LOOP
# ---------------------------------------------------------------------------

set settle_tol  0.0000005
set max_sit     5

for {set sit 0} {$sit < $max_sit} {incr sit} {

    wipe
    model basic -ndm 3 -ndf 6

    # --- base nodes -----------------------------------------------------
    node  1   $X1   0.0   0.0    ;# pier L base
    node  2   $X2   0.0   0.0    ;# pier M base
    node  3   $X3   0.0   0.0    ;# pier R base (settling, spring dof 3)
    node  4   $X3   0.0   0.0    ;# pier R spring anchor (fully fixed)

    # --- storey-top nodes -------------------------------------------------
    node  5   $X1   0.0   $H1    ;# pier L top 1
    node  6   $X2   0.0   $H1    ;# pier M top 1
    node  7   $X3   0.0   $H1    ;# pier R top 1

    node  8   $X1   0.0   $H2    ;# pier L top 2
    node  9   $X2   0.0   $H2    ;# pier M top 2
    node 10   $X3   0.0   $H2    ;# pier R top 2

    node 11   $X1   0.0   $H3    ;# pier L top 3
    node 12   $X2   0.0   $H3    ;# pier M top 3
    node 13   $X3   0.0   $H3    ;# pier R top 3

    # --- pier mid-height nodes (one per storey element) --------------------
    node 14   $X1   0.0   [expr $H1/2.0]              ;# pier L mid 1
    node 15   $X2   0.0   [expr $H1/2.0]              ;# pier M mid 1
    node 16   $X3   0.0   [expr $H1/2.0]              ;# pier R mid 1

    node 17   $X1   0.0   [expr $H1+$H1/2.0]          ;# pier L mid 2
    node 18   $X2   0.0   [expr $H1+$H1/2.0]          ;# pier M mid 2
    node 19   $X3   0.0   [expr $H1+$H1/2.0]          ;# pier R mid 2

    node 20   $X1   0.0   [expr $H2+$H1/2.0]          ;# pier L mid 3
    node 21   $X2   0.0   [expr $H2+$H1/2.0]          ;# pier M mid 3
    node 22   $X3   0.0   [expr $H2+$H1/2.0]          ;# pier R mid 3

    # --- spandrel mid-span nodes -------------------------------------------
    node 23   [expr ($X1+$X2)/2.0]   0.0   $H1        ;# bay 1 spandrel mid, storey 1
    node 24   [expr ($X1+$X2)/2.0]   0.0   $H2        ;# bay 1 spandrel mid, storey 2
    node 25   [expr ($X1+$X2)/2.0]   0.0   $H3         ;# bay 1 spandrel mid, storey 3

    node 26   [expr ($X2+$X3)/2.0]   0.0   $H1        ;# bay 2 spandrel mid, storey 1
    node 27   [expr ($X2+$X3)/2.0]   0.0   $H2        ;# bay 2 spandrel mid, storey 2
    node 28   [expr ($X2+$X3)/2.0]   0.0   $H3         ;# bay 2 spandrel mid, storey 3

    fix  1  1 1 1 1 1 1
    fix  2  1 1 1 1 1 1
    fix  3  1 1 0 1 1 1
    fix  4  1 1 1 1 1 1

    uniaxialMaterial Elastic 1 $k_spring
    element zeroLength 16  3 4  -mat 1  -dir 3

    # --- pier L (storeys 1-3) ----------------------------------------------
    element Macroelement3d 1 \
        1 5 14   0.0 0.0 1.0  0.0 1.0 0.0  -tremuri \
        $H_pier $L_pier $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass -pDelta
    element Macroelement3d 2 \
        5 8 17   0.0 0.0 1.0  0.0 1.0 0.0  -tremuri \
        $H_pier $L_pier $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass -pDelta
    element Macroelement3d 3 \
        8 11 20  0.0 0.0 1.0  0.0 1.0 0.0  -tremuri \
        $H_pier $L_pier $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass -pDelta

    # --- pier M (storeys 1-3) ----------------------------------------------
    element Macroelement3d 4 \
        2 6 15   0.0 0.0 1.0  0.0 1.0 0.0  -tremuri \
        $H_pier $L_pier $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass -pDelta
    element Macroelement3d 5 \
        6 9 18   0.0 0.0 1.0  0.0 1.0 0.0  -tremuri \
        $H_pier $L_pier $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass -pDelta
    element Macroelement3d 6 \
        9 12 21  0.0 0.0 1.0  0.0 1.0 0.0  -tremuri \
        $H_pier $L_pier $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass -pDelta

    # --- pier R (storeys 1-3, settling pier) --------------------------------
    element Macroelement3d 7 \
        3 7 16   0.0 0.0 1.0  0.0 1.0 0.0  -tremuri \
        $H_pier $L_pier $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass -pDelta
    element Macroelement3d 8 \
        7 10 19  0.0 0.0 1.0  0.0 1.0 0.0  -tremuri \
        $H_pier $L_pier $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass -pDelta
    element Macroelement3d 9 \
        10 13 22 0.0 0.0 1.0  0.0 1.0 0.0  -tremuri \
        $H_pier $L_pier $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass -pDelta

    # --- bay 1 spandrels (between pier L and pier M) ------------------------
    element Macroelement3d 10 \
        5 6 23  1.0 0.0 0.0  0.0 1.0 0.0  -tremuri \
        $H_span $L_span $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass -pDelta
    element Macroelement3d 11 \
        8 9 24  1.0 0.0 0.0  0.0 1.0 0.0  -tremuri \
        $H_span $L_span $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass -pDelta
    element Macroelement3d 12 \
        11 12 25  1.0 0.0 0.0  0.0 1.0 0.0  -tremuri \
        $H_span $L_span $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass -pDelta

    # --- bay 2 spandrels (between pier M and pier R) ------------------------
    element Macroelement3d 13 \
        6 7 26  1.0 0.0 0.0  0.0 1.0 0.0  -tremuri \
        $H_span $L_span $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass -pDelta
    element Macroelement3d 14 \
        9 10 27  1.0 0.0 0.0  0.0 1.0 0.0  -tremuri \
        $H_span $L_span $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass -pDelta
    element Macroelement3d 15 \
        12 13 28  1.0 0.0 0.0  0.0 1.0 0.0  -tremuri \
        $H_span $L_span $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass -pDelta

    pattern Plain 10 Linear {
        eleLoad -ele 1  -type -selfWeight 0.0 0.0 [expr -$g]
        eleLoad -ele 2  -type -selfWeight 0.0 0.0 [expr -$g]
        eleLoad -ele 3  -type -selfWeight 0.0 0.0 [expr -$g]
        eleLoad -ele 4  -type -selfWeight 0.0 0.0 [expr -$g]
        eleLoad -ele 5  -type -selfWeight 0.0 0.0 [expr -$g]
        eleLoad -ele 6  -type -selfWeight 0.0 0.0 [expr -$g]
        eleLoad -ele 7  -type -selfWeight 0.0 0.0 [expr -$g]
        eleLoad -ele 8  -type -selfWeight 0.0 0.0 [expr -$g]
        eleLoad -ele 9  -type -selfWeight 0.0 0.0 [expr -$g]
        eleLoad -ele 10 -type -selfWeight 0.0 0.0 [expr -$g]
        eleLoad -ele 11 -type -selfWeight 0.0 0.0 [expr -$g]
        eleLoad -ele 12 -type -selfWeight 0.0 0.0 [expr -$g]
        eleLoad -ele 13 -type -selfWeight 0.0 0.0 [expr -$g]
        eleLoad -ele 14 -type -selfWeight 0.0 0.0 [expr -$g]
        eleLoad -ele 15 -type -selfWeight 0.0 0.0 [expr -$g]
        load  5  0.0 0.0 $topLoad 0.0 0.0 0.0
        load  6  0.0 0.0 $topLoad 0.0 0.0 0.0
        load  7  0.0 0.0 $topLoad 0.0 0.0 0.0
        load  8  0.0 0.0 $topLoad 0.0 0.0 0.0
        load  9  0.0 0.0 $topLoad 0.0 0.0 0.0
        load 10  0.0 0.0 $topLoad 0.0 0.0 0.0
        load 11  0.0 0.0 $topLoad 0.0 0.0 0.0
        load 12  0.0 0.0 $topLoad 0.0 0.0 0.0
        load 13  0.0 0.0 $topLoad 0.0 0.0 0.0
    }

    system      UmfPack
    numberer    Plain
    constraints Transformation
    integrator  LoadControl 0.001
    test        NormUnbalance $tolF $iter 0
    algorithm   Newton
    analysis    Static

    puts "--- Spring iter $sit  (k = [format %.3e $k_spring] N/m) ---"
    set ok 0
    for {set gi 0} {$gi < 1000 && $ok == 0} {incr gi} {
        set ok [analyze 1]
        if {$ok != 0} {
            test      NormUnbalance $tolF $iter 0
            algorithm Newton -initial
            set ok [analyze 1]
        }
        if {$ok != 0} {
            test      NormUnbalance $tolF $iter 0
            algorithm ModifiedNewton
            set ok [analyze 1]
        }
        if {$ok != 0} { puts "Gravity failed at sub-step $gi"; break }
        algorithm Newton
        test      NormUnbalance $tolF $iter 0
    }

    if {$ok != 0} { puts "Gravity failed — stopping."; break }
    puts "Gravity completed."

    set d_settle [nodeDisp 3 3]
    puts "Settlement = [format %.5f $d_settle] m  (target = [format %.5f [expr -$targetSettlement]] m)"

    if {abs(abs($d_settle) - $targetSettlement) <= $settle_tol} {
        puts "Settlement within tolerance."
        break
    }

    set k_spring [expr $k_spring * abs($d_settle) / $targetSettlement]
    puts "New spring stiffness: [format %.3e $k_spring] N/m"
}

# ---------------------------------------------------------------------------
# FREEZE GRAVITY STATE
# ---------------------------------------------------------------------------

loadConst -time 0.0
set d_final [nodeDisp 3 3]
puts "\nFinal settlement at node 3 (right pier): [format %.5f $d_final] m"

remove element 16

timeSeries Constant 99
pattern Plain 99 99 {
    sp 3 3 $d_final
}

wipeAnalysis

# ---------------------------------------------------------------------------
# RECORDERS
# ---------------------------------------------------------------------------

recorder Node -file TopDisp.out        -time -node 13         -dof 1   disp
recorder Node -file FloorDisp.out      -time -node 7 10 13     -dof 1   disp
recorder Node -file BaseReaction.out   -time -node 1 2 3       -dof 1   reaction
recorder Node -file SettlementDisp.out -time -node 3           -dof 3   disp

recorder Element -file Pier1Force.out     -time -ele 1  force
recorder Element -file Pier2Force.out     -time -ele 2  force
recorder Element -file Pier3Force.out     -time -ele 3  force
recorder Element -file Pier4Force.out     -time -ele 4  force
recorder Element -file Pier5Force.out     -time -ele 5  force
recorder Element -file Pier6Force.out     -time -ele 6  force
recorder Element -file Pier7Force.out     -time -ele 7  force
recorder Element -file Pier8Force.out     -time -ele 8  force
recorder Element -file Pier9Force.out     -time -ele 9  force
recorder Element -file Spandrel1Force.out -time -ele 10 force
recorder Element -file Spandrel2Force.out -time -ele 11 force
recorder Element -file Spandrel3Force.out -time -ele 12 force
recorder Element -file Spandrel4Force.out -time -ele 13 force
recorder Element -file Spandrel5Force.out -time -ele 14 force
recorder Element -file Spandrel6Force.out -time -ele 15 force

# ---------------------------------------------------------------------------
# HORIZONTAL PUSHOVER
# ---------------------------------------------------------------------------

pattern Plain 30 Linear {
    load  5  [expr 1.0/6.0]  0.0 0.0 0.0 0.0 0.0
    load  6  [expr 1.0/6.0]  0.0 0.0 0.0 0.0 0.0
    load  7  [expr 1.0/6.0]  0.0 0.0 0.0 0.0 0.0
    load  8  [expr 2.0/6.0]  0.0 0.0 0.0 0.0 0.0
    load  9  [expr 2.0/6.0]  0.0 0.0 0.0 0.0 0.0
    load 10  [expr 2.0/6.0]  0.0 0.0 0.0 0.0 0.0
    load 11  [expr 3.0/6.0]  0.0 0.0 0.0 0.0 0.0
    load 12  [expr 3.0/6.0]  0.0 0.0 0.0 0.0 0.0
    load 13  [expr 3.0/6.0]  0.0 0.0 0.0 0.0 0.0
}

set targetDisp  0.3
set pushIncr    0.00005
set nSteps      [expr int($targetDisp / $pushIncr)]

system      UmfPack
numberer    Plain
constraints Transformation
test        NormUnbalance $tolF $iter 0
algorithm   Newton
integrator  DisplacementControl 13 1 $pushIncr
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
