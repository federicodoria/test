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

node 1   0.0            0.0   0.0
node 2   $L_span        0.0   0.0
node 3   0.0            0.0   $H_pier
node 4   $L_span        0.0   $H_pier
node 5   0.0            0.0   [expr $H_pier/2.0]
node 6   $L_span        0.0   [expr $H_pier/2.0]
node 7   [expr $L_span/2.0]  0.0  $H_pier

# --------------------------------------------------------------------------------------------------
# STEP 1: INITIAL BOUNDARY CONDITIONS — Both bases fully fixed
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

set tol  1.0e-4
set iter 100

system     BandGeneral
numberer   Plain
constraints Transformation
integrator LoadControl 1.0
test       NormDispIncr $tol $iter 5
algorithm  Newton
analysis   Static

puts "Running gravity analysis..."
set ok [analyze 1]

if {$ok != 0} {
    puts "Gravity analysis failed."
} else {
    puts "Gravity analysis completed."
}

# Fix loads at current state; reset pseudo-time to 0
loadConst -time 0.0

# --------------------------------------------------------------------------------------------------
# STEP 3: RELEASE VERTICAL DOF AT NODE 2 (settlement phase preparation)
# DOF order: 1=X  2=Y  3=Z(vertical)  4=Rx  5=Ry  6=Rz
# Must remove the existing SP constraint on DOF 3 before it can be freed
# --------------------------------------------------------------------------------------------------

remove sp 2 3

wipeAnalysis

# --------------------------------------------------------------------------------------------------
# STEP 4: SETTLEMENT — Displacement-controlled vertical pushdown at node 2
# Apply a reference downward unit force at node 2 (DOF 3, negative Z = downward)
# --------------------------------------------------------------------------------------------------

pattern Plain 20 Linear {
    load 2  0.0 0.0 -1.0 0.0 0.0 0.0
}

set targetSettlement  0.05;   # target settlement (m), adjust as needed
set settlIncr         0.0001; # displacement increment per step (m)
set settlSteps        [expr int($targetSettlement / $settlIncr)]

system      BandGeneral
numberer    Plain
constraints Transformation
test        NormDispIncr $tol $iter 5
algorithm   Newton
integrator  DisplacementControl 2 3 [expr -$settlIncr]
analysis    Static

puts "Running settlement analysis..."

set ok [analyze $settlSteps]

if {$ok != 0} {
    puts "Standard Newton failed during settlement. Switching to Newton -initial..."
    test      NormDispIncr $tol [expr $iter*2] 5
    algorithm Newton -initial
    set ok [analyze $settlSteps]
}

if {$ok != 0} {
    puts "Settlement analysis did not fully converge."
} else {
    puts "Settlement analysis completed."
}

# Freeze all loads and reactions at post-settlement state; reset pseudo-time
loadConst -time 0.0
record

# --------------------------------------------------------------------------------------------------
# STEP 5: RE-FIX NODE 2 (restore vertical fixity after settlement)
# DOFs 1,2,4,5,6 are still constrained from the original fix command
# Only DOF 3 was removed, so only DOF 3 needs to be re-added
# --------------------------------------------------------------------------------------------------

fix 2  0 0 1 0 0 0

wipeAnalysis

# --------------------------------------------------------------------------------------------------
# STEP 6: HORIZONTAL PUSHOVER
# --------------------------------------------------------------------------------------------------

pattern Plain 30 Linear {
    load 3  0.5 0.0 0.0 0.0 0.0 0.0
    load 4  0.5 0.0 0.0 0.0 0.0 0.0
}

set targetDisp  0.4;    # target horizontal displacement (m)
set pushIncr    0.0001; # displacement increment per step (m)
set nSteps      [expr int($targetDisp / $pushIncr)]

set controlled_node 4
set controlled_dof  1

system      BandGeneral
numberer    Plain
constraints Transformation
test        NormDispIncr $tol $iter 5
algorithm   Newton
integrator  DisplacementControl $controlled_node $controlled_dof $pushIncr
analysis    Static

puts "Running horizontal pushover..."

set ok [analyze $nSteps]

if {$ok != 0} {
    puts "Standard Newton failed during pushover. Switching to Newton -initial..."
    test      NormDispIncr $tol [expr $iter*2] 5
    algorithm Newton -initial
    set ok [analyze $nSteps]
}

if {$ok != 0} {
    puts "Pushover did not fully converge at target displacement."
} else {
    puts "Pushover analysis completed successfully."
}

puts "All analyses done."
