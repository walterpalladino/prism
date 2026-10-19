# PRISM — Implementation TODO

Task breakdown for the PRISM prototype, derived from [docs/prism-gdd/PRISM-GDD.md](docs/prism-gdd/PRISM-GDD.md) (v0.2).
Section references like `§7.2` point to the GDD. Milestones follow the roadmap in §10 (~17 weeks total).

**Legend:** `[ ]` todo · `[x]` done · **P0** prototype · **P1** stretch · **P2** later

**Ground rules (apply to every task)**

- GDScript is fully statically typed: no `:=`, no untyped `var`, no `Variant` in signatures (§6.2).
- `core/` scripts extend `RefCounted` and never touch `Node`, `SceneTree`, `Engine`, `Input` or autoloads (§9.2).
- One autoload only: `EditorContext` (composition root). Services get dependencies via `_init()`.
- UI never mutates the document directly — it calls app services and listens to their signals.
- Never load project files with `str_to_var()`, `bytes_to_var_with_objects()` or `ResourceLoader` — JSON and raw bytes only (§9.6).
- Clean-room: no code from Aseprite, the DPaint source release or LibreSprite (§2.1).
- Every new public function in `core/` and every command/tool in `app/` ships with gdUnit4 tests.

---

## M0 — Setup & technical spikes (1 week)

### Project setup
- [x] Pin Godot **4.7.2**; recorded in `README.md` and `CLAUDE.md` (CI config pending)
- [x] Switch renderer from Forward+ to **Compatibility** in `project.godot` (§9.4)
- [x] Remove the 3D physics engine setting (Jolt) — not needed for a 2D editor
- [x] Set GDScript warnings to **Error**: `untyped_declaration`, `inferred_declaration`, `unsafe_property_access`, `unsafe_method_access`, `unsafe_cast`, `unsafe_call_argument`, `return_value_discarded` (names verified against 4.7.2)
- [x] Enable *Snap 2D Transforms to Pixel* and default nearest texture filtering
- [x] Create folder skeleton: `boot/`, `core/{model,raster,modes,cycling}/`, `app/{commands,history,tools,playback,input}/`, `infra/{render,codecs,storage}/`, `ui/{scenes,theme}/`, `tests/golden/`, `tools/`, `docs/adr/` (§9.3)
- [x] Move `gen_concepts.py` to `tools/` (output path updated); `docs/` and `tools/` have `.gdignore`
- [x] Install **gdUnit4** 6.2.2 under `addons/gdUnit4/` and enable the plugin
- [x] Add `boot/editor_context.gd` as the single autoload (empty composition root)
- [x] Update `.gitignore` (export builds, `reports/`, `.vscode/`); `*.import` files are committed as Godot recommends
- [x] Write `CLAUDE.md` with architecture rules (§9.2), typing rule (§6.2) and file-loading security rule (§9.6)

### CI
- [ ] CI job: download pinned Godot 4.7.x, run gdUnit4 suites with `godot --headless` on every push
- [ ] CI job: render tests on Linux with a virtual display (`--rendering-driver opengl3`) (§11)
- [ ] Nightly export builds: Windows x86_64, macOS universal, Linux x86_64; create `export_presets.cfg`

### Spikes (each ends with an ADR in `docs/adr/`)
- [ ] **Spike A — display:** R8 index texture + palette LUT shader, 4 layers, zoom/pan; measure `ImageTexture.update()` at 256², 512², 1024²; decide tile size (default 64×64)
- [ ] **Spike B — input:** stroke latency with `Input.use_accumulated_input = false` + Bresenham interpolation
- [ ] **Spike C — CPU hot paths:** GDScript flood fill on 512² (budget < 50 ms); LZW-encode 64 frames of 256² GIF; decide on GDExtension for `RasterBackend` / GIF encoder
- [ ] **Spike D — coverage:** evaluate a GDScript coverage tool for 4.7; otherwise define a per-module test checklist
- [ ] Validate Compatibility vs Forward+ renderer (Q3)

**Exit:** all four spikes recorded as ADRs with go/no-go decisions; CI green on an empty test suite.

---

## M1 — Core model & raster ops (2 weeks)

### Model (`core/model/`) (§6)
- [ ] `PrismEnums` — `ColorMode`, `TagDirection`, `DrawMode`
- [ ] `IndexedImage` — id, width, height, `pixels: PackedByteArray`, `get_index` / `set_index`, `clone()`
- [ ] `Palette` — `PackedColorArray` (≤ 256), get/set color, ramps (list of `Vector2i` spans), ramp lookup for an index
- [ ] `Layer` — id, name, visible, locked, opacity
- [ ] `Frame` — id, `duration_ms`
- [ ] `Cel` — layer_id, frame_id, image_id, offset (shared `image_id` = linked cel)
- [ ] `Tag` — name, from/to frame, direction, color
- [ ] `CycleRange` — start/end index, `rate_hz`, step (±1), active
- [ ] `Stencil` — 256-byte lock table, `is_locked`, `set_locked`, `invert`, `lock_all_except(index)`
- [ ] `Brush` — `IndexedImage` + anchor; built-in square/round 1–8 px factory
- [ ] `PrismDocument` — all fields from §6.2; factory `PrismDocument.create(w, h, palette)` with one layer + one frame
- [ ] ID generator for layers/frames/images (deterministic in tests)
- [ ] Validation for all invariants in §6.3 (pixel count, index range, non-overlapping cycles, cel references exist) returning error lists, not crashing

### Raster ops (`core/raster/RasterOps`, static functions)
- [ ] Stencil-aware single write function used by every op (§6.3, §7.3)
- [ ] Put pixel, `read_rect` / `write_rect` (used by `PixelPatch`)
- [ ] Bresenham line (+ constrained angles: 0/45/90°, 1:2, 2:1)
- [ ] Rectangle outline / filled
- [ ] Midpoint ellipse outline / filled, symmetric pixels
- [ ] Scanline flood fill (4-way contiguous) and global replace
- [ ] Blit with transparent-index skip (brush stamping)
- [ ] Flip H / V, rotate 90°
- [ ] Pixel-perfect filter (remove L-shaped corners from a point sequence)
- [ ] Brush stamping along a path (brush shape at each point)
- [ ] `RasterBackend` interface + GDScript implementation (GDExtension-ready) (§9.2 rule 5)

### Drawing modes (`core/modes/`)
- [ ] Mode interface: `(dest_index, brush_index, button) -> new_index` or skip
- [ ] **Color** — solid FG/BG, custom brush as mask
- [ ] **Replace** — copy brush pixels, skip brush transparent index
- [ ] **Shade** — ±1 within the ramp containing the destination; clamp by default, wrap option (Q1)

### Tests
- [ ] gdUnit4 tests for every public function in `core/`
- [ ] Golden-buffer tests for each primitive (`tests/golden/*.bin`)
- [ ] Seeded property tests: random ops → invariants hold

**Exit:** every public `core/` function tested; golden tests for all primitives.

---

## M2 — Canvas, tools, undo (3 weeks)

### Commands & history (`app/commands/`, `app/history/`) (§7.11, §9.5)
- [ ] `@abstract Command` — `get_label`, `apply`, `revert`, `get_byte_size`
- [ ] `PixelPatch` — dirty-rect before/after bytes
- [ ] `History` — undo/redo stacks; limits by count (default 500, min 200) and memory (default 256 MB)
- [ ] `CommandBus` — executes commands, pushes to history, emits `document_changed(dirty: Rect2i)`
- [ ] Stroke coalescing: scratch buffer + growing dirty rect → one `PixelPatch` on release
- [ ] `Esc` cancel leaves no undo entry
- [ ] Property test: random command sequence, revert all == original

### Canvas view (`infra/render/`) (§9.4)
- [ ] `palette_lut.gdshader` (index → color, transparent discard, opacity, tint)
- [ ] Shared 256×1 RGBA8 palette `ImageTexture`
- [ ] `LayerSprite` — one sprite per visible cel, R8 texture from `IndexedImage`
- [ ] Tiled textures (64×64) for canvases > 256×256; update only dirty tiles, at most once per frame
- [ ] `CanvasView` scene: `SubViewportContainer` → `SubViewport` → `Camera2D` + layer sprites
- [ ] Zoom 1×–32× integer steps toward cursor (`+`/`-`/wheel, `1` = 1:1)
- [ ] Pan with Space+drag and middle mouse
- [ ] Checkerboard background (configurable colors)
- [ ] Pixel grid shader overlay (auto ≥ 600%, toggle `G`, optional custom tile grid)
- [ ] Ghost brush sprite snapped to cursor pixel; hidden over panels
- [ ] Floating preview `Window` (1×/2×)

### Input & tools (`app/tools/`, `app/input/`) (§7.2)
- [ ] `ToolController` — routes pointer events to active tool; LMB = FG, RMB = BG
- [ ] Stroke sampler: `use_accumulated_input = false` during strokes, Bresenham between events
- [ ] Pencil `D` (+ pixel-perfect toggle)
- [ ] Eraser `E` (transparent index, respects stencil)
- [ ] Line `L` (Shift = constrained angles)
- [ ] Rectangle `R` / filled `Shift+R`
- [ ] Ellipse `O` / filled
- [ ] Fill `F` contiguous / `Shift+F` global
- [ ] Picker `I` and Alt-hold (LMB → FG, RMB → BG)
- [ ] Rect select `M` — marching ants, copy/cut/paste, arrow-key nudge
- [ ] Move cel `V` — moves cel offset
- [ ] Brush pickup `B` (box) → custom brush, transparent index see-through
- [ ] Brush flip `X` / `Y`, rotate 90° `Z`, restore built-in `Shift+B`
- [ ] Built-in brush size/shape selection (1–8 px square/round)

### Shell UI
- [ ] `main.tscn` layout skeleton matching C1: menu bar, canvas, right toolbox, side panel, timeline dock, status bar (§8.1)
- [ ] Toolbox (2-column icon grid + FG/BG swatches)
- [ ] Status bar: cursor pos, index + hex under cursor, zoom, tool, frame
- [ ] `InputMap` actions for all default keys (§8.3)
- [ ] Prism dark `Theme` (`#1b1c23`, `#262833`, accents `#3d7bff` / `#ff8a3d`) (§8.2)

**Exit:** draw and edit a 64×64 sprite with full undo; `SceneRunner` smoke test simulates stroke + undo and checks the buffer.

---

## M3 — Palette, modes, stencil (2 weeks)

### Palette (§7.4)
- [ ] Default 32-color palette + presets: PICO-8-style 16, EGA 16, grayscale ramp
- [ ] Palette panel: swatch grid, FG/BG selection (LMB/RMB)
- [ ] Palette editor: RGB/HSV sliders, hex entry
- [ ] Reorder by drag **with remap** and **without remap** (both undoable commands)
- [ ] Ramp definition UI (mark contiguous spans)
- [ ] `[` / `]` step FG, `{` / `}` step BG
- [ ] Import/export `.gpl`, `.hex`, PNG strip (codecs with malformed-input tests)
- [ ] Palette edits as commands; emit `palette_changed()` and refresh the LUT texture

### Modes UI
- [ ] Mode selector (Color / Replace / Shade) in side panel and Mode menu
- [ ] Status bar highlights mode when not Color (§8.4)

### Stencil (§7.5)
- [ ] `Ctrl+click` swatch to lock; stencil row in side panel; `~` toggles stencil panel
- [ ] Quick actions: Invert stencil, Lock all except FG
- [ ] Orange underline on locked swatches
- [ ] Brief flash on stencil-blocked pixels (configurable)

**Exit:** scripted test paints a shaded sphere using Shade mode only and matches a golden image.

---

## M4 — Layers, frames, timeline (3 weeks)

### Layers (§7.7)
- [ ] Layers panel: add, delete, duplicate, rename, drag-reorder
- [ ] Visibility, lock, display opacity
- [ ] All layer ops as commands

### Frames & cels (§7.8)
- [ ] Frame ops: insert empty, duplicate (deep / linked), delete, drag-reorder
- [ ] Set duration (ms) for one or many frames
- [ ] Cel ops: link / unlink (copy-on-write clone), clear, copy/paste across frames
- [ ] Linked-cel edits mutate the shared image; property tests for link + undo correctness (Risk 4)

### Timeline UI
- [ ] Single custom `Control` drawing the whole cel grid in `_draw()` (§9.4.7)
- [ ] Duration row, empty-cel (○) and linked-cel markers, playhead (C2)
- [ ] Click cel to edit; frame/cel multi-selection
- [ ] Collapsible dock `Ctrl+T`
- [ ] Keys: `,` / `.` prev/next frame, `Enter` play/stop, `Alt+N` new frame, `Alt+D` duplicate

### Tags
- [ ] Create tag from frame selection; edit name / color / direction
- [ ] Tag bars drawn above the grid

### Playback (`app/playback/`)
- [ ] Playback engine driven by accumulated `delta` in `_process`, independent of render rate
- [ ] Forward / reverse / ping-pong; loop active tag or whole timeline
- [ ] Preview window plays independently

**Exit:** 8-frame, 3-layer walk cycle with two tags plays at correct durations (±2 ms drift over 10 s).

---

## M5 — Color cycling & onion skin (2 weeks)

### Color cycling (§7.6)
- [ ] `core/cycling/` — compute rotated palette for a time `t`; non-overlap validation (max 4 ranges)
- [ ] Cycle range editor (start, end, rate, direction, active) with brackets on the palette (C1/C3)
- [ ] `Tab` toggles cycling preview
- [ ] Rotate palette slice in the LUT texture once per tick
- [ ] Cycling runs during timeline playback and in the preview window

### Onion skin (§7.9)
- [ ] Past/future counts (0–5), separate tints (blue past / orange future), opacity falloff
- [ ] Tag-bounded vs global mode
- [ ] Extra tinted layer sprites via the LUT shader `tint` / `layer_opacity`
- [ ] Auto-hide during playback; `F3` toggle

### Render tests
- [ ] Golden PNG tests (real renderer) for LUT, transparency, cycling, onion skin (§11)

**Exit:** waterfall demo (C3) runs at stated rate; onion skin at 3 past / 2 future stays ≥ 60 fps.

---

## M6 — File I/O & export (2 weeks)

### Infrastructure
- [ ] `DocumentRepository` interface + `FileAccess`/`ZIPPacker` implementation + in-memory fake (§9.2 rule 4)
- [ ] `ImageCodec` interface

### Native format `.prism` (§9.6)
- [ ] Writer: `ZIPPacker`, `document.json` (v1 schema) + `images/*.bin`
- [ ] Reader: `ZIPReader` + `JSON.parse_string()`, field-by-field typed validation
- [ ] Migration scaffold `infra/codecs/prism/migrations/`; clear error on unknown future version
- [ ] Round-trip tests (save → load → identical model); malformed/truncated inputs return errors

### Autosave & recovery
- [ ] Autosave to `user://autosave/` every N seconds on `WorkerThreadPool` using a document snapshot
- [ ] Crash recovery prompt on startup

### Import / export (§7.12)
- [ ] Native file dialogs (`FileDialog.use_native_dialog = true`) with filters per format
- [ ] PNG single frame import/export (RGBA); import maps colors to palette
- [ ] PNG sequence export (`name_0001.png` …)
- [ ] Sprite sheet + JSON: row, column, grid, tight packing; frames, durations, tags in JSON
- [ ] Godot `SpriteFrames` `.tres` + `sheet.png`: one animation per tag, `AtlasTexture` regions, per-frame durations relative to base FPS, loop flag; target project folder chooser for `res://` paths
- [ ] GIF encoder (LZW, global palette, per-frame delays, transparency index)
- [ ] GIF / PNG-sequence cycling bake (LCM of periods, user cap, predicted frame-count warning) (Risk 5)
- [ ] Export compositing (layers + visibility) shared by all exporters

**Exit:** round-trip tests pass; generated `SpriteFrames` opens in Godot 4.7 and every tag plays correctly on an `AnimatedSprite2D`.

---

## M7 — Polish & playtest (2 weeks)

### Preferences (§7.13)
- [ ] `ConfigFile` at `user://settings.cfg`: theme (dark/light), checkerboard colors, onion tints, autosave interval, UI scale
- [ ] Light theme `prism_light.tres`
- [ ] Key binding overrides in `user://keybindings.json`, applied at startup
- [ ] Consider "Classic" vs "Modern" key presets (Risk 3)

### Polish
- [ ] Menu bar fully wired: Project, Edit, Picture, Brush, Mode, Anim, Effect, View
- [ ] Keyboard map review (resolve `.` conflict, §8.3 note)
- [ ] Tooltips with shortcuts, empty states, error dialogs
- [ ] Performance benchmarks vs §9.4 budgets: stroke < 8 ms @ 512², playback 60 fps @ 256² × 4 layers + onion, full-canvas undo < 16 ms, flood fill 512² < 50 ms
- [ ] 2-hour soak test: random commands + autosave + reload, no data loss

### Playtest
- [ ] Sessions with 3–5 artists (DPaint veteran, Aseprite user, game dev) running the §13 task script
- [ ] Collect "feels like DPaint" / "feels like a modern sprite tool" ratings (target ≥ 4/5)
- [ ] Triage findings into the P1 backlog

**Exit:** all §13 success criteria met; prioritized post-prototype backlog.

---

## Post-prototype backlog (ordered, §10)

1. [ ] Anim-brushes — multi-frame brush advancing per stamp (P1, §7.10)
2. [ ] Lasso / polygon selection & pickup (P1)
3. [ ] Symmetry (H/V) & tiled-wrap mode (P1)
4. [ ] Smear and Cycle drawing modes (P1)
5. [ ] RGBA document mode (P1)
6. [ ] IFF ILBM import — BMHD/CMAP/BODY, ByteRun1 (P1)
7. [ ] Indexed PNG encoder — PLTE + tRNS, zlib, CRC32 (P1)
8. [ ] Headless CLI export via `OS.get_cmdline_user_args()` (§9.7)
9. [ ] Scripting API
10. [ ] Tilemaps with Godot `TileSet` export
11. [ ] Web export build

Also P1/P2: pen pressure, palette extraction/quantize from PNG, reference layer, layer groups, movable docks, "Workbench" skin, IFF ANIM export, `.aseprite` import (Q2), macOS signing + notarization.

---

## Open questions to resolve (§12)

- [ ] Q1 — Shade mode at ramp ends: clamp (default) or wrap?
- [ ] Q2 — `.aseprite` import worth the licensing review pre-1.0?
- [ ] Q3 — Compatibility vs Forward+ as shipped default (decide in M0)
- [ ] Q4 — Fixed layout vs dockable panels (fixed for prototype)
