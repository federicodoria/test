# --------------------------------------------------------------------------------------------------
# MASONRY FRAME PUSHOVER ANALYSIS WITH SETTLEMENT
# Three-Storey Building
# --------------------------------------------------------------------------------------------------

wipe;
model basic -ndm 3 -ndf 6;

# --------------------------------------------------------------------------------------------------
# GEOMETRY
# --------------------------------------------------------------------------------------------------

set H_pier 3.0
set L_pier 1.0
set T_pier 0.25
set L_span 3.0
set H_span 0.80

set H1 $H_pier
set H2 [expr 2.0*$H_pier]
set H3 [expr 3.0*$H_pier]

# --------------------------------------------------------------------------------------------------
# MATERIAL PROPERTIES
# --------------------------------------------------------------------------------------------------

set E       1700.0e+06
set G       550.0e+06
set fc      6.0e+06
set c       0.150e+06
set Gc      6.0
set mu0     0.40
set beta    0.30
set rho     1200.0
set g       9.81

# --------------------------------------------------------------------------------------------------
# NODES
# Node layout (x=0 left column, x=L_span right column):
#
#   Floor 3 (roof)  : nodes  7 (left)  8 (right)   spandrel mid: 17
#   Floor 2         : nodes  5 (left)  6 (right)   spandrel mid: 16
#   Floor 1         : nodes  3 (left)  4 (right)   spandrel mid: 15
#   Ground          : nodes  1 (left)  2 (right)
#
#   Pier mid-nodes  : storey 1 left=9  right=10
#                     storey 2 left=11 right=12
#                     storey 3 left=13 right=14
# --------------------------------------------------------------------------------------------------

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
node 11   0.0                 0.0   [expr $H1 + $H1/2.0]
node 12   $L_span             0.0   [expr $H1 + $H1/2.0]
node 13   0.0                 0.0   [expr $H2 + $H1/2.0]
node 14   $L_span             0.0   [expr $H2 + $H1/2.0]
node 15   [expr $L_span/2.0]  0.0   $H1
node 16   [expr $L_span/2.0]  0.0   $H2
node 17   [expr $L_span/2.0]  0.0   $H3

# --------------------------------------------------------------------------------------------------
# BOUNDARY CONDITIONS
# -pDelta is NOT used: its 3D geometric stiffness couples in-plane axial force
# to out-of-plane DOFs, creating irresolvable residuals when those DOFs are
# constrained.  Without -pDelta the out-of-plane DOFs are strictly uncoupled
# and can be constrained here from the start.
#
# Base nodes fully fixed.
# Floor nodes (3-8): fix Uy(2), Rx(4), Rz(6) - no out-of-plane stiffness.
# Mid-nodes (9-17): fix Uy(2), Rx(4), Ry(5), Rz(6) - element provides no
#                   stiffness at mid-node for these DOFs.
# --------------------------------------------------------------------------------------------------

fix 1  1 1 1 1 1 1
fix 2  1 1 1 1 1 1

foreach n {3 4 5 6 7 8} {
    fix $n  0 1 0 1 0 1
}
foreach n {9 10 11 12 13 14 15 16 17} {
    fix $n  0 1 0 1 1 1
}

# --------------------------------------------------------------------------------------------------
# MACROELEMENTS
# Piers    : local axis 1 = 0 0 1 (vertical Z), local axis 2 = 0 1 0
# Spandrels: local axis 1 = 1 0 0 (horizontal X), local axis 2 = 0 1 0
# -pDelta omitted (see boundary condition note above)
# --------------------------------------------------------------------------------------------------

element Macroelement3d 1 \
    1 3 9 \
    0.0 0.0 1.0 \
    0.0 1.0 0.0 \
    -tremuri \
    $H_pier $L_pier $T_pier \
    $E $G $fc $mu0 $c $Gc $beta \
    -density $rho -cmass

element Macroelement3d 2 \
    2 4 10 \
    0.0 0.0 1.0 \
    0.0 1.0 0.0 \
    -tremuri \
    $H_pier $L_pier $T_pier \
    $E $G $fc $mu0 $c $Gc $beta \
    -density $rho -cmass

element Macroelement3d 3 \
    3 5 11 \
    0.0 0.0 1.0 \
    0.0 1.0 0.0 \
    -tremuri \
    $H_pier $L_pier $T_pier \
    $E $G $fc $mu0 $c $Gc $beta \
    -density $rho -cmass

element Macroelement3d 4 \
    4 6 12 \
    0.0 0.0 1.0 \
    0.0 1.0 0.0 \
    -tremuri \
    $H_pier $L_pier $T_pier \
    $E $G $fc $mu0 $c $Gc $beta \
    -density $rho -cmass

element Macroelement3d 5 \
    5 7 13 \
    0.0 0.0 1.0 \
    0.0 1.0 0.0 \
    -tremuri \
    $H_pier $L_pier $T_pier \
    $E $G $fc $mu0 $c $Gc $beta \
    -density $rho -cmass

element Macroelement3d 6 \
    6 8 14 \
    0.0 0.0 1.0 \
    0.0 1.0 0.0 \
    -tremuri \
    $H_pier $L_pier $T_pier \
    $E $G $fc $mu0 $c $Gc $beta \
    -density $rho -cmass

element Macroelement3d 7 \
    3 4 15 \
    1.0 0.0 0.0 \
    0.0 1.0 0.0 \
    -tremuri \
    $H_span $L_span $T_pier \
    $E $G $fc $mu0 $c $Gc $beta \
    -density $rho -cmass

element Macroelement3d 8 \
    5 6 16 \
    1.0 0.0 0.0 \
    0.0 1.0 0.0 \
    -tremuri \
    $H_span $L_span $T_pier \
    $E $G $fc $mu0 $c $Gc $beta \
    -density $rho -cmass

element Macroelement3d 9 \
    7 8 17 \
    1.0 0.0 0.0 \
    0.0 1.0 0.0 \
    -tremuri \
    $H_span $L_span $T_pier \
    $E $G $fc $mu0 $c $Gc $beta \
    -density $rho -cmass

# --------------------------------------------------------------------------------------------------
# RECORDERS
# --------------------------------------------------------------------------------------------------

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

# --------------------------------------------------------------------------------------------------
# STEP 2: GRAVITY ANALYSIS
# --------------------------------------------------------------------------------------------------

set topLoad [expr -1.0*$g*$rho*$L_span*$T_pier]

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

set tolF  1.0
set iter  200

system      BandGeneral
numberer    Plain
constraints Transformation
integrator  LoadControl 0.1
test        NormUnbalance $tolF $iter 0
algorithm   Newton
analysis    Static

puts "Running gravity analysis..."
set ok 0
for {set gi 0} {$gi < 10 && $ok == 0} {incr gi} {
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
    if {$ok != 0} {
        puts "Gravity failed at sub-step $gi - stopping."
        break
    }
}

if {$ok != 0} {
    puts "Gravity analysis failed."
} else {
    puts "Gravity analysis completed."
}

loadConst -time 0.0

# --------------------------------------------------------------------------------------------------
# STEP 3: RELEASE VERTICAL DOF AT NODE 2 FOR SETTLEMENT
# --------------------------------------------------------------------------------------------------

set targetSettlement  0.005
set settlSteps        10000

remove sp 2 3
wipeAnalysis

# --------------------------------------------------------------------------------------------------
# STEP 4: SETTLEMENT
# --------------------------------------------------------------------------------------------------

pattern Plain 20 Linear {
    sp 2 3 [expr -$targetSettlement]
}

set settlIncr [expr 1.0 / $settlSteps]

system      BandGeneral
numberer    Plain
constraints Transformation
test        NormUnbalance $tolF $iter 0
algorithm   Newton
integrator  LoadControl $settlIncr
analysis    Static

puts "Running settlement analysis..."

set stepS 0
set ok    0
while {$stepS < $settlSteps && $ok == 0} {
    test      NormUnbalance $tolF $iter 0
    algorithm Newton
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
    if {$ok != 0} {
        puts "Settlement failed at step $stepS - stopping."
        break
    }
    incr stepS
}

if {$ok != 0} {
    puts "Settlement stopped early at step $stepS of $settlSteps."
} else {
    puts "Settlement analysis completed."
}

loadConst -time 0.0
record
wipeAnalysis

# --------------------------------------------------------------------------------------------------
# STEP 5: HORIZONTAL PUSHOVER
# Triangular load pattern (proportional to height):
#   Floor 1 (h=  H_pier): 1/6 per node
#   Floor 2 (h=2*H_pier): 2/6 per node
#   Floor 3 (h=3*H_pier): 3/6 per node
# --------------------------------------------------------------------------------------------------

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

set controlled_node 8
set controlled_dof  1
set tolF_push 1000.0

system      BandGeneral
numberer    Plain
constraints Transformation
test        NormUnbalance $tolF_push $iter 0
algorithm   Newton
integrator  DisplacementControl $controlled_node $controlled_dof $pushIncr
analysis    Static

puts "Running horizontal pushover..."

set stepP 0
set ok    0
while {$stepP < $nSteps && $ok == 0} {
    test      NormUnbalance $tolF_push $iter 0
    algorithm Newton
    set ok [analyze 1]
    if {$ok != 0} {
        puts "Step $stepP: Newton failed - trying Newton -initial..."
        test      NormUnbalance $tolF_push $iter 0
        algorithm Newton -initial
        set ok [analyze 1]
    }
    if {$ok != 0} {
        puts "Step $stepP: Newton -initial failed - trying ModifiedNewton..."
        test      NormUnbalance $tolF_push $iter 0
        algorithm ModifiedNewton
        set ok [analyze 1]
    }
    if {$ok != 0} {
        puts "Pushover stopped at step $stepP - structure likely at capacity."
        break
    }
    incr stepP
}

if {$ok != 0} {
    puts "Pushover stopped at step $stepP (disp = [expr $stepP*$pushIncr] m)."
} else {
    puts "Pushover analysis completed successfully."
}

puts "All analyses done."
