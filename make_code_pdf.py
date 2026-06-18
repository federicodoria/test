from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.pdfgen import canvas
import os

JOBS = [
    ("/home/user/test/diagnostic.tcl",
     "/home/user/test/diagnostic.pdf",
     "diagnostic.tcl"),
    ("/home/user/test/newcode3storey_debug.tcl",
     "/home/user/test/newcode3storey_debug.pdf",
     "newcode3storey_debug.tcl"),
]

PAGE_W, PAGE_H = A4
MARGIN_L = 1.6 * cm
MARGIN_R = 1.2 * cm
MARGIN_T = 1.8 * cm
MARGIN_B = 1.5 * cm
FONT = "Courier"
SIZE = 8
LEADING = 10.2
MAX_CHARS = 95   # wrap long lines

def wrap(line, n):
    if line == "":
        return [""]
    out = []
    while len(line) > n:
        out.append(line[:n])
        line = line[n:]
    out.append(line)
    return out

for src, dst, title in JOBS:
    with open(src) as f:
        raw = f.readlines()

    lines = []
    for ln in raw:
        ln = ln.rstrip("\n").replace("\t", "    ")
        lines.extend(wrap(ln, MAX_CHARS))

    c = canvas.Canvas(dst, pagesize=A4)
    usable_h = PAGE_H - MARGIN_T - MARGIN_B
    lines_per_page = int(usable_h / LEADING) - 1

    def header(c, title, page):
        c.setFont("Helvetica-Bold", 9)
        c.setFillColor(colors.HexColor("#1a1a2e"))
        c.drawString(MARGIN_L, PAGE_H - MARGIN_T + 6, title)
        c.setFont("Helvetica", 7)
        c.setFillColor(colors.HexColor("#888888"))
        c.drawRightString(PAGE_W - MARGIN_R, PAGE_H - MARGIN_T + 6, f"page {page}")
        c.setStrokeColor(colors.HexColor("#cccccc"))
        c.setLineWidth(0.4)
        c.line(MARGIN_L, PAGE_H - MARGIN_T + 1, PAGE_W - MARGIN_R, PAGE_H - MARGIN_T + 1)

    page = 1
    header(c, title, page)
    y = PAGE_H - MARGIN_T - LEADING
    count = 0
    c.setFont(FONT, SIZE)
    c.setFillColor(colors.black)

    for ln in lines:
        if count >= lines_per_page:
            c.showPage()
            page += 1
            header(c, title, page)
            c.setFont(FONT, SIZE)
            c.setFillColor(colors.black)
            y = PAGE_H - MARGIN_T - LEADING
            count = 0
        # comment lines in grey
        stripped = ln.lstrip()
        if stripped.startswith("#"):
            c.setFillColor(colors.HexColor("#6a737d"))
        else:
            c.setFillColor(colors.black)
        c.drawString(MARGIN_L, y, ln)
        y -= LEADING
        count += 1

    c.showPage()
    c.save()
    print(f"Written {dst}")
