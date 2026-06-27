# --------------------------------------------------------------------------------------------------
# MASONRY FRAME PUSHOVER ANALYSIS WITH SETTLEMENT
# One-Storey Building
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
# --------------------------------------------------------------------------------------------------

node 1   0.0                  0.0   0.0
node 2   $L_span              0.0   0.0
node 3   0.0                  0.0   $H_pier
node 4   $L_span              0.0   $H_pier
node 5   0.0                  0.0   [expr $H_pier/2.0]
node 6   $L_span              0.0   [expr $H_pier/2.0]
node 7   [expr $L_span/2.0]   0.0   $H_pier

# --------------------------------------------------------------------------------------------------
# STEP 1: INITIAL BOUNDARY CONDITIONS — both bases fully fixed
# --------------------------------------------------------------------------------------------------

fix 1  1 1 1 1 1 1
fix 2  1 1 1 1 1 1

# --------------------------------------------------------------------------------------------------
# MACROELEMENTS
# --------------------------------------------------------------------------------------------------

element Macroelement3d 1 \
    1 3 5 \
    0.0 0.0 1.0 \
    0.0 1.0 0.0 \
    -tremuri \
    $H_pier $L_pier $T_pier \
    $E $G $fc $mu0 $c $Gc $beta \
    -density $rho \
    -cmass \
    -pDelta

element Macroelement3d 2 \
    2 4 6 \
    0.0 0.0 1.0 \
    0.0 1.0 0.0 \
    -tremuri \
    $H_pier $L_pier $T_pier \
    $E $G $fc $mu0 $c $Gc $beta \
    -density $rho \
    -cmass \
    -pDelta

element Macroelement3d 3 \
    3 4 7 \
    1.0 0.0 0.0 \
    0.0 1.0 0.0 \
    -tremuri \
    $H_span $L_span $T_pier \
    $E $G $fc $mu0 $c $Gc $beta \
    -density $rho \
    -cmass \
    -pDelta

# --------------------------------------------------------------------------------------------------
# RECORDERS
# --------------------------------------------------------------------------------------------------

recorder Node \
    -file TopDisp.out \
    -time \
    -node 4 \
    -dof 1 \
    disp

recorder Node \
    -file BaseReaction.out \
    -time \
    -node 1 2 \
    -dof 1 3 \
    reaction

recorder Node \
    -file SettlementDisp.out \
    -time \
    -node 2 \
    -dof 3 \
    disp

recorder Element \
    -file Pier1Force.out \
    -time \
    -ele 1 \
    force

recorder Element \
    -file Pier2Force.out \
    -time \
    -ele 2 \
    force

recorder Element \
    -file SpandrelForce.out \
    -time \
    -ele 3 \
    force

# --------------------------------------------------------------------------------------------------
# STEP 2: GRAVITY ANALYSIS
# --------------------------------------------------------------------------------------------------

set topLoad [expr -5.0*$g*$rho*$L_span*$T_pier]

pattern Plain 10 Linear {
    eleLoad -ele 1 -type -selfWeight 0.0 0.0 [expr -$g]
    eleLoad -ele 2 -type -selfWeight 0.0 0.0 [expr -$g]
    eleLoad -ele 3 -type -selfWeight 0.0 0.0 [expr -$g]

    load 3  0.0 0.0 $topLoad 0.0 0.0 0.0
    load 4  0.0 0.0 $topLoad 0.0 0.0 0.0
}

# tolF : force unbalance tolerance (N)
# iter : max Newton iterations per step
set tolF  1.0
set iter  200

system      BandGeneral
numberer    Plain
constraints Transformation
integrator  LoadControl 1.0
test        NormUnbalance $tolF $iter 2
algorithm   Newton
analysis    Static

puts "Running gravity analysis..."
set ok [analyze 1]

if {$ok != 0} {
    puts "Gravity analysis failed."
} else {
    puts "Gravity analysis completed."
}

loadConst -time 0.0

# --------------------------------------------------------------------------------------------------
# STEP 3: RELEASE VERTICAL DOF AT NODE 2 and set up imposed settlement
# DOF order: 1=X  2=Y  3=Z(vertical)  4=Rx  5=Ry  6=Rz
#
# Approach: "sp inside a load pattern" + LoadControl
#   - Transformation handler enforces the prescribed disp kinematically (DOF eliminated)
#   - At load factor 0: imposed disp = 0 (matches original fixed state, zero unbalance)
#   - At load factor 1: imposed disp = -targetSettlement
#   - This avoids the large initial unbalance from suddenly releasing the support reaction
# --------------------------------------------------------------------------------------------------

set targetSettlement  0.05;   # target settlement (m) — adjust as needed
set settlSteps        1000;   # load steps to reach full settlement

# Remove the homogeneous (zero) fixed SP at node 2 DOF 3 before adding the ramped one
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
test        NormUnbalance $tolF $iter 2
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
        puts "Settlement failed at step $stepS — stopping."
        break
    }
    incr stepS
}

if {$ok != 0} {
    puts "Settlement stopped early at step $stepS of $settlSteps."
} else {
    puts "Settlement analysis completed."
}

# Freeze settlement at final position (load factor = 1, imposed disp = -targetSettlement).
# The frozen pattern 20 sp constraint keeps node 2 DOF 3 at the settled value —
# no need to re-fix node 2 manually.
loadConst -time 0.0
record

# --------------------------------------------------------------------------------------------------
# STEP 5: wipeAnalysis — no re-fix needed, pattern 20 holds the settlement
# --------------------------------------------------------------------------------------------------

wipeAnalysis

# --------------------------------------------------------------------------------------------------
# STEP 6: HORIZONTAL PUSHOVER
# --------------------------------------------------------------------------------------------------

pattern Plain 30 Linear {
    load 3  0.5 0.0 0.0 0.0 0.0 0.0
    load 4  0.5 0.0 0.0 0.0 0.0 0.0
}

set targetDisp  0.4;     # target horizontal displacement (m)
set pushIncr    0.00005; # displacement increment per step (m)
set nSteps      [expr int($targetDisp / $pushIncr)]

set controlled_node 4
set controlled_dof  1

system      BandGeneral
numberer    Plain
constraints Transformation
test        NormUnbalance $tolF $iter 2
algorithm   Newton
integrator  DisplacementControl $controlled_node $controlled_dof $pushIncr
analysis    Static

puts "Running horizontal pushover..."

set stepP 0
set ok    0
while {$stepP < $nSteps && $ok == 0} {
    test      NormUnbalance $tolF $iter 0
    algorithm Newton
    set ok [analyze 1]

    if {$ok != 0} {
        puts "Step $stepP: Newton failed — trying Newton -initial..."
        test      NormUnbalance $tolF $iter 0
        algorithm Newton -initial
        set ok [analyze 1]
    }

    if {$ok != 0} {
        puts "Step $stepP: Newton -initial failed — trying ModifiedNewton..."
        test      NormUnbalance $tolF $iter 0
        algorithm ModifiedNewton
        set ok [analyze 1]
    }

    if {$ok != 0} {
        puts "Pushover stopped at step $stepP — structure likely at capacity."
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
