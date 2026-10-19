# PRISM — agent directives

PRISM is a palette-first pixel painter and frame animator built as a Godot application.
The design source of truth is [docs/prism-gdd/PRISM-GDD.md](docs/prism-gdd/PRISM-GDD.md); the task list is [TODO.md](TODO.md).
Tick TODO items when they are done and verified.

## Engine

- Godot **4.7.2** (pinned). Do not use APIs newer than 4.7.
- Renderer: **Compatibility** (`gl_compatibility`). Nearest texture filtering and 2D pixel snapping are on project-wide.

## Typing (enforced — the project will not parse otherwise)

These GDScript warnings are set to **Error** in `project.godot`:
`untyped_declaration`, `inferred_declaration`, `unsafe_property_access`, `unsafe_method_access`,
`unsafe_cast`, `unsafe_call_argument`, `return_value_discarded`.

- Declare every variable, parameter and return type explicitly. No `:=`. No untyped `var`.
- No `Variant` in function signatures.
- Use typed arrays and typed dictionaries (`Array[Layer]`, `Dictionary[Vector2i, Cel]`).
- Type loop variables: `for layer: Layer in doc.layers:`.
- When a return value is intentionally unused, assign it (`var err: int = ...`) and check it, or put
  `@warning_ignore("return_value_discarded")` on the line before (needed for `Packed*Array.append()`, which returns a bool).
- Connect signals with `Signals.on(sig, callable)` (`core/util/signals.gd`): `Signal.connect()` returns an
  error code, which the typing rules forbid discarding.
- Typed `const` arrays of `PackedStringArray` literals come out empty at runtime; use `Array[Array]` for tables.
- `res://addons/` is excluded from warnings via `debug/gdscript/warnings/directory_rules`.

## Architecture rules (GDD §9.2)

1. `core/` scripts extend `RefCounted` and never reference `Node`, `SceneTree`, `Engine`, `Input` or any autoload.
2. Exactly one autoload: `EditorContext` (`boot/editor_context.gd`), the composition root.
   Services receive dependencies through `_init()` parameters — no global lookups inside services.
3. UI nodes never mutate the document. They call application services and listen to their signals
   (`document_changed(dirty: Rect2i)`, `frame_changed(index: int)`, `palette_changed()`).
4. All file and OS access goes through interfaces in `infra/` (`DocumentRepository`, `ImageCodec`) so tests can use fakes.
5. Every hot loop sits behind a GDExtension-ready interface (`RasterBackend`) with a GDScript implementation first.
6. Every document mutation is a `Command` (`app/commands/`) with `apply` / `revert`; Godot's `UndoRedo` is not used.
   Tools paint live into the image and record one `PixelPatch` per stroke on release (`StrokeSession`);
   `CommandBus.execute()` applies + records, `CommandBus.record()` records an already-applied command.
7. Keyboard shortcuts are `InputMap` actions defined in `Shortcuts.DEFAULTS` (`app/input/shortcuts.gd`) and stored in
   `project.godot`. After changing the table, regenerate the `[input]` section (see `Shortcuts` doc comment) and match
   with `is_action_pressed(action, echo, true)` (exact match, so `X` does not fire on `Ctrl+X`).

## GDScript facts that matter here (see docs/adr/)

- Packed arrays are **shared by reference** on assignment and argument passing in 4.7 (ADR 0005).
  Aliasing `image.pixels` in a hot loop is fine; call `duplicate()` whenever an independent copy is needed.
- In hot loops, typed `for i: int in range(a, b)` beats `while`; avoid allocating arrays per iteration;
  inline small helpers (ADR 0003). Re-run `bench/cpu_bench.gd` after touching raster code.
- After adding or renaming a `class_name`, refresh the global class cache before running tests:
  `godot --headless --path . --import`.

## Layout

```
boot/    composition root (EditorContext autoload)
core/    domain model, raster ops, drawing modes, cycling — RefCounted only
app/     commands, history, tools, playback, input
infra/   rendering (CanvasView, shaders), codecs, storage
ui/      scenes and themes
tests/   gdUnit4 suites mirroring the folders above; tests/golden/ holds expected outputs
bench/   benchmark scripts (excluded from exports)
tools/   offline scripts, e.g. api_coverage.py (Godot ignores this folder)
docs/    GDD, ADRs in docs/adr/ (Godot ignores this folder)
```

## Icons

- UI icons live in `ui/icons/` as white 24×24 SVGs, loaded with `PrismIcons.get_icon(name)` and tinted by the theme.
- Source: Pixelarticons 2.4.2 (MIT, credited in `CREDITS.md`). Need a new one? Add it to `VENDORED` in
  `tools/gen_icons.py` and run it with `--vendor <pixelarticons>/svg`. If the pack lacks it, draw it as a 12×12
  cell grid in `ICONS` there, keeping the Pixelarticons look.
- Never add icons or art from another source without recording its license in `CREDITS.md`.

## Security

Never load project or user files with `str_to_var()`, `bytes_to_var_with_objects()` or `ResourceLoader`.
Use `JSON.parse_string()` plus field-by-field validation, and raw bytes. Malformed input returns an error, never crashes.

## Clean-room

Do not copy code from Aseprite (EULA), the DPaint source release (non-commercial) or LibreSprite (GPLv2).
Reimplement behavior from public manuals and documentation.

## Tests

- Framework: gdUnit4 6.2.2 in `addons/gdUnit4/`.
- Test files are named `*_test.gd`, extend `GdUnitTestSuite`, and start with
  `@warning_ignore_start("return_value_discarded")` because gdUnit4's fluent asserts return a value.
- Every public function in `core/` and every command/tool in `app/` needs tests.
  `python3 tools/api_coverage.py` lists public functions no test calls; keep it at 100 % (ADR 0004).
- Golden files live in `tests/golden/` as text (one hex digit per pixel). Regenerate with
  `PRISM_UPDATE_GOLDEN=1` and review the diff by eye before committing.
- Run all tests headless:

  ```sh
  GODOT_BIN=/path/to/Godot addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -a res://tests
  ```

  Rendering tests need a real renderer and cannot run with `--headless`. Godot's headless display server
  also does not route mouse input to the GUI, so `tests/ui/` skips itself under `--headless`. Run the whole
  suite with a window before ticking UI work:

  ```sh
  GODOT_BIN=/path/to/Godot addons/gdUnit4/runtest.sh -a res://tests
  ```
- UI tests push `InputEvent`s into the scene viewport (`get_viewport().push_input`) rather than using gdUnit4's
  mouse simulation, so input goes through real GUI hit-testing.

## Benchmarks

```sh
godot --headless --path . -s res://bench/cpu_bench.gd      # flood fill, undo patches, strokes, GIF LZW
godot --path . -s res://bench/display_bench.gd             # texture uploads, frame times (opens a window)
godot --path . -s res://bench/lut_check.gd                 # palette shader correctness (opens a window)
```
