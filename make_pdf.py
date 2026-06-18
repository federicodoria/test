from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Preformatted,
    Table, TableStyle, HRFlowable
)
from reportlab.lib.enums import TA_LEFT, TA_CENTER

OUTPUT = "/home/user/test/opensees_review.pdf"

doc = SimpleDocTemplate(
    OUTPUT,
    pagesize=A4,
    leftMargin=2.5*cm, rightMargin=2.5*cm,
    topMargin=2.5*cm, bottomMargin=2.5*cm
)

styles = getSampleStyleSheet()

# Custom styles
title_style = ParagraphStyle(
    "Title", parent=styles["Title"],
    fontSize=16, spaceAfter=4, textColor=colors.HexColor("#1a1a2e")
)
subtitle_style = ParagraphStyle(
    "Subtitle", parent=styles["Normal"],
    fontSize=10, textColor=colors.HexColor("#555555"), spaceAfter=16
)
h1_style = ParagraphStyle(
    "H1", parent=styles["Heading1"],
    fontSize=13, textColor=colors.HexColor("#1a1a2e"),
    spaceBefore=18, spaceAfter=6, borderPad=0
)
h2_style = ParagraphStyle(
    "H2", parent=styles["Heading2"],
    fontSize=11, textColor=colors.HexColor("#2c3e6b"),
    spaceBefore=14, spaceAfter=4
)
h3_style = ParagraphStyle(
    "H3", parent=styles["Heading3"],
    fontSize=10, textColor=colors.HexColor("#2c3e6b"),
    spaceBefore=10, spaceAfter=3
)
body_style = ParagraphStyle(
    "Body", parent=styles["Normal"],
    fontSize=9.5, leading=14, spaceAfter=6
)
code_style = ParagraphStyle(
    "Code", parent=styles["Code"],
    fontSize=8, leading=11, fontName="Courier",
    backColor=colors.HexColor("#f4f4f4"),
    borderColor=colors.HexColor("#cccccc"),
    borderWidth=0.5, borderPad=6,
    spaceAfter=8, spaceBefore=4
)
note_style = ParagraphStyle(
    "Note", parent=styles["Normal"],
    fontSize=9, textColor=colors.HexColor("#555555"),
    leftIndent=12, spaceAfter=6, leading=13
)
label_critical = ParagraphStyle(
    "LabelCrit", parent=styles["Normal"],
    fontSize=9, textColor=colors.white,
    backColor=colors.HexColor("#c0392b"),
    borderPad=3, spaceAfter=2
)

def code(text):
    return Preformatted(text, code_style)

def body(text):
    return Paragraph(text, body_style)

def h1(text):
    return Paragraph(text, h1_style)

def h2(text):
    return Paragraph(text, h2_style)

def h3(text):
    return Paragraph(text, h3_style)

def gap(n=6):
    return Spacer(1, n)

def rule():
    return HRFlowable(width="100%", thickness=0.5, color=colors.HexColor("#cccccc"), spaceAfter=8)


story = []

# ─── Title ───────────────────────────────────────────────────────────────────
story.append(Paragraph("OpenSees Script Review", title_style))
story.append(Paragraph("3-Storey Masonry Frame — <i>newcode3storey.tcl</i>", subtitle_style))
story.append(rule())

# ─── Foreword ────────────────────────────────────────────────────────────────
story.append(h1("Foreword"))
story.append(body(
    "The structure of this script is solid and the modelling approach is correct — "
    "Macroelement3d for piers and spandrels, three analysis phases (gravity → settlement → pushover), "
    "displacement control with a Newton fallback. The issues below are the kind of subtle traps "
    "that catch experienced OpenSees users too, mostly because the framework is flexible enough "
    "to accept commands silently even when they have no effect. Nothing here reflects a gap in "
    "understanding of the structural problem — it is purely OpenSees bookkeeping."
))
story.append(body(
    "The note on version and extensions matters: two of the items below may or may not apply "
    "depending on the exact Macroelement3d implementation in use, and those are flagged explicitly."
))

# ─── Critical Issues ─────────────────────────────────────────────────────────
story.append(h1("Critical Issues"))
story.append(body(
    "These three items will either produce silently wrong results or cause the pushover "
    "to run past its intended target."
))

# Issue 1
story.append(h2("1 — Foundation Settlement Is Never Applied"))
story.append(Paragraph("<b>Lines 80–81 and 258</b>", note_style))
story.append(code(
    "fix 1  1 1 1 1 1 1    ;# node 1: ALL six DOFs locked, including vertical (DOF 3)\n"
    "...\n"
    "pattern Plain 20 Linear {\n"
    "    sp 1 3 -0.001     ;# tries to impose a vertical displacement on node 1\n"
    "}"
))
story.append(body(
    "With the <b>Transformation</b> constraint handler (used throughout the script), fixed DOFs are "
    "eliminated from the system of equations before the solver runs. The <b>sp</b> command inside "
    "the pattern therefore has nothing to act on — the settlement is accepted without error but "
    "never actually applied."
))
story.append(body("The fix is to leave the vertical DOF of node 1 free:"))
story.append(code(
    "fix 1  1 1 0 1 1 1    ;# DOF 3 (Z, vertical) is now free for settlement\n"
    "fix 2  1 1 1 1 1 1    ;# node 2 remains fully fixed"
))

# Issue 2
story.append(h2("2 — Floor Load Formula Produces Values ~12× Too Large"))
story.append(Paragraph("<b>Line 218</b>", note_style))
story.append(code("set floorLoad [expr -5.0*$g*$rho*$L_span*$T_pier]"))
story.append(body(
    "Working through the units in SI (N, m, kg):"
))
story.append(code(
    "rho × g               →  N/m³   (specific weight of masonry)\n"
    "× L_span × T_pier     →  N/m    (load per metre of height)\n"
    "× 5.0                 →  N      (only if 5.0 is a height in metres)"
))
story.append(body(
    "The formula computes the weight of a masonry block <b>5 metres tall</b>, with cross-section "
    "L_span × T_pier. Since H_story = 3.0 m, this is larger than one full storey applied at every "
    "floor node — approximately <b>44 100 N per node</b>. The structure is therefore pre-loaded far "
    "beyond its gravitational state before the pushover even begins."
))
story.append(body(
    "If the intent was a <b>5 kN/m² floor load</b> (a common value), the correct line is:"
))
story.append(code("set floorLoad [expr -5.0e3 * $L_span * $T_pier]   ;# → -3 750 N per node"))
story.append(body(
    "If the intent was the <b>self-weight of the masonry wall</b> above each floor "
    "(tributary height = H_story):"
))
story.append(code(
    "set floorLoad [expr -$rho * $g * $H_story * $L_span * $T_pier]\n"
    ";# → -26 487 N per node"
))

# Issue 3
story.append(h2("3 — Pushover Fallback Overshoots the Target Displacement"))
story.append(Paragraph("<b>Lines 316–326</b>", note_style))
story.append(code(
    "set nSteps [expr int($targetDisp/$incr)]   ;# = 2000 steps\n\n"
    "set ok [analyze $nSteps]                   ;# runs up to 2000 steps, fails at step k\n\n"
    "if {$ok != 0} {\n"
    "    algorithm Newton -initial\n"
    "    set ok [analyze $nSteps]               ;# runs ANOTHER 2000 steps from step k\n"
    "}"
))
story.append(body(
    "If the first block fails after, say, 1 500 of 2 000 steps, the controlled node is already "
    "at 0.15 m. The fallback then requests 2 000 more steps, potentially driving the roof to "
    "0.35 m — well past the 0.20 m target. The output file will contain a trajectory that "
    "extends far beyond the intended pushover range."
))
story.append(body("A step-by-step loop is more reliable:"))
story.append(code(
    "set completedSteps 0\n\n"
    "while {$completedSteps < $nSteps} {\n\n"
    "    set ok [analyze 1]\n\n"
    "    if {$ok == 0} {\n"
    "        incr completedSteps\n"
    "    } else {\n"
    "        puts \"Newton failed at step $completedSteps — trying Newton -initial\"\n"
    "        test  NormUnbalance 100.0 200 5\n"
    "        algorithm Newton -initial\n"
    "        set ok [analyze 1]\n\n"
    "        if {$ok == 0} {\n"
    "            incr completedSteps\n"
    "            algorithm Newton\n"
    "            test NormUnbalance 100.0 50 5\n"
    "        } else {\n"
    "            puts \"Analysis stopped at step $completedSteps / $nSteps\"\n"
    "            break\n"
    "        }\n"
    "    }\n"
    "}\n\n"
    "puts \"Pushover completed: $completedSteps of $nSteps steps.\""
))

# ─── Significant Issues ───────────────────────────────────────────────────────
story.append(h1("Significant Issues"))

story.append(h2("4 — Possible Double-Counting of Self-Weight"))
story.append(Paragraph("<b>Line 223 — version-dependent</b>", note_style))
story.append(code(
    "element Macroelement3d 1 ... -density $rho -cmass\n"
    "...\n"
    "eleLoad -ele $e -type -selfWeight 0.0 0.0 [expr -$g]"
))
story.append(body(
    "The <b>-density</b> flag tells the element its mass density (used to build the consistent "
    "mass matrix via <b>-cmass</b>). The <b>eleLoad -selfWeight</b> separately applies a body-force "
    "acceleration to each element. In some Macroelement3d implementations, -density is used only "
    "for the mass matrix, so eleLoad -selfWeight is the correct way to apply static gravity. In "
    "others, the element automatically generates gravity loads from its density, making the "
    "eleLoad redundant and the self-weight double-counted."
))
story.append(body(
    "<b>Action:</b> check the documentation of the specific Macroelement3d version in use. "
    "If gravity reactions are roughly twice the expected value after the gravity phase, "
    "this is the cause."
))

story.append(h2("5 — Internal Spandrel Nodes Receive No Floor Load"))
story.append(Paragraph("<b>Lines 226–233</b>", note_style))
story.append(code(
    "load 3  0.0 0.0 $floorLoad 0.0 0.0 0.0\n"
    "load 4  0.0 0.0 $floorLoad 0.0 0.0 0.0\n"
    ";# nodes 15, 16, 17 (spandrel midpoints) receive nothing"
))
story.append(body(
    "Nodes 15, 16, and 17 are the midpoint internal nodes of the three spandrel elements. "
    "If -density and -cmass are active, these nodes carry mass. The eleLoad -selfWeight distributes "
    "gravity body forces to them through the consistent mass matrix, but any additional floor loads "
    "(live load, slab weight not included in self-weight) are missing at these nodes. "
    "If the floor loads at nodes 3–8 represent superimposed loads from slabs or occupancy, "
    "a proportional share should go to nodes 15–17 as well."
))

story.append(h2("6 — Convergence Tolerance May Be Too Tight for Nonlinear Analysis"))
story.append(Paragraph("<b>Lines 240 and 296</b>", note_style))
story.append(code("test NormUnbalance 100.0 50 5"))
story.append(body(
    "A tolerance of 100 N on the unbalanced force norm is an absolute criterion. With axial pier "
    "capacities on the order of fc × A = 6×10⁶ × (1.0 × 0.25) = 1.5 MN, this is extremely "
    "strict (0.007% of capacity). Near yield or after cracking, the Newton-Raphson iterations "
    "may struggle to reach this tolerance within 50 iterations, causing premature divergence "
    "even when the structural solution is physically well-behaved. Consider switching to a "
    "relative criterion:"
))
story.append(code("test RelativeNormUnbalance 1.0e-4 100 5"))

# ─── Minor Points ─────────────────────────────────────────────────────────────
story.append(h1("Minor Points"))

story.append(h2("7 — Shear Modulus Implies an Unusually High Poisson's Ratio"))
story.append(Paragraph("<b>Lines 24–26</b>", note_style))
story.append(code("set E  1700.0e6   ;# 1 700 MPa\nset G   550.0e6   ;#   550 MPa"))
story.append(body(
    "From the elastic relation G = E / (2(1+ν)), the implied Poisson's ratio is "
    "ν = E/(2G) − 1 = 1700 / (2 × 550) − 1 ≈ 0.55. Typical masonry values are "
    "ν ≈ 0.15–0.20, which for E = 1 700 MPa gives G ≈ 739 MPa. A value of "
    "G = 550 MPa is sometimes used as a cracked shear stiffness (~0.3–0.4 × G_elastic), "
    "which is a legitimate modelling choice — but it is worth confirming this is intentional "
    "and consistent with the reference source for these material properties."
))

story.append(h2("8 — Fracture Energy Gc = 6 J/m² Is on the Low End"))
story.append(Paragraph("<b>Line 29</b>", note_style))
story.append(code("set Gc  6.0"))
story.append(body(
    "Mode-II fracture energy for masonry in the Macroelement3d/TREMURI formulation is typically "
    "in the range 20–100 J/m². A value of 6 J/m² will produce a very brittle post-peak response — "
    "a sharp, steep drop on the pushover curve immediately after peak force. This is not necessarily "
    "wrong, but if the curve shows an unrealistically abrupt capacity loss, Gc is the first "
    "parameter to revisit."
))

story.append(h2("9 — No Element Recorders Defined"))
story.append(Paragraph("<b>Lines 200–211</b>", note_style))
story.append(body(
    "Only nodal displacement and base reaction are recorded. Without element recorders it is not "
    "possible to know which piers or spandrels have cracked or yielded, or where in the structure "
    "damage concentrates. Adding at least the following will make it much easier to interpret the "
    "pushover curve and diagnose unusual behaviour:"
))
story.append(code(
    "recorder Element -file PierForces.out  -time -ele 1 2 3 4 5 6  basicForce\n"
    "recorder Element -file SpanForces.out  -time -ele 7 8 9        basicForce"
))

# ─── Summary Table ─────────────────────────────────────────────────────────────
story.append(h1("Summary Table"))
story.append(gap(4))

table_data = [
    ["#", "Lines", "Severity", "Issue", "Suggested fix"],
    ["1", "80, 258",   "Critical",     "Fixed node: settlement never applied",               "Release DOF 3 on node 1"],
    ["2", "218",       "Critical",     "Floor load ~12× too large (unit mismatch)",           "Use 5.0e3 × L_span × T_pier"],
    ["3", "316–326",   "Critical",     "Fallback reruns full step count, overshoots target",  "Replace with step-by-step loop"],
    ["4", "223",       "Significant",  "Possible double self-weight (version-dependent)",     "Check Macroelement3d docs"],
    ["5", "226–233",   "Significant",  "Spandrel midpoint nodes have no floor load",          "Add loads at nodes 15, 16, 17"],
    ["6", "240, 296",  "Significant",  "Absolute tolerance may be too tight post-cracking",  "Switch to RelativeNormUnbalance"],
    ["7", "24–26",     "Minor",        "G/E implies ν ≈ 0.55 vs. typical 0.15–0.20",         "Verify source of material data"],
    ["8", "29",        "Minor",        "Gc = 6 J/m² → very brittle post-peak",               "Check experimental reference"],
    ["9", "200–211",   "Minor",        "No element recorders",                               "Add recorder Element for piers/spandrels"],
]

sev_colors = {
    "Critical":    colors.HexColor("#fdecea"),
    "Significant": colors.HexColor("#fff8e1"),
    "Minor":       colors.HexColor("#f1f8e9"),
}

col_widths = [1.0*cm, 1.8*cm, 2.4*cm, 6.5*cm, 4.5*cm]

cell_style = ParagraphStyle("tc", fontSize=8, leading=10)
header_style = ParagraphStyle("th", fontSize=8, leading=10, textColor=colors.white, fontName="Helvetica-Bold")

def make_cell(text, style):
    return Paragraph(text, style)

formatted = []
for i, row in enumerate(table_data):
    if i == 0:
        formatted.append([make_cell(c, header_style) for c in row])
    else:
        formatted.append([make_cell(c, cell_style) for c in row])

tbl = Table(formatted, colWidths=col_widths, repeatRows=1)

row_colors = []
for i, row in enumerate(table_data):
    if i == 0:
        row_colors.append(("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#1a1a2e")))
    else:
        sev = row[2]
        row_colors.append(("BACKGROUND", (0, i), (-1, i), sev_colors.get(sev, colors.white)))

tbl.setStyle(TableStyle([
    ("FONTNAME",    (0, 0), (-1, 0), "Helvetica-Bold"),
    ("FONTSIZE",    (0, 0), (-1, -1), 8),
    ("VALIGN",      (0, 0), (-1, -1), "TOP"),
    ("GRID",        (0, 0), (-1, -1), 0.4, colors.HexColor("#cccccc")),
    ("ROWBACKGROUNDS", (0, 0), (-1, -1), [colors.white]),
    ("TOPPADDING",  (0, 0), (-1, -1), 4),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ("LEFTPADDING", (0, 0), (-1, -1), 5),
] + row_colors))

story.append(tbl)
story.append(gap(16))
story.append(rule())
story.append(body(
    "<i>Issues 1, 2, and 3 are the most likely explanation for incorrect or unexpected results. "
    "Fixing these three will substantially change the output and should be the first priority "
    "before revisiting material parameters or convergence settings.</i>"
))

doc.build(story)
print(f"PDF written to {OUTPUT}")
