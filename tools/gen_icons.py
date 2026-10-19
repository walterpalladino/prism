#!/usr/bin/env python3
"""Generates PRISM's own toolbar icons in the Pixelarticons style (12x12 cells of 2 units
on a 24x24 viewBox, white fill so the UI theme can tint them).

Only icons that Pixelarticons lacks are drawn here; they are project-owned.
With --vendor it also re-copies the Pixelarticons icons PRISM uses (VENDORED), recolored to white.

Usage:
  python3 tools/gen_icons.py
  python3 tools/gen_icons.py --vendor <pixelarticons-2.4.2>/svg     # from the npm package `pixelarticons`
"""
import sys
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "ui" / "icons"

ICONS = {
    # Line tool: a diagonal stroke between two end-point handles.
    "line": [
        "..........##",
        "..........##",
        ".........#..",
        "........#...",
        ".......#....",
        "......#.....",
        ".....#......",
        "....#.......",
        "...#........",
        "..#.........",
        "##..........",
        "##..........",
    ],
    # Fill tool: a tipped paint bucket pouring a drop.
    "fill": [
        "...#........",
        "..#.#.......",
        ".#...#......",
        "#.....#.....",
        "##.....#....",
        "#.#.....#...",
        "#..#...#.#..",
        ".#..#.#...#.",
        "..#..#....#.",
        "...#.#...###",
        "....#....###",
        "..........#.",
    ],
    # Rotate brush 90 degrees clockwise: open arc with a downward arrow head on the right.
    "rotate": [
        "..#####.....",
        ".#.....#....",
        "#.......#...",
        "#........#..",
        "#......#####",
        "#.......###.",
        "#........#..",
        "#...........",
        "#...........",
        ".#..........",
        "..#####.....",
        "............",
    ],
}


# PRISM icon name -> Pixelarticons 2.4.2 file name (MIT, see CREDITS.md).
VENDORED = {
    "pencil": "pencil", "eraser": "eraser", "rect": "square", "ellipse": "circle", "picker": "pipette",
    "select": "square-dashed-cursor", "move": "move", "brush": "brush",
    "flip_h": "flip-horizontal-2", "flip_v": "flip-vertical-2",
    "undo": "undo", "redo": "redo", "cut": "cut", "copy": "copy", "paste": "clipboard",
    "zoom_in": "zoom-in", "zoom_out": "zoom-out", "grid": "grid-3x3", "new": "file", "close": "close",
    "preview": "image", "save": "save", "folder": "folder",
    "eye": "eye", "eye_off": "eye-off", "lock": "lock", "unlock": "unlock", "play": "play", "pause": "pause",
    "plus": "plus", "minus": "minus", "trash": "trash", "duplicate": "copy",
    "prev": "chevron-left", "next": "chevron-right",
}


def vendor(svg_dir: Path) -> None:
    for name, source in VENDORED.items():
        text = (svg_dir / f"{source}.svg").read_text().replace('fill="currentColor"', 'fill="#ffffff"')
        assert "currentColor" not in text, source
        (OUT / f"{name}.svg").write_text(text)
    print(f"vendored {len(VENDORED)} Pixelarticons icons")


def to_svg(rows: list[str]) -> str:
    assert len(rows) == 12 and all(len(r) == 12 for r in rows), "icons are 12x12 cells"
    cells = [f"M{x * 2} {y * 2}h2v2h-2z" for y, row in enumerate(rows) for x, ch in enumerate(row) if ch == "#"]
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="#ffffff" viewBox="0 0 24 24">'
            f'<path d="{"".join(cells)}"/></svg>\n')


# Counter-clockwise rotate: the clockwise icon mirrored left to right.
ICONS["rotate_ccw"] = [row[::-1] for row in ICONS["rotate"]]


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, rows in ICONS.items():
        (OUT / f"{name}.svg").write_text(to_svg(rows))
        print(f"wrote ui/icons/{name}.svg")
    if "--vendor" in sys.argv:
        vendor(Path(sys.argv[sys.argv.index("--vendor") + 1]))


if __name__ == "__main__":
    main()
