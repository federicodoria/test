# ===========================================================================
# MASONRY FRAME — GRAVITY + SPRING SETTLEMENT + HORIZONTAL PUSHOVER
# One-Storey Building
# ===========================================================================

# ---------------------------------------------------------------------------
# PARAMETERS
# ---------------------------------------------------------------------------

set H_pier  3.0
set L_pier  1.0
set T_pier  0.25
set L_span  3.0
set H_span  0.80

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
set iter             200

set topLoad [expr -1.0*$g*$rho*$L_span*$T_pier]

# Initial spring stiffness estimate
set R_est [expr   $rho*$g*$H_pier*$L_pier*$T_pier \
               + 0.5*$rho*$g*$H_span*$L_span*$T_pier \
               + abs($topLoad)]
set k_spring [expr $R_est / $targetSettlement]
puts "Estimated reaction at node 2 : [format %.0f $R_est] N"
puts "Initial spring stiffness     : [format %.3e $k_spring] N/m"

# ---------------------------------------------------------------------------
# SPRING-GRAVITY ITERATION LOOP
# ---------------------------------------------------------------------------

set settle_tol  0.00005
set max_sit     5

for {set sit 0} {$sit < $max_sit} {incr sit} {

    wipe
    model basic -ndm 3 -ndf 6

    # ---- Nodes ----
    node 1   0.0                 0.0   0.0
    node 2   $L_span             0.0   0.0
    node 3   0.0                 0.0   $H_pier
    node 4   $L_span             0.0   $H_pier
    node 5   0.0                 0.0   [expr $H_pier/2.0]
    node 6   $L_span             0.0   [expr $H_pier/2.0]
    node 7   [expr $L_span/2.0]  0.0   $H_pier
    node 8   $L_span             0.0   0.0   ;# spring anchor

    # ---- Boundary conditions ----
    fix 1  1 1 1 1 1 1
    fix 2  1 1 0 1 1 1
    fix 8  1 1 1 1 1 1

    # ---- Vertical spring (ZeroLength) ----
    uniaxialMaterial Elastic 1 $k_spring
    element zeroLength 10  2 8  -mat 1  -dir 3

    # ---- Macroelements ----
    element Macroelement3d 1 \
        1 3 5   0.0 0.0 1.0  0.0 1.0 0.0  -tremuri \
        $H_pier $L_pier $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass -pDelta
    element Macroelement3d 2 \
        2 4 6   0.0 0.0 1.0  0.0 1.0 0.0  -tremuri \
        $H_pier $L_pier $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass -pDelta
    element Macroelement3d 3 \
        3 4 7   1.0 0.0 0.0  0.0 1.0 0.0  -tremuri \
        $H_span $L_span $T_pier  $E $G $fc $mu0 $c $Gc $beta  -density $rho -cmass -pDelta

    # ---- Gravity loads ----
    pattern Plain 10 Linear {
        eleLoad -ele 1 -type -selfWeight 0.0 0.0 [expr -$g]
        eleLoad -ele 2 -type -selfWeight 0.0 0.0 [expr -$g]
        eleLoad -ele 3 -type -selfWeight 0.0 0.0 [expr -$g]
        load 3  0.0 0.0 $topLoad 0.0 0.0 0.0
        load 4  0.0 0.0 $topLoad 0.0 0.0 0.0
    }

    # ---- Gravity analysis ----
    system      UmfPack
    numberer    Plain
    constraints Transformation
    integrator  LoadControl 0.01
    test        NormUnbalance $tolF $iter 0
    algorithm   Newton
    analysis    Static

    puts "--- Spring iter $sit  (k = [format %.3e $k_spring] N/m) ---"
    set ok 0
    for {set gi 0} {$gi < 100 && $ok == 0} {incr gi} {
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
puts "\nFinal settlement at node 2: [format %.5f $d_final] m"

remove element 10

timeSeries Constant 99
pattern Plain 99 99 {
    sp 2 3 $d_final
}

wipeAnalysis

# ---------------------------------------------------------------------------
# RECORDERS
# ---------------------------------------------------------------------------

recorder Node -file TopDisp.out        -time -node 4      -dof 1   disp
recorder Node -file BaseReaction.out   -time -node 1 2    -dof 1   reaction
recorder Node -file SettlementDisp.out -time -node 2      -dof 3   disp

recorder Element -file Pier1Force.out     -time -ele 1 force
recorder Element -file Pier2Force.out     -time -ele 2 force
recorder Element -file SpandrelForce.out  -time -ele 3 force

# ---------------------------------------------------------------------------
# HORIZONTAL PUSHOVER  (adaptive bisection stepping)
# ---------------------------------------------------------------------------

pattern Plain 30 Linear {
    load 3  0.5  0.0 0.0 0.0 0.0 0.0
    load 4  0.5  0.0 0.0 0.0 0.0 0.0
}

set targetDisp   0.3
set pushIncr     0.0001     ;# base increment (m) — 4× larger than before
set minIncr      1.0e-7     ;# abort if step shrinks below this
set nSteps       [expr int($targetDisp / $pushIncr)]

system      UmfPack
numberer    Plain
constraints Transformation
test        NormUnbalance $tolF $iter 0
algorithm   Newton
integrator  DisplacementControl 4 1 $pushIncr
analysis    Static

puts "Running horizontal pushover  (target = $targetDisp m, base incr = $pushIncr m)..."

set stepP       0
set ok          0
set currentIncr $pushIncr
set dispDone    0.0

while {$dispDone < $targetDisp} {

    # --- try Newton ---
    integrator DisplacementControl 4 1 $currentIncr
    test      NormUnbalance $tolF $iter 0
    algorithm Newton
    set ok [analyze 1]

    # --- fallback: Newton -initial ---
    if {$ok != 0} {
        test      NormUnbalance $tolF $iter 0
        algorithm Newton -initial
        set ok [analyze 1]
    }

    # --- fallback: KrylovNewton ---
    if {$ok != 0} {
        test      NormUnbalance $tolF $iter 0
        algorithm KrylovNewton
        set ok [analyze 1]
    }

    # --- fallback: ModifiedNewton ---
    if {$ok != 0} {
        test      NormUnbalance $tolF $iter 0
        algorithm ModifiedNewton
        set ok [analyze 1]
    }

    if {$ok == 0} {
        # step converged — accumulate displacement and restore base increment
        set dispDone    [expr $dispDone + $currentIncr]
        set currentIncr $pushIncr
        incr stepP
    } else {
        # bisect the step size
        set currentIncr [expr $currentIncr / 2.0]
        if {$currentIncr < $minIncr} {
            puts "Pushover stopped: step < minIncr at disp = [format %.5f $dispDone] m  (base shear load factor ~ [format %.1f [expr $stepP*$pushIncr]] m done)"
            break
        }
        puts "Step $stepP: bisecting → incr = [format %.2e $currentIncr] m"
    }
}

if {$dispDone >= $targetDisp} {
    puts "Pushover completed successfully ([format %.3f $dispDone] m)."
} else {
    puts "Pushover ended at disp = [format %.5f $dispDone] m."
}
puts "All analyses done."
