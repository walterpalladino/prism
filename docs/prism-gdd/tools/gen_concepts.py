"""Generates the original concept-art SVGs for the PRISM GDD."""
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "concept-art"
OUT.mkdir(parents=True, exist_ok=True)

BG = "#1b1c23"
PANEL = "#262833"
PANEL2 = "#2f3240"
BORDER = "#3c4052"
TEXT = "#c9cbd6"
DIM = "#7d8197"
ORANGE = "#ff8a3d"
BLUE = "#3d7bff"
FONT = "font-family='ui-monospace,Menlo,Consolas,monospace'"

SPRITE = [
    "................",
    "................",
    "......####......",
    "....##hhoo##....",
    "...#hhoooooo#...",
    "..#hoooooooooo#.",
    "..#oWBooooWBoo#.",
    ".#ooWWooooWWooo#",
    ".#oooooooooooos#",
    ".#ooooo#ss#ooos#",
    "#ooooooo##oooos#",
    "#oooooooooooss#.",
    "#ssoooooooosss#.",
    ".#ssssssssss##..",
    "..##########....",
    "................",
]
SPRITE_COLORS = {"#": "#1a1430", "o": "#4fc35a", "h": "#a6f08a", "s": "#2c7a4b",
                 "W": "#ffffff", "B": "#1a1430"}

PALETTE32 = [
    "#000000", "#1a1430", "#3b2d5c", "#5b4b8a", "#8a7bc4", "#c4b8f0", "#ffffff", "#7d8197",
    "#2c7a4b", "#4fc35a", "#a6f08a", "#e8ffd0", "#7a2c2c", "#c34f4f", "#f08a8a", "#ffd0d0",
    "#0a2a5c", "#1650a0", "#2f86e0", "#6ec0ff", "#a8e0ff", "#e0f6ff", "#5c3a0a", "#a0661a",
    "#e0a040", "#ffd080", "#fff0c0", "#ff8a3d", "#ff5ea8", "#ffe14a", "#3dffd0", "#202020",
]


def text(x, y, s, size=12, fill=TEXT, anchor="start", weight="normal"):
    return (f"<text x='{x}' y='{y}' {FONT} font-size='{size}' fill='{fill}' "
            f"text-anchor='{anchor}' font-weight='{weight}'>{s}</text>")


def rect(x, y, w, h, fill, stroke=None, rx=0, extra=""):
    st = f" stroke='{stroke}'" if stroke else ""
    return f"<rect x='{x}' y='{y}' width='{w}' height='{h}' fill='{fill}'{st} rx='{rx}' {extra}/>"


def sprite(x0, y0, px, opacity=1.0):
    out = [f"<g opacity='{opacity}'>"]
    for r, row in enumerate(SPRITE):
        for c, ch in enumerate(row):
            if ch in SPRITE_COLORS:
                out.append(rect(x0 + c * px, y0 + r * px, px, px, SPRITE_COLORS[ch]))
    out.append("</g>")
    return "".join(out)


def checker(x, y, w, h, s):
    out = [rect(x, y, w, h, "#3a3a44")]
    for i in range(0, w // s):
        for j in range(0, h // s):
            if (i + j) % 2 == 0:
                out.append(rect(x + i * s, y + j * s, s, s, "#44444f"))
    return "".join(out)


def svg(w, h, body, title):
    return (f"<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 {w} {h}' width='{w}' height='{h}'>"
            f"<title>{title}</title>{rect(0, 0, w, h, BG)}{body}</svg>")


def main_ui():
    W, H = 1280, 800
    b = []
    # menu bar
    b.append(rect(0, 0, W, 26, PANEL2))
    for i, m in enumerate(["Project", "Edit", "Picture", "Brush", "Mode", "Anim", "Effect", "View"]):
        b.append(text(14 + i * 82, 18, m, 13))
    b.append(text(W - 14, 18, "PRISM 0.1  ·  slime.prism  ·  32 colors  ·  64×64", 12, DIM, "end"))
    # canvas area
    b.append(rect(0, 26, 960, 560, "#15161c"))
    b.append(checker(224, 50, 512, 512, 32))
    b.append(sprite(224, 50, 32))
    # pixel grid hint
    b.append(f"<g stroke='#ffffff' stroke-opacity='0.06'>")
    for i in range(17):
        b.append(f"<line x1='{224 + i*32}' y1='50' x2='{224 + i*32}' y2='562'/>")
        b.append(f"<line x1='224' y1='{50 + i*32}' x2='736' y2='{50 + i*32}'/>")
    b.append("</g>")
    # brush ghost attached to cursor (DPaint style)
    b.append(sprite(780, 380, 8, 0.55))
    b.append(f"<rect x='780' y='380' width='128' height='128' fill='none' stroke='{ORANGE}' stroke-dasharray='4 3'/>")
    b.append(text(844, 526, "custom brush (ghost preview)", 11, ORANGE, "middle"))
    # navigator / preview (Aseprite style)
    b.append(rect(800, 44, 140, 140, PANEL, BORDER, 4))
    b.append(sprite(806, 50, 8))
    b.append(text(870, 198, "preview 1:1 / 2:1", 10, DIM, "middle"))
    # toolbox (right, DPaint homage)
    b.append(rect(960, 26, 96, 560, PANEL, BORDER))
    tools = ["PEN", "DOT", "LIN", "CRV", "CIR", "RCT", "FIL", "PLY", "AIR", "BRU", "TXT", "GRD",
             "MOV", "SEL", "ZM", "GRID", "SYM", "ROT", "PCK", "STN"]
    for i, t in enumerate(tools):
        col, row = i % 2, i // 2
        x, y = 970 + col * 40, 38 + row * 40
        sel = (i == 0)
        b.append(rect(x, y, 34, 34, ORANGE if sel else PANEL2, BORDER, 4))
        b.append(text(x + 17, y + 21, t, 10, "#1b1c23" if sel else TEXT, "middle", "bold"))
    b.append(text(1008, 452, "FG / BG", 10, DIM, "middle"))
    b.append(rect(978, 462, 44, 44, "#4fc35a", "#ffffff"))
    b.append(rect(1000, 484, 44, 44, "#1a1430", "#ffffff"))
    b.append(text(1008, 552, "[ ] step", 10, DIM, "middle"))
    b.append(text(1008, 566, "RMB = BG", 10, DIM, "middle"))
    # side panel
    b.append(rect(1056, 26, 224, 560, PANEL, BORDER))
    b.append(text(1068, 48, "PALETTE  (indexed, 32)", 11, DIM))
    for i, c in enumerate(PALETTE32):
        x, y = 1068 + (i % 8) * 25, 58 + (i // 8) * 25
        b.append(rect(x, y, 22, 22, c, "#000000"))
    b.append(rect(1068 + 1 * 25 - 2, 58 + 1 * 25 - 2, 26, 26, "none", ORANGE, 0, "stroke-width='2'"))
    # cycle bracket
    b.append(f"<path d='M1068 168 v6 h196 v-6' fill='none' stroke='{BLUE}' stroke-width='2'/>")
    b.append(text(1166, 188, "cycle range 16–21 · 12 fps", 10, BLUE, "middle"))
    b.append(text(1068, 214, "STENCIL", 11, DIM))
    for i in range(8):
        on = i in (1, 2)
        b.append(rect(1068 + i * 25, 222, 22, 12, ORANGE if on else PANEL2, BORDER))
    b.append(text(1068, 256, "LAYERS", 11, DIM))
    layers = [("Outline", True), ("Shading", True), ("Color", True), ("BG", False)]
    for i, (n, vis) in enumerate(layers):
        y = 266 + i * 30
        b.append(rect(1068, y, 200, 26, PANEL2 if i else "#3a3550", BORDER, 3))
        b.append(text(1080, y + 17, "●" if vis else "○", 12, TEXT if vis else DIM))
        b.append(text(1100, y + 17, n, 12))
        b.append(text(1258, y + 17, "100%", 10, DIM, "end"))
    b.append(text(1068, 410, "BRUSH", 11, DIM))
    b.append(rect(1068, 420, 200, 72, PANEL2, BORDER, 3))
    b.append(sprite(1076, 428, 3.5))
    b.append(text(1140, 446, "slime_head", 11))
    b.append(text(1140, 464, "56×56 · anchor C", 10, DIM))
    b.append(text(1140, 480, "flip H  rot 0°", 10, DIM))
    b.append(text(1068, 516, "MODE", 11, DIM))
    for i, m in enumerate(["Color", "Replace", "Shade", "Cycle"]):
        x = 1068 + (i % 2) * 102
        y = 526 + (i // 2) * 26
        b.append(rect(x, y, 98, 22, BLUE if i == 0 else PANEL2, BORDER, 3))
        b.append(text(x + 49, y + 15, m, 11, "#ffffff" if i == 0 else TEXT, "middle"))
    # timeline
    b.append(rect(0, 586, W, 190, PANEL, BORDER))
    b.append(text(14, 606, "TIMELINE", 11, DIM))
    for i, ic in enumerate(["|◀", "◀", "▶", "▶|", "LOOP"]):
        b.append(text(110 + i * 30, 607, ic, 12))
    b.append(text(300, 606, "onion: −2 / +1   ·   loop: idle   ·   12 fps", 11, DIM))
    # tags
    b.append(rect(160, 616, 4 * 44 - 4, 14, BLUE, None, 3))
    b.append(text(164, 627, "idle", 10, "#ffffff"))
    b.append(rect(160 + 4 * 44, 616, 4 * 44 - 4, 14, ORANGE, None, 3))
    b.append(text(164 + 4 * 44, 627, "hop", 10, "#1b1c23"))
    for f in range(12):
        b.append(text(160 + f * 44 + 20, 646, str(f + 1), 11, ORANGE if f == 2 else DIM, "middle"))
    for r, (n, _) in enumerate(layers):
        y = 654 + r * 28
        b.append(rect(10, y, 140, 24, PANEL2, BORDER, 3))
        b.append(text(20, y + 16, n, 11))
        for f in range(12):
            x = 160 + f * 44
            b.append(rect(x, y, 40, 24, "#232530", BORDER, 2))
            if f < 8 and not (r == 3 and f > 0):
                if r == 3:
                    b.append(f"<line x1='{x+20}' y1='{y+12}' x2='{x+20+7*44}' y2='{y+12}' stroke='{DIM}'/>")
                b.append(f"<circle cx='{x+20}' cy='{y+12}' r='5' fill='{TEXT}'/>")
    # playhead + onion range
    b.append(rect(160 + 0 * 44, 640, 2 * 44 - 4, 132, BLUE, None, 0, "opacity='0.12'"))
    b.append(rect(160 + 3 * 44, 640, 40, 132, ORANGE, None, 0, "opacity='0.12'"))
    b.append(f"<line x1='{160+2*44+20}' y1='636' x2='{160+2*44+20}' y2='772' stroke='{ORANGE}' stroke-width='2'/>")
    # status bar
    b.append(rect(0, 776, W, 24, PANEL2))
    b.append(text(14, 792, "x 9  y 6  ·  idx 9 #4fc35a  ·  zoom 800%  ·  Pencil (pixel-perfect)  ·  frame 3/12", 11, DIM))
    return svg(W, H, "".join(b), "PRISM concept — main editor layout")


def timeline():
    W, H = 960, 420
    b = [text(24, 36, "Timeline &amp; Light Table (onion skin) — concept", 16, TEXT, weight="bold")]
    # onion skin demo canvas
    b.append(checker(24, 60, 288, 288, 24))
    b.append(sprite(24 + 24, 60 + 40, 14, 0.25))  # prev -2
    b.append(f"<g transform='translate(0,0)'>{sprite(24 + 36, 60 + 30, 14, 0.4)}</g>")
    b.append(sprite(24 + 48, 60 + 16, 14))
    b.append(text(168, 370, "current cel + 2 past cels tinted", 11, DIM, "middle"))
    # timeline grid
    x0, y0 = 340, 70
    b.append(rect(x0 - 10, y0 - 20, 600, 300, PANEL, BORDER, 6))
    b.append(rect(x0 + 90, y0 - 10, 4 * 48 - 4, 14, BLUE, None, 3))
    b.append(text(x0 + 94, y0 + 1, "idle (ping-pong)", 10, "#ffffff"))
    b.append(rect(x0 + 90 + 4 * 48, y0 - 10, 6 * 48 - 4, 14, ORANGE, None, 3))
    b.append(text(x0 + 94 + 4 * 48, y0 + 1, "hop (forward)", 10, "#1b1c23"))
    for f in range(10):
        b.append(text(x0 + 90 + f * 48 + 22, y0 + 24, str(f + 1), 11, DIM, "middle"))
        b.append(text(x0 + 90 + f * 48 + 22, y0 + 40, "100" if f != 6 else "250", 9, ORANGE if f == 6 else DIM, "middle"))
    b.append(text(x0, y0 + 40, "ms", 9, DIM))
    rows = ["Outline", "Shading", "Color", "FX (cycle)", "BG (linked)"]
    for r, n in enumerate(rows):
        y = y0 + 52 + r * 40
        b.append(text(x0, y + 20, n, 11))
        for f in range(10):
            x = x0 + 90 + f * 48
            b.append(rect(x, y, 44, 32, "#232530", BORDER, 3))
            if r == 4:
                if f == 0:
                    b.append(f"<line x1='{x+22}' y1='{y+16}' x2='{x+22+9*48}' y2='{y+16}' stroke='{BLUE}' stroke-width='2'/>")
                b.append(f"<circle cx='{x+22}' cy='{y+16}' r='5' fill='{BLUE}'/>")
            elif r == 3 and f % 3 != 0:
                b.append(f"<circle cx='{x+22}' cy='{y+16}' r='5' fill='none' stroke='{DIM}'/>")
            else:
                b.append(f"<circle cx='{x+22}' cy='{y+16}' r='6' fill='{TEXT}'/>")
    b.append(f"<line x1='{x0+90+5*48+22}' y1='{y0+14}' x2='{x0+90+5*48+22}' y2='{y0+252}' stroke='{ORANGE}' stroke-width='2'/>")
    legend = [("●", TEXT, "cel with pixels"), ("○", DIM, "empty cel"), ("●—", BLUE, "linked cel (shared image)")]
    for i, (g, c, s) in enumerate(legend):
        b.append(text(x0 + i * 190, y0 + 300, g, 12, c))
        b.append(text(x0 + 26 + i * 190, y0 + 300, s, 11, DIM))
    return svg(W, H, "".join(b), "PRISM concept — timeline and light table")


def color_cycling():
    W, H = 960, 380
    b = [text(24, 36, "Color cycling — palette ranges drive animation without new frames", 16, TEXT, weight="bold")]
    water = ["#0a2a5c", "#1650a0", "#2f86e0", "#6ec0ff", "#a8e0ff", "#e0f6ff"]
    for k in range(3):
        y = 70 + k * 96
        shifted = water[-k:] + water[:-k] if k else water
        b.append(text(24, y + 16, f"t = {k}", 12, DIM))
        for i, c in enumerate(shifted):
            b.append(rect(90 + i * 34, y, 30, 30, c, "#000"))
            b.append(text(90 + i * 34 + 15, y + 46, str(16 + i), 9, DIM, "middle"))
        # waterfall strip
        for row in range(12):
            c = shifted[row % 6]
            b.append(rect(330, y + row * 6 - 6, 120, 6, c))
        b.append(rect(330, y - 6, 120, 72, "none", BORDER))
        if k < 2:
            b.append(text(470, y + 34, "→ rotate range by 1", 11, BLUE))
    b.append(rect(620, 60, 316, 290, PANEL, BORDER, 6))
    lines = [
        ("Cycle range", ORANGE),
        ("start 16 · end 21", TEXT),
        ("rate 12 steps/s", TEXT),
        ("direction: forward", TEXT),
        ("", TEXT),
        ("Rules", ORANGE),
        ("• pixels store indices, not RGB", TEXT),
        ("• playback rotates palette LUT only", TEXT),
        ("• GPU: 1 texture upload per tick", TEXT),
        ("• export: bake to frames (GIF/PNG)", TEXT),
        ("  or keep as metadata (.prism)", DIM),
    ]
    for i, (s, c) in enumerate(lines):
        b.append(text(640, 90 + i * 22, s, 12, c))
    return svg(W, H, "".join(b), "PRISM concept — color cycling")


def brush_flow():
    W, H = 960, 340
    b = [text(24, 36, "Brush pickup workflow (DPaint heritage)", 16, TEXT, weight="bold")]
    titles = ["1 · Select region (B)", "2 · Brush follows cursor", "3 · Stamp / transform"]
    for k in range(3):
        x = 24 + k * 312
        b.append(rect(x, 56, 290, 250, PANEL, BORDER, 6))
        b.append(text(x + 14, 80, titles[k], 12, ORANGE))
        b.append(checker(x + 14, 92, 262, 200, 20))
    b.append(sprite(24 + 40, 110, 9))
    b.append(f"<rect x='{24+40+18}' y='{110+18}' width='{12*9}' height='{12*9}' fill='none' stroke='{ORANGE}' stroke-dasharray='5 3' stroke-width='2'/>")
    b.append(sprite(336 + 90, 130, 7, 0.55))
    b.append(f"<path d='M{336+150} {200} l14 20 l-6 0 l4 10 l-4 2 l-4 -10 l-5 5 z' fill='#fff'/>")
    b.append(text(336 + 145, 290, "ghost = exact preview", 10, DIM, "middle"))
    for i, (dx, dy, flip) in enumerate([(30, 110, False), (120, 120, True), (200, 160, False)]):
        g = sprite(0, 0, 5)
        tr = f"translate({648+dx + (80 if flip else 0)},{dy}) scale({-1 if flip else 1},1)"
        b.append(f"<g transform='{tr}'>{g}</g>")
    b.append(text(648 + 145, 290, "stamp ×3 · flip X on the middle one", 10, DIM, "middle"))
    return svg(W, H, "".join(b), "PRISM concept — brush pickup workflow")


for name, fn in [("01-main-editor.svg", main_ui), ("02-timeline-light-table.svg", timeline),
                 ("03-color-cycling.svg", color_cycling), ("04-brush-pickup.svg", brush_flow)]:
    (OUT / name).write_text(fn(), encoding="utf-8")
    print("wrote", OUT / name)
