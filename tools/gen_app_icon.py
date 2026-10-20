#!/usr/bin/env python3
"""Generates the PRISM app icon (icon.svg): a pixel-art prism filled with a spectrum.

The icon is drawn on a 16x16 cell grid (8 px cells in a 128 px SVG), so it stays crisp when
Godot rasterizes it at 16, 32, 64 or 128 px. Every color comes from the PRISM 32 palette
(core/model/palette_presets.gd). Usage: python3 tools/gen_app_icon.py
"""

from pathlib import Path

GRID = 16
CELL = 8
BACKGROUND = "#1a1430"
# Left to right, two columns each, across the prism.
SPECTRUM = ["#c34f4f", "#ff8a3d", "#ffe14a", "#4fc35a", "#2f86e0", "#8a7bc4"]
# The prism: a triangle whose sides step one cell out every two rows (a clean 2:1 pixel line).
TOP_ROW = 2
ROWS = 12


def build() -> str:
    size = GRID * CELL
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" '
        f'viewBox="0 0 {size} {size}" shape-rendering="crispEdges">',
        f'<rect width="{size}" height="{size}" rx="{2 * CELL}" fill="{BACKGROUND}"/>',
    ]
    for row in range(ROWS):
        half = 1 + row // 2
        for column in range(GRID // 2 - half, GRID // 2 + half):
            color = SPECTRUM[(column - (GRID // 2 - len(SPECTRUM))) // 2]
            parts.append(f'<rect x="{column * CELL}" y="{(TOP_ROW + row) * CELL}" width="{CELL}" height="{CELL}" fill="{color}"/>')
    parts.append("</svg>")
    return "\n".join(parts) + "\n"


if __name__ == "__main__":
    target = Path(__file__).resolve().parent.parent / "icon.svg"
    target.write_text(build())
    print(f"wrote {target}")
