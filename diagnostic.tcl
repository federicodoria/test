# =====================================================================================
# DIAGNOSTIC SCRIPT — run this BEFORE the main analysis
# It collects environment info and tests that Macroelement3d is available.
# Copy the full output and share it for further support.
# =====================================================================================

puts "============================================================"
puts "  OpenSees / Tcl Environment Diagnostic"
puts "============================================================"

# --- Tcl version ---------------------------------------------------------------
puts "\n--- Tcl ---"
puts "Tcl version : [info tclversion]"
puts "Tcl patchlevel : [info patchlevel]"

# --- OpenSees version ----------------------------------------------------------
puts "\n--- OpenSees ---"
if {[catch {version} ver]} {
    puts "OpenSees version command not available: $ver"
} else {
    puts "OpenSees version : $ver"
}

# --- Loaded packages -----------------------------------------------------------
puts "\n--- Loaded packages ---"
foreach pkg [package names] {
    set v [package provide $pkg]
    if {$v ne ""} { puts "  $pkg  $v" }
}

# --- Test: basic model setup ---------------------------------------------------
puts "\n--- Testing basic model setup ---"
if {[catch {
    wipe
    model basic -ndm 3 -ndf 6
    puts "  model basic -ndm 3 -ndf 6 : OK"
} err]} {
    puts "  FAILED: $err"
}

# --- Test: node creation -------------------------------------------------------
puts "\n--- Testing node creation ---"
if {[catch {
    node 1  0.0  0.0  0.0
    node 2  3.0  0.0  0.0
    node 3  0.0  0.0  3.0
    node 4  3.0  0.0  3.0
    node 9  0.0  0.0  1.5
    puts "  node creation : OK"
} err]} {
    puts "  FAILED: $err"
}

# --- Test: Macroelement3d availability -----------------------------------------
puts "\n--- Testing Macroelement3d element ---"
if {[catch {
    fix 1 1 1 1 1 1 1
    fix 2 1 1 1 1 1 1
    element Macroelement3d 1 \
        1 3 9 \
        0.0 0.0 1.0 \
        0.0 1.0 0.0 \
        -tremuri \
        3.0 1.0 0.25 \
        1700.0e6 550.0e6 6.0e6 0.40 0.150e6 6.0 0.30 \
        -density 1200.0 \
        -cmass \
        -pDelta
    puts "  Macroelement3d -tremuri : OK"
} err]} {
    puts "  FAILED: $err"
    puts "  >> This is the element the main script depends on."
    puts "  >> If this fails, the extension is not loaded or the syntax differs."
}

# --- Test: eleLoad selfWeight --------------------------------------------------
puts "\n--- Testing eleLoad -selfWeight ---"
if {[catch {
    pattern Plain 1 Linear {
        eleLoad -ele 1 -type -selfWeight 0.0 0.0 -9.81
    }
    puts "  eleLoad -selfWeight : OK"
} err]} {
    puts "  FAILED: $err"
}

# --- Test: DisplacementControl integrator -------------------------------------
puts "\n--- Testing DisplacementControl integrator ---"
if {[catch {
    system BandGeneral
    numberer Plain
    constraints Transformation
    test NormUnbalance 1.0 10 0
    algorithm Newton
    integrator DisplacementControl 3 1 0.001
    analysis Static
    puts "  DisplacementControl setup : OK"
} err]} {
    puts "  FAILED: $err"
}

# --- Test: sp command in pattern ----------------------------------------------
puts "\n--- Testing sp command in pattern (settlement) ---"
wipe
model basic -ndm 3 -ndf 6
node 1 0.0 0.0 0.0
node 2 0.0 0.0 3.0
node 3 0.0 0.0 1.5
# Note: DOF 3 left FREE on node 1 to allow settlement
fix 1 1 1 0 1 1 1
fix 2 1 1 1 1 1 1
if {[catch {
    pattern Plain 20 Linear {
        sp 1 3 -0.001
    }
    puts "  sp in pattern : OK (syntax accepted)"
} err]} {
    puts "  FAILED: $err"
}

puts "\n============================================================"
puts "  Diagnostic complete."
puts "  Please copy everything above this line and share it."
puts "============================================================\n"
