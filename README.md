# PRISM

A palette-first pixel painter with a modern animation timeline — *"DPaint's hands, Aseprite's timeline."*

- Design document: [docs/prism-gdd/PRISM-GDD.md](docs/prism-gdd/PRISM-GDD.md)
- Task list: [TODO.md](TODO.md)

## Requirements

- **Godot 4.7.2** (pinned; other versions are untested)

## Running

Open the folder in Godot 4.7.2 and press Play, or:

```sh
godot --path .
```

## Tests

Tests use [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) 6.2.2, vendored in `addons/gdUnit4/`.

```sh
GODOT_BIN=/path/to/Godot addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -a res://tests
```

The UI tests in `tests/ui/` need a window (Godot's headless mode does not route mouse input to the GUI)
and skip themselves under `--headless`. To run everything:

```sh
GODOT_BIN=/path/to/Godot addons/gdUnit4/runtest.sh -a res://tests
```

Reports are written to `reports/` (git-ignored).

```sh
python3 tools/api_coverage.py                                # public functions not called by any test
PRISM_UPDATE_GOLDEN=1 GODOT_BIN=... addons/gdUnit4/runtest.sh ...   # regenerate golden files
```

## Benchmarks

See `bench/` and the measurements in [docs/adr/](docs/adr/README.md).

```sh
godot --headless --path . -s res://bench/cpu_bench.gd
godot --path . -s res://bench/display_bench.gd
```

## File formats and export

All formats are in the **Project** menu. Exports ask which frames to include (all frames or one tag) and an
integer pixel scale (1–8×, nearest neighbor).

| Format | Read / write | Notes |
|---|---|---|
| `.prism` | R/W | Native document (see below) |
| PNG, one frame | R/W | Import maps colors to the nearest palette entry; *New from PNG* uses the image's own colors (≤ 255) |
| PNG sequence | W | `name_0001.png`, `name_0002.png`, …; can bake color cycling into frames |
| Sprite sheet + JSON | W | All frames in one PNG plus a JSON description (see below) |
| Godot `SpriteFrames` | W | `.tres` + sheet PNG, one animation per tag |
| GIF | W | Animated, loops forever; can bake color cycling into frames |
| Palettes `.gpl`, `.hex`, PNG strip | R/W | Project → Load / Save palette |

### `.prism` documents

A zip archive with `document.json` (versioned schema, currently v1) and `images/<id>.bin` (raw palette
indices, one byte per pixel). Files are only ever parsed as JSON and raw bytes, and every field is validated:
a damaged or newer-version file gives an error message, never a crash. Saves go to a temporary file first
and replace the target only when complete.

### Sprite sheet + JSON

**Layout options:** row, column, grid or tight (trimmed); for grids, columns × rows (0 = automatic; if both
are set they must hold every frame); outer margin (pixels between the sheet border and the frames) and
spacing (pixels between frames). Margin and spacing are in output pixels, not multiplied by the scale.

**JSON format.** The JSON follows the **TexturePacker "JSON (Array)"** layout, with the two extensions
Aseprite adds to it: a per-frame `duration` (ms) and `meta.frameTags`. This is a de facto standard (there is
no formal specification), so tools that read Aseprite or TexturePacker array sheets can usually read PRISM
sheets as they are.

```json
{
  "frames": [
    {
      "filename": "frame 1",
      "frame": { "x": 8, "y": 8, "w": 48, "h": 32 },
      "rotated": false,
      "trimmed": false,
      "spriteSourceSize": { "x": 0, "y": 0, "w": 48, "h": 32 },
      "sourceSize": { "w": 48, "h": 32 },
      "duration": 100
    }
  ],
  "meta": {
    "app": "PRISM",
    "version": "0.0.1",
    "image": "hero.png",
    "format": "RGBA8888",
    "size": { "w": 168, "h": 48 },
    "scale": "1",
    "frameTags": [
      { "name": "walk", "from": 0, "to": 3, "direction": "forward", "color": "#3d7bff" }
    ]
  }
}
```

| Field | Meaning |
|---|---|
| `frames[]` | One entry per exported frame, in timeline order |
| `frame` | Where the frame is in the sheet (pixels, includes margin and spacing) |
| `trimmed`, `spriteSourceSize` | Tight layout only: the trimmed area inside the full frame |
| `sourceSize` | Full frame size (canvas × scale) |
| `duration` | Frame duration in milliseconds |
| `meta.image`, `meta.size` | Sheet file name and size |
| `meta.frameTags[]` | Tags inside the exported range: `from` / `to` are 0-based indices into `frames`; `direction` is `forward`, `reverse` or `pingpong` |

**Known compatible readers** (from their documented formats; not every tool has been tested with PRISM):
Phaser 3 (texture atlas loader, and its Aseprite animation import, which uses `frameTags` and `duration`),
Godot community Aseprite importers, and TexturePacker / Aseprite JSON importers for Unity, Construct and
Defold. **Not compatible as is:** PixiJS, which expects the "JSON (Hash)" variant (frames keyed by name),
and libGDX, which uses its own `.atlas` text format.

**Differences from Aseprite's own JSON:**

- Tag `color` is `#rrggbb` (recent Aseprite versions write `#rrggbbaa`); readers generally ignore it.
- No `meta.layers` or `meta.slices`: PRISM exports flattened frames and has no slices.
- `direction` has no `pingpong_reverse` (Aseprite 1.3), because PRISM has no such tag direction.
- Frame names are `frame 1`, `frame 2`, …; this only matters if a game looks frames up by name.

### Godot `SpriteFrames`

Save the `.tres` inside a Godot project (a folder with `project.godot` somewhere above it) so the sheet gets a
`res://` path. Each tag becomes an animation (`default` when there are no tags), with looping on, playback
`speed` = 1000 / the tag's shortest frame (ms) and each frame's `duration` relative to it, so frames last
exactly as long as in PRISM. Reverse and ping-pong tags are written out as frame sequences.

### GIF

Global palette, per-frame delays (rounded without drift; GIF delays are in 1/100 s, minimum 2), transparency
from the transparent index, loops forever. Layer opacity cannot be represented in GIF and is ignored. With
*Bake color cycling*, frames are split wherever a cycle steps, each with its own color table, covering one
full loop of animation and cycles (capped at 500 frames, with a warning).

## Building PRISM

`export_presets.cfg` defines Windows x86_64, macOS universal, Linux x86_64 and Web. Install the Godot 4.7.2
export templates first (Editor → Manage Export Templates).

### Web (HTML5) build

`.github/workflows/web.yml` exports the **Web** preset on every push to `main` (or on demand from the
Actions tab) and publishes it to GitHub Pages at <https://walterpalladino.github.io/prism/>.
One-time setup: repository Settings → Pages → Build and deployment → Source: **GitHub Actions**.

**Releases:** pushing a version tag builds that version and publishes a GitHub Release with the web
build as `prism-web-<tag>.zip` (plus `LICENSE` and `CREDITS.md`). The tag sets the version shown in
About; the site on Pages keeps following `main`.

```sh
git tag v0.1.0
git push origin v0.1.0
```

The Web preset uses Godot's single-threaded template, because GitHub Pages cannot send the
cross-origin isolation headers threaded builds need. To build it locally:

```sh
godot --headless --path . --export-release "Web" build/web/index.html
python3 -m http.server --directory build/web   # then open http://localhost:8000
```

Limitations of the web build today: file dialogs only see the browser's private storage, so Open,
Save, Import and Export cannot reach files on your computer yet. Autosave and settings persist in
the browser (IndexedDB). UI text must use characters of Godot's built-in font (there are no system
fonts to fall back on); `tests/ui/glyphs_test.gd` checks this.

## License

PRISM is released under the [MIT License](LICENSE). Third-party components (Godot Engine, Pixelarticons,
gdUnit4) and their licenses are listed in [CREDITS.md](CREDITS.md); the About dialog also shows them.
