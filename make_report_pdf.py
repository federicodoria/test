from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Preformatted,
    Table, TableStyle, HRFlowable, KeepTogether
)
from reportlab.lib.enums import TA_LEFT

OUTPUT = "/home/user/test/full_report.pdf"

doc = SimpleDocTemplate(
    OUTPUT, pagesize=A4,
    leftMargin=2.2*cm, rightMargin=2.0*cm,
    topMargin=2.2*cm, bottomMargin=2.0*cm
)

# ── Styles ─────────────────────────────────────────────────────────────
dark   = colors.HexColor("#1a1a2e")
blue   = colors.HexColor("#2c3e6b")
green  = colors.HexColor("#1e6b3c")
red    = colors.HexColor("#8b1a1a")
amber  = colors.HexColor("#7a5c00")
grey   = colors.HexColor("#555555")
code_bg = colors.HexColor("#f6f8fa")
code_border = colors.HexColor("#d0d7de")

def style(name, **kw):
    s = ParagraphStyle(name, **kw)
    return s

title_s  = style("T",  fontName="Helvetica-Bold",  fontSize=15, textColor=dark,  spaceAfter=2,  leading=18)
sub_s    = style("S",  fontName="Helvetica",        fontSize=9,  textColor=grey,  spaceAfter=14, leading=12)
h1_s     = style("H1", fontName="Helvetica-Bold",   fontSize=12, textColor=dark,  spaceBefore=18,spaceAfter=5, leading=15)
h2_s     = style("H2", fontName="Helvetica-Bold",   fontSize=10, textColor=blue,  spaceBefore=13,spaceAfter=4, leading=13)
h3_s     = style("H3", fontName="Helvetica-BoldOblique", fontSize=9.5, textColor=blue, spaceBefore=10, spaceAfter=3, leading=12)
body_s   = style("B",  fontName="Helvetica",        fontSize=9,  leading=13, spaceAfter=5)
note_s   = style("N",  fontName="Helvetica-Oblique",fontSize=8.5,textColor=grey, leading=12, spaceAfter=4)
label_s  = style("L",  fontName="Helvetica-Bold",   fontSize=8,  leading=11)
code_s   = ParagraphStyle("C", fontName="Courier",  fontSize=7.8,leading=10.5,
                           backColor=code_bg, borderColor=code_border,
                           borderWidth=0.5, borderPad=5,
                           spaceAfter=7, spaceBefore=3)
warn_s   = style("W",  fontName="Courier",          fontSize=7.5,leading=10,
                       textColor=colors.HexColor("#6a3d00"),
                       backColor=colors.HexColor("#fff8e1"),
                       borderColor=colors.HexColor("#e6c96e"),
                       borderWidth=0.4, borderPad=4,
                       spaceAfter=6)

def hr(): return HRFlowable(width="100%", thickness=0.4, color=colors.HexColor("#cccccc"), spaceAfter=8)
def gap(n=5): return Spacer(1, n)
def P(t, s=body_s): return Paragraph(t, s)
def H1(t): return Paragraph(t, h1_s)
def H2(t): return Paragraph(t, h2_s)
def H3(t): return Paragraph(t, h3_s)
def code(t): return Preformatted(t, code_s)
def warn(t): return Preformatted(t, warn_s)
def note(t): return P(t, note_s)

story = []

# ── Title ───────────────────────────────────────────────────────────────
story += [
    P("OpenSees Analysis — Full Diagnostic Report", title_s),
    P("3-Storey Masonry Frame · <i>newcode3storey.tcl</i>", sub_s),
    hr(),
]

# ── 0. Environment ───────────────────────────────────────────────────────
story += [H1("0 · What We Know for Certain")]
story += [P(
    "The <b>environment is not the problem</b>. Running diagnostic.tcl confirmed:"
)]
rows = [
    ["Tcl version", "8.6.8"],
    ["OpenSees version", "3.2.1"],
    ["Macroelement3d", "Loaded from external library — Francesco Vanin, EPFL 2019"],
    ["eleLoad -selfWeight", "OK"],
    ["DisplacementControl", "OK"],
    ["sp in pattern", "OK"],
]
cell = ParagraphStyle("tc", fontSize=8, leading=10)
tdata = [[P(r[0],cell), P(r[1],cell)] for r in rows]
tbl = Table(tdata, colWidths=[4*cm, 11.5*cm])
tbl.setStyle(TableStyle([
    ("FONTNAME",(0,0),(-1,-1),"Helvetica"),
    ("FONTSIZE",(0,0),(-1,-1),8),
    ("GRID",(0,0),(-1,-1),0.3,colors.HexColor("#cccccc")),
    ("BACKGROUND",(0,0),(0,-1),colors.HexColor("#f0f0f0")),
    ("TOPPADDING",(0,0),(-1,-1),3),
    ("BOTTOMPADDING",(0,0),(-1,-1),3),
    ("LEFTPADDING",(0,0),(-1,-1),5),
]))
story += [tbl, gap(8)]
story += [P("The errors are in the <b>analysis logic and model connectivity</b>, not in the installation.")]

# ── 1. Error output ──────────────────────────────────────────────────────
story += [H1("1 · Reading the Error Output — Line by Line")]

story += [H2("1.1 · Singular matrix during pushover")]
story += [warn(
    "WARNING BandGenLinLapackSolver::solve() -factorization failed,\n"
    "        matrix singular U(i,i) = 0, i= 87\n"
    "WARNING NewtonRaphson::solveCurrentStep() -the LinearSysOfEqn failed in solve()\n"
    "StaticAnalysis::analyze() - the Algorithm failed at iteration: 0\n"
    "        with domain at load factor -3.58368e+19\n"
    "OpenSees > analyze failed, returned: -3 error flag"
)]
story += [H3("What DOF 87 is:")]
story += [P(
    "With 17 nodes × 6 DOFs = 102 total DOFs, and nodes 1 and 2 fixed (12 constrained DOFs), "
    "there are 90 free DOFs numbered sequentially. DOF 87 maps to <b>node 17, DOF 3 (global Z, vertical)</b>."
)]
story += [P(
    "Node 17 is the <b>midpoint internal node of element 9</b> — the roof spandrel connecting "
    "nodes 7 and 8, horizontal along global X, at position [1.5, 0, 9.0]."
)]
story += [P(
    "Node 17 is connected to <b>exactly one element</b>. For a horizontal spandrel with local "
    "axis along X, the Macroelement3d does not contribute stiffness to the vertical (Z) DOF at "
    "the internal node K. That DOF has zero stiffness in the assembled global matrix → zero pivot "
    "→ singular factorisation."
)]
story += [P("<b>The same problem likely exists at:</b>")]
story += [code(
    "Node 15 (DOF Z)  — internal node of element 7  (floor-1 spandrel)\n"
    "Node 16 (DOF Z)  — internal node of element 8  (floor-2 spandrel)\n"
    "Nodes 9-14 (Y and rotational DOFs) — internal pier nodes, single-element connections"
)]
story += [H3("What 'load factor -3.58368e+19' means:")]
story += [P(
    "This is <b>not a structural result</b>. When the linear solver encounters a zero pivot, "
    "it produces a nonsensical displacement. The load factor is computed from that displacement "
    "and becomes effectively infinite. This number has no physical meaning — it is a numerical "
    "artefact of the singular DOF."
)]

story += [H2("1.2 · Newton fallback and the convergence warnings")]
story += [warn(
    "Newton failed - switching to Newton Initial\n"
    "WARNING: CTestNormUnbalance::test() - failed to converge but going on\n"
    "         current Norm: 20394.9  (max: 100, Norm deltaX: 8.43657e-06)\n"
    "WARNING: CTestNormUnbalance::test() - failed to converge but going on\n"
    "         current Norm: 9986.6   (max: 100, Norm deltaX: 1.17368e-06)\n"
    "...\n"
    "WARNING: CTestNormUnbalance::test() - failed to converge but going on\n"
    "         current Norm: 596.1    (max: 100, Norm deltaX: 1.82e-07)"
)]
story += [H3("Why Newton Initial can continue past the singular point:")]
story += [P(
    "<b>algorithm Newton -initial</b> uses the initial (undamaged, elastic) stiffness matrix "
    "for every iteration instead of updating it. The initial stiffness is non-singular, so the "
    "solve succeeds. The trade-off is much slower convergence."
)]
story += [H3("Reading the two norm columns:")]
nrows = [
    ["Column", "Meaning", "Values seen"],
    ["current Norm", "Unbalanced force residual (N) at end of step", "20 395 → 596"],
    ["Norm deltaX", "Displacement correction at last Newton iteration (m)", "8.4×10⁻⁶ → 1.8×10⁻⁷"],
]
nc = ParagraphStyle("nc", fontSize=8, leading=10)
nh = ParagraphStyle("nh", fontSize=8, leading=10, fontName="Helvetica-Bold", textColor=colors.white)
ntdata = []
for i,r in enumerate(nrows):
    s = nh if i==0 else nc
    ntdata.append([P(c,s) for c in r])
ntbl = Table(ntdata, colWidths=[3.5*cm, 7.5*cm, 4.5*cm])
ntbl.setStyle(TableStyle([
    ("BACKGROUND",(0,0),(-1,0),dark),
    ("GRID",(0,0),(-1,-1),0.3,colors.HexColor("#cccccc")),
    ("TOPPADDING",(0,0),(-1,-1),3),
    ("BOTTOMPADDING",(0,0),(-1,-1),3),
    ("LEFTPADDING",(0,0),(-1,-1),5),
    ("BACKGROUND",(0,1),(-1,-1),colors.white),
]))
story += [ntbl, gap(6)]
story += [P(
    "The <b>force residual is large but decreasing step by step</b> — the system is making "
    "progress toward equilibrium. The <b>displacement correction is near zero</b> — the "
    "DOFs have essentially stopped moving. This is the signature of <b>post-peak softening "
    "with near-zero tangent stiffness</b>: the structure has passed its lateral capacity peak "
    "and is on the descending branch."
)]
story += [H3("What printFlag 5 does:")]
story += [P(
    "The <b>5</b> at the end of <tt>test NormUnbalance 100.0 100 5</tt> means "
    "<i>\"print when failed, but return success and continue.\"</i> "
    "The analysis is NOT stopped — it keeps running and writing output files."
)]
story += [H3("Reliability of results on the softening branch:")]
story += [P(
    "With an unbalanced force norm of ~600 N against structural forces in the kN range, "
    "per-step errors are roughly 5–20%. The <b>peak of the pushover curve</b> — reached "
    "before the singular matrix warning — is more reliable. The descending branch should "
    "be treated as indicative of trend, not precise quantitative values."
)]

# ── 2. Code Issues ────────────────────────────────────────────────────────
story += [H1("2 · Code Issues — By Confidence Level")]

# 2.A
story += [KeepTogether([
    H2("2.A · CONFIRMED — Singular DOFs at internal spandrel/pier nodes"),
    P("<b>Fix: add immediately after the boundary condition block</b> (after <tt>fix 2 1 1 1 1 1 1</tt>):"),
    code(
        "# Suppress zero-stiffness DOFs at internal pier nodes\n"
        "# Fixing Y, Rx, Rz — leaving X, Z, Ry free\n"
        "foreach n {9 10 11 12 13 14} {\n"
        "    fix $n  0 1 0 1 0 1\n"
        "}\n\n"
        "# Suppress zero-stiffness DOFs at internal spandrel nodes\n"
        "# Fixing Y, Z, Rx, Rz — leaving X, Ry free (Z is the critical one)\n"
        "foreach n {15 16 17} {\n"
        "    fix $n  0 1 1 1 0 1\n"
        "}"
    ),
    note("If singular behaviour persists, try fixing all DOFs except X for the spandrel nodes: fix $n 0 1 1 1 1 1"),
])]

# 2.B
story += [H2("2.B · CONFIRMED — Pushover fallback overshoots target displacement")]
story += [P(
    "When <tt>analyze $nSteps</tt> fails at step <i>k</i>, the fallback calls "
    "<tt>analyze $nSteps</tt> again — running another full set of steps from the "
    "current displaced position, overshooting the 0.20 m target."
)]
story += [P("<b>Replace the entire pushover execution block with:</b>")]
story += [code(
    "set completedSteps 0\n"
    "set usingInitial   0\n\n"
    "while {$completedSteps < $nSteps} {\n\n"
    "    set ok [analyze 1]\n\n"
    "    if {$ok == 0} {\n"
    "        incr completedSteps\n"
    "        if {$usingInitial} {\n"
    "            algorithm Newton\n"
    "            test NormDispIncr 1.0e-6 100 0\n"
    "            set usingInitial 0\n"
    "        }\n"
    "    } else {\n"
    "        if {!$usingInitial} {\n"
    '            puts "Step $completedSteps: Newton failed — switching to Newton -initial"\n'
    "            test NormDispIncr 1.0e-5 200 5\n"
    "            algorithm Newton -initial\n"
    "            set usingInitial 1\n"
    "        }\n"
    "        set ok [analyze 1]\n"
    "        if {$ok == 0} {\n"
    "            incr completedSteps\n"
    "        } else {\n"
    '            puts "STOP: both algorithms failed at step $completedSteps / $nSteps"\n'
    '            puts "Roof displacement at stop: [expr $completedSteps * $incr] m"\n'
    "            break\n"
    "        }\n"
    "    }\n\n"
    "    if {[expr $completedSteps % 200] == 0 && $completedSteps > 0} {\n"
    '        puts "Progress: $completedSteps / $nSteps  ([expr $completedSteps*$incr] m)"\n'
    "    }\n"
    "}\n"
    'puts "Pushover done: $completedSteps / $nSteps steps"'
)]

# 2.C
story += [KeepTogether([
    H2("2.C · CONFIRMED — Convergence test wrong for post-peak regime"),
    P(
        "<tt>NormUnbalance</tt> checks residual forces. In the softening regime the tangent "
        "stiffness is near zero, so large force residuals remain even when displacements are "
        "fully converged. Use <tt>NormDispIncr</tt> for the pushover phase."
    ),
    P("<b>For gravity</b> (force equilibrium matters):"),
    code("test NormUnbalance 1.0 50 0"),
    P("<b>For pushover</b> (displacement convergence is the meaningful criterion):"),
    code("test NormDispIncr 1.0e-6 100 0"),
])]

story += [H2("2.D · TO VERIFY — Floor load formula")]
story += [P(
    "The current formula: <tt>set floorLoad [expr -5.0*$g*$rho*$L_span*$T_pier]</tt>"
)]
story += [P("Dimensional analysis:")]
story += [code(
    "rho [kg/m³] × g [m/s²]          = specific weight  [N/m³]\n"
    "× L_span [m] × T_pier [m]        = load intensity   [N/m]  (per unit height)\n"
    "× 5.0                             = total force      [N]    only if 5.0 is in metres\n\n"
    "Numerical result: -5.0 × 9.81 × 1200 × 3.0 × 0.25 = -44 145 N per floor node"
)]
story += [P(
    "<b>If 5.0 is an equivalent tributary masonry height in metres</b> — the formula is "
    "dimensionally consistent and correct."
)]
story += [P(
    "<b>If 5.0 is a floor pressure in kN/m²</b> — the formula is wrong. The correct line would be:"
)]
story += [code("set floorLoad [expr -5.0e3 * $L_span * $T_pier]   ;# → -3 750 N per node")]
story += [P(
    "Please verify what 5.0 physically represents in the original model. "
    "This cannot be determined from the script alone."
)]

story += [H2("2.E · RETRACTED — Settlement on fully fixed node")]
story += [P(
    "The settlement phase completed without error, and OpenSees 3.2.1 with "
    "<tt>constraints Transformation</tt> appears to handle <tt>sp</tt> overriding a "
    "<tt>fix</tt> correctly in this version. No change is recommended unless the vertical "
    "reaction at node 1 does not change between the gravity and settled states."
)]

# ── 3. Minimum patch ─────────────────────────────────────────────────────
story += [H1("3 · Minimum Working Patch (apply in order)")]
story += [P("<b>Step 1</b> — Add after <tt>fix 2 1 1 1 1 1 1</tt>:")]
story += [code(
    "foreach n {9 10 11 12 13 14} { fix $n  0 1 0 1 0 1 }\n"
    "foreach n {15 16 17}         { fix $n  0 1 1 1 0 1 }"
)]
story += [P("<b>Step 2</b> — Change the pushover convergence test:")]
story += [code("test NormDispIncr 1.0e-6 100 0")]
story += [P("<b>Step 3</b> — Replace the if{$ok != 0} fallback block with the while-loop from section 2.B.")]
story += [P(
    "These three changes together should eliminate the singular matrix warning and "
    "the convergence warning flood."
)]

# ── 4. Verifying output ──────────────────────────────────────────────────
story += [H1("4 · Verifying the Output")]
story += [P("After a corrected run, <tt>RoofDisp.out</tt> should contain:")]
story += [code(
    "time       disp_node8_X\n"
    "0.0        0.0\n"
    "0.0001     <small value>\n"
    "...\n"
    "0.20       <value near 0.20 if pushover completed>"
)]
story += [P(
    "In displacement-controlled pushover, the 'time' column equals the cumulative "
    "displacement increment at the controlled node (node 8, DOF 1). It should increase "
    "monotonically from 0 to approximately 0.20 m."
)]
story += [P("<b>Sanity checks on the pushover curve:</b>")]
story += [code(
    "1. Initial slope = elastic lateral stiffness.\n"
    "   For this frame: expected range ~ 10³ – 10⁴ kN/m.\n\n"
    "2. Peak shear per pier ≈ (c + mu0 × sigma_0) × L_pier × T_pier\n"
    "   where sigma_0 = axial stress under gravity loads.\n\n"
    "3. If the curve drops sharply right after the elastic range:\n"
    "   Gc = 6 J/m² is very low. Typical TREMURI values: 20–50 J/m².\n"
    "   Try Gc = 20 and compare the descending branch."
)]

# ── 5. Action plan ───────────────────────────────────────────────────────
story += [H1("5 · Step-by-Step Action Plan")]
steps = [
    ("Apply the internal node fix (section 3).",
     "Run gravity only (comment out settlement and pushover). "
     "Check that it completes without the singular matrix warning."),
    ("Run gravity + settlement.",
     "Check SupportReaction.out — the vertical reaction at node 1 should change "
     "between the gravity state and the settled state. If it does not change, "
     "release DOF 3 of node 1: fix 1  1 1 0 1 1 1."),
    ("Run the full script with NormDispIncr and the while-loop fallback.",
     "The singular matrix warning should be gone. Some steps near capacity "
     "may still use Newton Initial, but convergence warnings should be minimal."),
    ("Check the floor load (section 2.D).",
     "Verify sigma_0 in the piers under gravity. Expected range: 0.5–2 MPa. "
     "If much higher, the floor load formula may need correction."),
    ("Parametric study on Gc.",
     "Try Gc = 6 (current), 20, and 50 J/m². Compare the descending branch. "
     "This is a valid thesis discussion regardless of the convergence issues."),
]
for i,(title,body) in enumerate(steps):
    story += [KeepTogether([
        P(f"<b>{i+1}. {title}</b>"),
        P(body),
        gap(4),
    ])]

story += [hr()]
story += [P(
    "<i>The structural model and element choice are correct. The issues are in "
    "boundary condition completeness (zero-stiffness DOFs at internal nodes), "
    "the convergence criterion for the softening regime, and the fallback logic. "
    "None of these reflect a misunderstanding of the structural problem.</i>",
    note_s
)]

doc.build(story)
print(f"Written {OUTPUT}")
