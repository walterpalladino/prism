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

## Exporting

`export_presets.cfg` defines Windows x86_64, macOS universal and Linux x86_64. Install the Godot 4.7.2
export templates first (Editor → Manage Export Templates).
