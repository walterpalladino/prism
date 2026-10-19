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

Reports are written to `reports/` (git-ignored).
