# =====================================================================================
# 3-STOREY MASONRY FRAME
# GRAVITY + FOUNDATION SETTLEMENT + PUSHOVER
#
# Corrections applied vs. original:
#   FIX 1 — zero-stiffness DOFs at internal nodes constrained (singular matrix fix)
#   FIX 2 — pushover convergence test changed to NormDispIncr (post-peak regime)
#   FIX 3 — pushover fallback replaced with step-by-step loop (no target overshoot)
# =====================================================================================

wipe
model basic -ndm 3 -ndf 6

# =====================================================================================
# GEOMETRY
# =====================================================================================

set H_story 3.0
set L_span  3.0

set L_pier  1.0
set T_pier  0.25
set H_span  0.80

# =====================================================================================
# MATERIAL
# =====================================================================================

set E       1700.0e6
set G       550.0e6
set fc      6.0e6
set c       0.150e6
set Gc      6.0
set mu0     0.40
set beta    0.30

set rho     1200.0
set g       9.81

# =====================================================================================
# NODES
# =====================================================================================

# Base
node 1   0.0      0.0   0.0
node 2   $L_span  0.0   0.0

# First floor
node 3   0.0      0.0   $H_story
node 4   $L_span  0.0   $H_story

# Second floor
node 5   0.0      0.0   [expr 2.0*$H_story]
node 6   $L_span  0.0   [expr 2.0*$H_story]

# Roof
node 7   0.0      0.0   [expr 3.0*$H_story]
node 8   $L_span  0.0   [expr 3.0*$H_story]

# Internal pier nodes (mid-height of each storey)
node 9   0.0      0.0   [expr 0.5*$H_story]
node 10  $L_span  0.0   [expr 0.5*$H_story]

node 11  0.0      0.0   [expr 1.5*$H_story]
node 12  $L_span  0.0   [expr 1.5*$H_story]

node 13  0.0      0.0   [expr 2.5*$H_story]
node 14  $L_span  0.0   [expr 2.5*$H_story]

# Internal spandrel nodes (mid-span of each floor beam)
node 15  [expr $L_span/2.0] 0.0 $H_story
node 16  [expr $L_span/2.0] 0.0 [expr 2.0*$H_story]
node 17  [expr $L_span/2.0] 0.0 [expr 3.0*$H_story]

# =====================================================================================
# BOUNDARY CONDITIONS
# =====================================================================================

fix 1  1 1 1 1 1 1
fix 2  1 1 1 1 1 1

# =====================================================================================
# FIX 1 — CONSTRAIN ZERO-STIFFNESS DOFs AT INTERNAL NODES
#
# This fixes the "matrix singular U(i,i) = 0" crash during pushover.
#
# Internal nodes are connected to exactly one element each. For a planar model
# in 3D space, several DOFs at these nodes receive zero stiffness contribution
# from the element:
#
# Pier internal nodes (9-14): element axis = global Z (vertical)
#   → no stiffness on Y, Rx, Rz  →  fix those three
#   → X, Z, Ry remain free (in-plane response)
#
# Spandrel internal nodes (15-17): element axis = global X (horizontal)
#   → no stiffness on Y, Z, Rx, Rz  →  fix those four
#   → X and Ry remain free
#
# DOF order: [X  Y  Z  Rx  Ry  Rz]
#             [1  2  3   4   5   6]
# =====================================================================================

foreach n {9 10 11 12 13 14} {
    fix $n  0 1 0 1 0 1
}

foreach n {15 16 17} {
    fix $n  0 1 1 1 0 1
}

# =====================================================================================
# PIER ELEMENTS
# =====================================================================================

# Storey 1

element Macroelement3d 1 \
    1 3 9 \
    0.0 0.0 1.0 \
    0.0 1.0 0.0 \
    -tremuri \
    $H_story $L_pier $T_pier \
    $E $G $fc $mu0 $c $Gc $beta \
    -density $rho \
    -cmass \
    -pDelta

element Macroelement3d 2 \
    2 4 10 \
    0.0 0.0 1.0 \
    0.0 1.0 0.0 \
    -tremuri \
    $H_story $L_pier $T_pier \
    $E $G $fc $mu0 $c $Gc $beta \
    -density $rho \
    -cmass \
    -pDelta

# Storey 2

element Macroelement3d 3 \
    3 5 11 \
    0.0 0.0 1.0 \
    0.0 1.0 0.0 \
    -tremuri \
    $H_story $L_pier $T_pier \
    $E $G $fc $mu0 $c $Gc $beta \
    -density $rho \
    -cmass \
    -pDelta

element Macroelement3d 4 \
    4 6 12 \
    0.0 0.0 1.0 \
    0.0 1.0 0.0 \
    -tremuri \
    $H_story $L_pier $T_pier \
    $E $G $fc $mu0 $c $Gc $beta \
    -density $rho \
    -cmass \
    -pDelta

# Storey 3

element Macroelement3d 5 \
    5 7 13 \
    0.0 0.0 1.0 \
    0.0 1.0 0.0 \
    -tremuri \
    $H_story $L_pier $T_pier \
    $E $G $fc $mu0 $c $Gc $beta \
    -density $rho \
    -cmass \
    -pDelta

element Macroelement3d 6 \
    6 8 14 \
    0.0 0.0 1.0 \
    0.0 1.0 0.0 \
    -tremuri \
    $H_story $L_pier $T_pier \
    $E $G $fc $mu0 $c $Gc $beta \
    -density $rho \
    -cmass \
    -pDelta

# =====================================================================================
# SPANDREL ELEMENTS
# =====================================================================================

element Macroelement3d 7 \
    3 4 15 \
    1.0 0.0 0.0 \
    0.0 1.0 0.0 \
    -tremuri \
    $H_span $L_span $T_pier \
    $E $G $fc $mu0 $c $Gc $beta \
    -density $rho \
    -cmass \
    -pDelta

element Macroelement3d 8 \
    5 6 16 \
    1.0 0.0 0.0 \
    0.0 1.0 0.0 \
    -tremuri \
    $H_span $L_span $T_pier \
    $E $G $fc $mu0 $c $Gc $beta \
    -density $rho \
    -cmass \
    -pDelta

element Macroelement3d 9 \
    7 8 17 \
    1.0 0.0 0.0 \
    0.0 1.0 0.0 \
    -tremuri \
    $H_span $L_span $T_pier \
    $E $G $fc $mu0 $c $Gc $beta \
    -density $rho \
    -cmass \
    -pDelta

# =====================================================================================
# RECORDERS
# =====================================================================================

recorder Node \
    -file RoofDisp.out \
    -time \
    -node 8 \
    -dof 1 \
    disp

recorder Node \
    -file SupportReaction.out \
    -time \
    -node 1 2 \
    -dof 1 \
    reaction

recorder Element -file PierForces.out -time -ele 1 2 3 4 5 6 basicForce
recorder Element -file SpanForces.out -time -ele 7 8 9        basicForce

# =====================================================================================
# GRAVITY LOADS
#
# Note on floor load formula:
# floorLoad = 5.0 * g * rho * L_span * T_pier
# Dimensionally this equals the weight of a masonry block (5.0 m tall, L_span x T_pier
# cross-section). If 5.0 represents an equivalent tributary height in metres, the
# formula is correct. If it was intended as a 5 kN/m² pressure, replace with:
#   set floorLoad [expr -5.0e3 * $L_span * $T_pier]
# =====================================================================================

set floorLoad [expr -5.0*$g*$rho*$L_span*$T_pier]

pattern Plain 10 Linear {

    for {set e 1} {$e <= 9} {incr e} {
        eleLoad -ele $e -type -selfWeight 0.0 0.0 [expr -$g]
    }

    load 3 0.0 0.0 $floorLoad 0.0 0.0 0.0
    load 4 0.0 0.0 $floorLoad 0.0 0.0 0.0

    load 5 0.0 0.0 $floorLoad 0.0 0.0 0.0
    load 6 0.0 0.0 $floorLoad 0.0 0.0 0.0

    load 7 0.0 0.0 $floorLoad 0.0 0.0 0.0
    load 8 0.0 0.0 $floorLoad 0.0 0.0 0.0
}

system BandGeneral
numberer Plain
constraints Transformation

test NormUnbalance 1.0 50 0
algorithm Newton

integrator LoadControl 0.01
analysis Static

puts "Applying gravity loads..."

analyze 100

loadConst -time 0.0

# =====================================================================================
# FOUNDATION SETTLEMENT
# =====================================================================================

pattern Plain 20 Linear {
    sp 1 3 -0.001
}

integrator LoadControl 0.01

puts "Applying settlement..."

analyze 200

loadConst -time 0.0

record

# =====================================================================================
# PUSHOVER LOAD PATTERN
# =====================================================================================

pattern Plain 30 Linear {

    load 3 0.20 0.0 0.0 0.0 0.0 0.0
    load 4 0.20 0.0 0.0 0.0 0.0 0.0

    load 5 0.40 0.0 0.0 0.0 0.0 0.0
    load 6 0.40 0.0 0.0 0.0 0.0 0.0

    load 7 0.60 0.0 0.0 0.0 0.0 0.0
    load 8 0.60 0.0 0.0 0.0 0.0 0.0
}

# =====================================================================================
# PUSHOVER ANALYSIS
# =====================================================================================

constraints Transformation
numberer Plain
system BandGeneral

# FIX 2 — NormDispIncr instead of NormUnbalance for pushover.
# In the post-peak softening regime the tangent stiffness is near zero,
# so force residuals remain large even when displacements are fully converged.
# NormDispIncr checks the displacement correction between Newton iterations,
# which is the appropriate convergence measure for displacement-controlled pushover.

test NormDispIncr 1.0e-6 100 0
algorithm Newton

analysis Static

set targetDisp 0.20
set incr       0.0001

set nSteps [expr int($targetDisp/$incr)]

set controlled_node 8
set controlled_dof  1

integrator DisplacementControl \
    $controlled_node \
    $controlled_dof \
    $incr

puts "Running pushover..."

# FIX 3 — Step-by-step loop with algorithm switching.
# The original script re-ran the full $nSteps count after a failure,
# potentially driving the roof far past the 0.20 m target.
# This loop advances one step at a time and switches algorithm only when
# needed, then reverts to standard Newton as soon as convergence is restored.

set completedSteps 0
set usingInitial   0

while {$completedSteps < $nSteps} {

    set ok [analyze 1]

    if {$ok == 0} {
        incr completedSteps
        if {$usingInitial} {
            algorithm Newton
            test NormDispIncr 1.0e-6 100 0
            set usingInitial 0
        }
    } else {
        if {!$usingInitial} {
            puts "Step $completedSteps: Newton failed — switching to Newton -initial"
            test NormDispIncr 1.0e-5 200 5
            algorithm Newton -initial
            set usingInitial 1
        }
        set ok [analyze 1]
        if {$ok == 0} {
            incr completedSteps
        } else {
            puts "Analysis stopped at step $completedSteps / $nSteps"
            puts "Roof displacement at stop: [expr $completedSteps * $incr] m"
            break
        }
    }

    if {[expr $completedSteps % 200] == 0 && $completedSteps > 0} {
        puts "  Step $completedSteps / $nSteps  \
([expr $completedSteps * $incr] m)"
    }
}

puts "Pushover completed: $completedSteps of $nSteps steps."
puts "Final roof displacement: [expr $completedSteps * $incr] m"
puts "Results written to: RoofDisp.out, SupportReaction.out"
puts "Element results  : PierForces.out, SpanForces.out"
