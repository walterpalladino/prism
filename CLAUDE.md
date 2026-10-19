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
- When a return value is intentionally unused, assign it (`var err: int = ...`) and check it.
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

## Layout

```
boot/    composition root (EditorContext autoload)
core/    domain model, raster ops, drawing modes, cycling — RefCounted only
app/     commands, history, tools, playback, input
infra/   rendering (CanvasView, shaders), codecs, storage
ui/      scenes and themes
tests/   gdUnit4 suites mirroring the folders above; tests/golden/ holds expected outputs
tools/   offline scripts (Godot ignores this folder)
docs/    GDD, ADRs (Godot ignores this folder)
```

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
- Run all tests headless:

  ```sh
  GODOT_BIN=/path/to/Godot addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -a res://tests
  ```

  Rendering tests need a real renderer and cannot run with `--headless`.
