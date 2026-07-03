# ===========================================================================
# MASONRY FRAME — GRAVITY + SPRING SETTLEMENT (MIDDLE PIER) + HORIZONTAL PUSHOVER
# Three-Storey Building, 3 Piers / 2 Bays
# ===========================================================================
#
# Column layout (plan, along X):
#   Left pier    x = 0
#   Middle pier  x = L_span      <-- settlement applied here
#   Right pier   x = 2*L_span
#
# Node numbering:
#    1- 3  : base nodes            (left, middle, right)
#    4- 6  : floor 1 nodes         (left, middle, right)
#    7- 9  : floor 2 nodes         (left, middle, right)
#   10-12  : floor 3 / roof nodes  (left, middle, right)
#   13-15  : pier control nodes, storey 1 (left, middle, right)
#   16-18  : pier control nodes, storey 2 (left, middle, right)
#   19-21  : pier control nodes, storey 3 (left, middle, right)
#   22-23  : spandrel control nodes, floor 1 (bay 1, bay 2)
#   24-25  : spandrel control nodes, floor 2 (bay 1, bay 2)
#   26-27  : spandrel control nodes, floor 3 (bay 1, bay 2)
#   28     : dummy fixed node under the middle base, for the settlement spring
#
# Element numbering:
#    1- 3  : left column piers,   storeys 1-3
#    4- 6  : middle column piers, storeys 1-3   (bear on the settling spring)
#    7- 9  : right column piers,  storeys 1-3
#   10-11  : floor 1 spandrels, bay 1 / bay 2
#   12-13  : floor 2 spandrels, bay 1 / bay 2
#   14-15  : floor 3 spandrels, bay 1 / bay 2
#   20     : zeroLength settlement spring under the middle base (removed after gravity)
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

set targetSettlement  0.02
set tolF              0.001
set iter             1000

set topLoad [expr -1.0*$g*$rho*$L_span*$T_pier]

# Reaction estimate at the MIDDLE base node: its own column (3 piers) +
# both adjacent spandrels at each of the 3 floors (1 full spandrel-worth
# per floor, since the middle column picks up half of each side) +
# 2x topLoad per floor (middle node carries tributary from both bays).
set R_est [expr   3.0*$rho*$g*$H_pier*$L_pier*$T_pier \
               + 3.0*$rho*$g*$H_span*$L_span*$T_pier \
               + 6.0*abs($topLoad)]
set k_spring [expr $R_est / $targetSettlement]
puts "Estimated reaction at middle base node (node 2) : [format %.0f $R_est] N"
puts "Initial spring stiffness                        : [format %.3e $k_spring] N/m"

# ---------------------------------------------------------------------------
# SPRING-GRAVITY ITERATION LOOP
# ---------------------------------------------------------------------------

set settle_tol  0.0000005
set max_sit     5

for {set sit 0} {$sit < $max_sit} {incr sit} {

    wipe
    model basic -ndm 3 -ndf 6

    # base nodes
    node  1   0.0                 0.0   0.0
    node  2   $L_span             0.0   0.0
    node  3   [expr 2.0*$L_span]  0.0   0.0

    # floor 1
    node  4   0.0                 0.0   $H1
    node  5   $L_span             0.0   $H1
    node  6   [expr 2.0*$L_span]  0.0   $H1

    # floor 2
    node  7   0.0                 0.0   $H2
    node  8   $L_span             0.0   $H2
    node  9   [expr 2.0*$L_span]  0.0   $H2

    # floor 3 / roof
    node 10   0.0                 0.0   $H3
    node 11   $L_span             0.0   $H3
    node 12   [expr 2.0*$L_span]  0.0   $H3

    # pier control nodes, storey 1
    node 13   0.0                 0.0   [expr $H1/2.0]
    node 14   $L_span             0.0   [expr $H1/2.0]
    node 15   [expr 2.0*$L_span]  0.0   [expr $H1/2.0]

    # pier control nodes, storey 2
    node 16   0.0                 0.0   [expr $H1+$H1/2.0]
    node 17   $L_span             0.0   [expr $H1+$H1/2.0]
    node 18   [expr 2.0*$L_span]  0.0   [expr $H1+$H1/2.0]

    # pier control nodes, storey 3
    node 19   0.0                 0.0   [expr $H2+$H1/2.0]
    node 20   $L_span             0.0   [expr $H2+$H1/2.0]
    node 21   [expr 2.0*$L_span]  0.0   [expr $H2+$H1/2.0]

    # spandrel control nodes
    node 22   [expr $L_span/2.0]        0.0   $H1
    node 23   [expr 1.5*$L_span]        0.0   $H1
    node 24   [expr $L_span/2.0]        0.0   $H2
    node 25   [expr 1.5*$L_span]        0.0   $H2
    node 26   [expr $L_span/2.0]        0.0   $H3
    node 27   [expr 1.5*$L_span]        0.0   $H3

    # dummy support node for the settlement spring
    node 28   $L_span             0.0   0.0

    fix  1  1 1 1 1 1 1
    fix  2  1 1 0 1 1 1
    fix  3  1 1 1 1 1 1
    fix 28  1 1 1 1 1 1

    uniaxialMaterial Elastic 1 $k_spring
    element zeroLength 20  2 28  -mat 1  -dir 3

    # --- left column (piers 1-3) ---
    element Macroelement3d 1 \
        1 4 13  0.0 0.0 1.0  0.0 1.0 0.0  -tremuri \
        $H_pier $L_pier $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass -pDelta
    element Macroelement3d 2 \
        4 7 16  0.0 0.0 1.0  0.0 1.0 0.0  -tremuri \
        $H_pier $L_pier $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass -pDelta
    element Macroelement3d 3 \
        7 10 19  0.0 0.0 1.0  0.0 1.0 0.0  -tremuri \
        $H_pier $L_pier $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass -pDelta

    # --- middle column (piers 4-6) — settling column ---
    element Macroelement3d 4 \
        2 5 14  0.0 0.0 1.0  0.0 1.0 0.0  -tremuri \
        $H_pier $L_pier $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass -pDelta
    element Macroelement3d 5 \
        5 8 17  0.0 0.0 1.0  0.0 1.0 0.0  -tremuri \
        $H_pier $L_pier $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass -pDelta
    element Macroelement3d 6 \
        8 11 20  0.0 0.0 1.0  0.0 1.0 0.0  -tremuri \
        $H_pier $L_pier $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass -pDelta

    # --- right column (piers 7-9) ---
    element Macroelement3d 7 \
        3 6 15  0.0 0.0 1.0  0.0 1.0 0.0  -tremuri \
        $H_pier $L_pier $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass -pDelta
    element Macroelement3d 8 \
        6 9 18  0.0 0.0 1.0  0.0 1.0 0.0  -tremuri \
        $H_pier $L_pier $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass -pDelta
    element Macroelement3d 9 \
        9 12 21  0.0 0.0 1.0  0.0 1.0 0.0  -tremuri \
        $H_pier $L_pier $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass -pDelta

    # --- spandrels, floor 1 (bay 1: left-middle, bay 2: middle-right) ---
    element Macroelement3d 10 \
        4 5 22  1.0 0.0 0.0  0.0 1.0 0.0  -tremuri \
        $H_span $L_span $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass -pDelta
    element Macroelement3d 11 \
        5 6 23  1.0 0.0 0.0  0.0 1.0 0.0  -tremuri \
        $H_span $L_span $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass -pDelta

    # --- spandrels, floor 2 ---
    element Macroelement3d 12 \
        7 8 24  1.0 0.0 0.0  0.0 1.0 0.0  -tremuri \
        $H_span $L_span $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass -pDelta
    element Macroelement3d 13 \
        8 9 25  1.0 0.0 0.0  0.0 1.0 0.0  -tremuri \
        $H_span $L_span $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass -pDelta

    # --- spandrels, floor 3 ---
    element Macroelement3d 14 \
        10 11 26  1.0 0.0 0.0  0.0 1.0 0.0  -tremuri \
        $H_span $L_span $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass -pDelta
    element Macroelement3d 15 \
        11 12 27  1.0 0.0 0.0  0.0 1.0 0.0  -tremuri \
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

        # floor slab loads: middle nodes carry tributary from both bays (2x)
        load  4  0.0 0.0 $topLoad                    0.0 0.0 0.0
        load  5  0.0 0.0 [expr 2.0*$topLoad]          0.0 0.0 0.0
        load  6  0.0 0.0 $topLoad                    0.0 0.0 0.0
        load  7  0.0 0.0 $topLoad                    0.0 0.0 0.0
        load  8  0.0 0.0 [expr 2.0*$topLoad]          0.0 0.0 0.0
        load  9  0.0 0.0 $topLoad                    0.0 0.0 0.0
        load 10  0.0 0.0 $topLoad                    0.0 0.0 0.0
        load 11  0.0 0.0 [expr 2.0*$topLoad]          0.0 0.0 0.0
        load 12  0.0 0.0 $topLoad                    0.0 0.0 0.0
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

    set d_settle [nodeDisp 2 3]
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
set d_final [nodeDisp 2 3]
puts "\nFinal settlement at middle base node (node 2): [format %.5f $d_final] m"

remove element 20

timeSeries Constant 99
pattern Plain 99 99 {
    sp 2 3 $d_final
}

wipeAnalysis

# ---------------------------------------------------------------------------
# RECORDERS
# ---------------------------------------------------------------------------

recorder Node -file TopDisp.out          -time -node 12          -dof 1   disp
recorder Node -file FloorDisp_Right.out  -time -node 6 9 12       -dof 1   disp
recorder Node -file FloorDisp_Middle.out -time -node 5 8 11       -dof 1   disp
recorder Node -file FloorDisp_Left.out   -time -node 4 7 10       -dof 1   disp
recorder Node -file BaseReaction.out     -time -node 1 2 3        -dof 1   reaction
recorder Node -file SettlementDisp.out   -time -node 2            -dof 3   disp

recorder Element -file PierLeft1Force.out    -time -ele 1  force
recorder Element -file PierLeft2Force.out    -time -ele 2  force
recorder Element -file PierLeft3Force.out    -time -ele 3  force
recorder Element -file PierMid1Force.out     -time -ele 4  force
recorder Element -file PierMid2Force.out     -time -ele 5  force
recorder Element -file PierMid3Force.out     -time -ele 6  force
recorder Element -file PierRight1Force.out   -time -ele 7  force
recorder Element -file PierRight2Force.out   -time -ele 8  force
recorder Element -file PierRight3Force.out   -time -ele 9  force
recorder Element -file Spandrel1Bay1Force.out -time -ele 10 force
recorder Element -file Spandrel1Bay2Force.out -time -ele 11 force
recorder Element -file Spandrel2Bay1Force.out -time -ele 12 force
recorder Element -file Spandrel2Bay2Force.out -time -ele 13 force
recorder Element -file Spandrel3Bay1Force.out -time -ele 14 force
recorder Element -file Spandrel3Bay2Force.out -time -ele 15 force

# ---------------------------------------------------------------------------
# HORIZONTAL PUSHOVER
# ---------------------------------------------------------------------------
# Inverted-triangular pattern (proportional to storey level), split equally
# across the 3 columns at each floor.

pattern Plain 30 Linear {
    load  4  [expr 1.0/9.0]  0.0 0.0 0.0 0.0 0.0
    load  5  [expr 1.0/9.0]  0.0 0.0 0.0 0.0 0.0
    load  6  [expr 1.0/9.0]  0.0 0.0 0.0 0.0 0.0
    load  7  [expr 2.0/9.0]  0.0 0.0 0.0 0.0 0.0
    load  8  [expr 2.0/9.0]  0.0 0.0 0.0 0.0 0.0
    load  9  [expr 2.0/9.0]  0.0 0.0 0.0 0.0 0.0
    load 10  [expr 3.0/9.0]  0.0 0.0 0.0 0.0 0.0
    load 11  [expr 3.0/9.0]  0.0 0.0 0.0 0.0 0.0
    load 12  [expr 3.0/9.0]  0.0 0.0 0.0 0.0 0.0
}

set targetDisp  0.3
set pushIncr    0.00005
set nSteps      [expr int($targetDisp / $pushIncr)]

system      UmfPack
numberer    Plain
constraints Transformation
test        NormUnbalance $tolF $iter 0
algorithm   Newton
integrator  DisplacementControl 12 1 $pushIncr
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
