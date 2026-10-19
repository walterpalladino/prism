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
- [x] Pin Godot **4.7.2**; recorded in `README.md` and `CLAUDE.md`
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

### Export presets
- [x] Create `export_presets.cfg`: Windows x86_64, macOS universal, Linux x86_64 (local builds; CI is deferred, see *Future: GitHub CI*)

### Spikes (each ends with an ADR in `docs/adr/`)
- [x] **Spike A — display:** R8 index texture + palette LUT shader, 4 layers, zoom/pan; measure `ImageTexture.update()` at 256², 512², 1024²; decide tile size (default 64×64) → no tiling needed ≤ 512² ([ADR 0001](docs/adr/0001-display-pipeline.md))
- [x] **Spike B — input:** stroke latency with `Input.use_accumulated_input = false` + Bresenham interpolation → CPU ≤ 0.7 ms/event; hand-check real latency in M2 ([ADR 0002](docs/adr/0002-stroke-input.md))
- [x] **Spike C — CPU hot paths:** GDScript flood fill on 512² (budget < 50 ms); LZW-encode 64 frames of 256² GIF; decide on GDExtension for `RasterBackend` / GIF encoder → stay in GDScript ([ADR 0003](docs/adr/0003-cpu-hot-paths.md))
- [x] **Spike D — coverage:** evaluate a GDScript coverage tool for 4.7; otherwise define a per-module test checklist → none usable; `tools/api_coverage.py` + checklist ([ADR 0004](docs/adr/0004-test-coverage.md))
- [x] Validate Compatibility vs Forward+ renderer (Q3) → Compatibility ([ADR 0006](docs/adr/0006-renderer.md))

**Exit:** all four spikes recorded as ADRs with go/no-go decisions; test suite runs green locally. ✅ Also: [ADR 0005](docs/adr/0005-packed-array-semantics.md) (packed arrays are shared by reference in 4.7).

Also delivered early (needed by the spikes): `infra/render/palette_lut.gdshader` (M2) and `infra/codecs/gif/gif_lzw.gd` LZW encoder (M6).

---

## M1 — Core model & raster ops (2 weeks)

### Model (`core/model/`) (§6)
- [x] `PrismEnums` — `ColorMode`, `TagDirection`, `DrawMode`
- [x] `IndexedImage` — id, width, height, `pixels: PackedByteArray`, `get_index` / `set_index`, `duplicate_image()`
- [x] `Palette` — `PackedColorArray` (≤ 256), get/set color, ramps (list of `Vector2i` spans), ramp lookup for an index
- [x] `Layer` — id, `layer_name`, visible, locked, opacity
- [x] `Frame` — id, `duration_ms`
- [x] `Cel` — layer_id, frame_id, image_id, offset (shared `image_id` = linked cel)
- [x] `Tag` — name, from/to frame, direction, color
- [x] `CycleRange` — start/end index, `rate_hz`, step (±1), active
- [x] `Stencil` — 256-byte lock table, `is_locked`, `set_locked`, `invert`, `lock_all_except(index)`
- [x] `Brush` — `IndexedImage` + anchor; built-in square/round 1–8 px factory
- [x] `PrismDocument` — all fields from §6.2; factory `PrismDocument.create(w, h, palette)` with one layer + one frame
- [x] ID generator for layers/frames/images (deterministic in tests)
- [x] Validation for all invariants in §6.3 (pixel count, index range, non-overlapping cycles, cel references exist) returning error lists, not crashing

### Raster ops (`core/raster/RasterOps`, static functions)
- [x] Stencil-aware single write function used by every op (§6.3, §7.3)
- [x] Put pixel, `read_rect` / `write_rect` (used by `PixelPatch`)
- [x] Bresenham line (+ constrained angles: 0/45/90°, 1:2, 2:1)
- [x] Rectangle outline / filled
- [x] Midpoint ellipse outline / filled, symmetric pixels
- [x] Scanline flood fill (4-way contiguous) and global replace (512² noise worst case 49.7 ms)
- [x] Blit with transparent-index skip (brush stamping)
- [x] Flip H / V, rotate 90°
- [x] Pixel-perfect filter (remove L-shaped corners from a point sequence)
- [x] Brush stamping along a path (brush shape at each point)
- [x] `RasterBackend` interface + GDScript implementation (GDExtension-ready) (§9.2 rule 5)

### Drawing modes (`core/modes/`)
- [x] Mode interface `Ink.apply(dest, brush_value, brush_is_mask, ctx) -> new index or SKIP`; `Painter` applies brush + ink + stencil, each pixel at most once per stroke
- [x] **Color** — solid FG/BG, custom brush as mask
- [x] **Replace** — copy brush pixels, skip brush transparent index
- [x] **Shade** — ±1 within the ramp containing the destination; clamp by default, wrap option (Q1)

### Tests
- [x] gdUnit4 tests for every public function in `core/`
- [x] Golden tests for each primitive (text files in `tests/golden/`, reviewable in diffs)
- [x] Seeded property tests: random ops → invariants hold

**Exit:** every public `core/` function tested; golden tests for all primitives. ✅ 92 tests, API coverage 100 %.

---

## M2 — Canvas, tools, undo (3 weeks)

### Commands & history (`app/commands/`, `app/history/`) (§7.11, §9.5)
- [x] `@abstract Command` — `get_label`, `apply`, `revert`, `get_byte_size`
- [x] `PixelPatch` — dirty-rect before/after bytes
- [x] `History` — undo/redo stacks; limits by count (default 500, min 200) and memory (default 256 MB)
- [x] `CommandBus` — executes commands, pushes to history, emits `document_changed(dirty: Rect2i)`
- [x] Stroke coalescing: scratch buffer + growing dirty rect → one `PixelPatch` on release
- [x] `Esc` cancel leaves no undo entry
- [x] Property test: random command sequence, revert all == original

### Canvas view (`infra/render/`) (§9.4)
- [x] `palette_lut.gdshader` (index → color, transparent discard, opacity, tint)
- [x] Shared 256×1 RGBA8 palette `ImageTexture`
- [x] `LayerSprite` — one sprite per visible cel, R8 texture from `IndexedImage`
- [x] ~~Tiled textures~~ not needed ≤ 512² ([ADR 0001](docs/adr/0001-display-pipeline.md)); `CelTextureCache` uploads each dirty cel at most once per frame
- [x] `CanvasView` scene: `SubViewportContainer` → `SubViewport` → `Camera2D` + layer sprites
- [x] Zoom 1×–32× integer steps toward cursor (`+`/`-`/wheel, `1` = 1:1)
- [x] Pan with Space+drag and middle mouse
- [x] Checkerboard background (colors are shader uniforms; user setting arrives with Preferences in M7)
- [x] Pixel grid shader overlay (auto ≥ 600%, toggle `G`, tile grid 8/16/32 from the View menu)
- [x] Ghost brush sprite snapped to cursor pixel; hidden over panels
- [x] Floating preview `Window` (1×/2×), sharing the canvas textures

### Input & tools (`app/tools/`, `app/input/`) (§7.2)
- [x] `ToolController` — routes pointer events to active tool; LMB = FG, RMB = BG
- [x] Stroke sampler: `use_accumulated_input = false` during strokes, Bresenham between events
- [ ] Hand-check real input-to-screen latency (fast circles at 800%, ghost must not trail) — ADR 0002 follow-up
- [x] Pencil `D` (+ pixel-perfect toggle)
- [x] Eraser `E` (transparent index, respects stencil)
- [x] Line `L` (Shift = constrained angles)
- [x] Rectangle `R` / filled `Shift+R`
- [x] Ellipse `O` / filled
- [x] Fill `F` contiguous / `Shift+F` global
- [x] Picker `I` and Alt-hold (LMB → FG, RMB → BG)
- [x] Rect select `M` — marching ants, copy/cut/paste, arrow-key nudge
- [x] Move cel `V` — moves cel offset
- [x] Brush pickup `B` (box) → custom brush, transparent index see-through
- [x] Brush flip `X` / `Y`, rotate 90° `Z`, restore built-in `Shift+B`
- [x] Built-in brush size/shape selection (1–8 px square/round)

### Shell UI
- [x] `main.tscn` layout matching C1: menu bar, canvas, right toolbox, side panel, timeline dock (placeholder until M4), status bar (§8.1). Panels are `class_name` scripts in `ui/panels/` built in code
- [x] Toolbox (2-column icon grid + FG/BG swatches) — Pixelarticons icons (MIT) + 3 project-drawn (line, fill, rotate); menu items have icons too
- [x] Status bar: cursor pos, index + hex under cursor, zoom, tool, frame
- [x] `InputMap` actions for all default keys (§8.3)
- [x] Prism dark `Theme` (`#1b1c23`, `#262833`, accents `#3d7bff` / `#ff8a3d`) (§8.2), built in `ui/theme/prism_theme.gd`

**Exit:** draw and edit a 64×64 sprite with full undo; `SceneRunner` smoke test simulates stroke + undo and checks the buffer. ✅ 154 tests (UI smoke tests need a window), API coverage 100 %.

Also delivered early: a minimal palette swatch grid (LMB = FG, RMB = BG) so M2 is usable; full palette editing is M3.

---

## M3 — Palette, modes, stencil (2 weeks)

### Palette (§7.4)
- [x] Default 32-color palette + presets: PICO-8-style 16, EGA 16, grayscale ramp
- [x] Palette panel: swatch grid, FG/BG selection (LMB/RMB)
- [x] Palette editor: RGB/HSV sliders, hex entry — popup opened by double-clicking a swatch (`ColorEditDialog`); original vs new swatches; live preview; OK = one undo step, Cancel/close restores
- [x] Reorder by drag **with remap** (pixels, transparent index, stencil and FG/BG follow) and **without remap** (Shift+drag) — both undoable
- [x] Ramp definition UI: "Ramp FG→BG" / "Remove", blue bars over ramp spans; Shade wrap option (Q1 default: clamp)
- [x] `[` / `]` step FG, `{` / `}` step BG
- [x] Import/export `.gpl`, `.hex`, PNG strip (codecs with malformed-input tests); native file dialogs; presets in the Picture menu
- [x] Palette edits as commands; `CommandBus.palette_changed` refreshes the LUT texture. A shorter loaded palette is padded so no pixel points outside it

### Modes UI
- [x] Mode selector (Color / Replace / Shade) in side panel and Mode menu
- [x] Status bar highlights mode when not Color (§8.4)

### Stencil (§7.5)
- [x] `Ctrl+click` swatch to lock; stencil section in side panel; `~` toggles it. Stencil changes are undoable
- [x] Quick actions: Invert stencil, Lock all except FG
- [x] Orange underline on locked swatches
- [x] Brief orange flash on stencil-blocked pixels (option in the stencil section)

**Exit:** scripted test paints a shaded sphere using Shade mode only and matches a golden image. ✅ `tests/app/scenarios/shaded_sphere_test.gd` (outline protected by the stencil); 196 tests, API coverage 100 %.

---

## M4 — Layers, frames, timeline (3 weeks)

### Layers (§7.7)
- [x] Layers panel: add, delete, duplicate, rename (double-click), drag-reorder — the timeline's left column (Aseprite-style) plus toolbar, Anim menu and context menu
- [x] Visibility (eye), lock, display opacity (context menu → Layer opacity…)
- [x] All layer/frame/cel/tag ops are commands: `StructureCommand` stores before/after `DocumentStructure` snapshots

### Frames & cels (§7.8)
- [x] Frame ops: insert empty, duplicate (deep / linked), delete, drag-reorder (drag a frame number)
- [x] Set duration (ms) for one or many frames (double-click the ms row; new frames inherit the duration)
- [x] Cel ops: link / unlink (clone), clear, copy/paste across frames. Every layer×frame slot always has a cel; "empty" = all transparent
- [x] Linked-cel edits mutate the shared image; property test: random timeline ops + strokes, undo-all = original, redo-all = final (Risk 4)

### Timeline UI
- [x] Single custom `Control` drawing the whole cel grid in `_draw()` (§9.4.7)
- [x] Duration row, empty-cel (○) and linked-cel markers, playhead (C2)
- [x] Click cel to edit; Shift+click / drag selects a frame range
- [x] Collapsible dock `Ctrl+T`
- [x] Keys: `,` / `.` prev/next frame, `Enter` play/stop, `Alt+N` new frame, `Alt+D` duplicate

### Tags
- [x] Create tag from frame selection; edit name / color / direction
- [x] Tag bars drawn above the grid

### Playback (`app/playback/`)
- [x] Playback engine driven by accumulated `delta` in `_process`, independent of render rate
- [x] Forward / reverse / ping-pong; loop active tag or whole timeline
- [x] Preview window plays independently (own `Playback`, play button and 1×/2× toggle)

**Exit:** 8-frame, 3-layer walk cycle with two tags plays at correct durations (±2 ms drift over 10 s).

---

## M5 — Color cycling & onion skin (2 weeks)

### Color cycling (§7.6)
- [x] `core/cycling/` — `ColorCycler` computes the rotated palette for a time `t` (+ loop length for M6 baking); non-overlap validation (max 4 ranges)
- [x] Cycle range editor (CYCLING section: add FG→BG, edit form, on/off, delete — all undoable) with teal brackets on the palette (C1/C3)
- [x] `Tab` toggles cycling preview
- [x] Rotate palette slice in the LUT texture only when a cycle steps (`ColorCycling` → `PaletteDisplay`, the single LUT writer)
- [x] Cycling runs during timeline playback and in the preview window

### Onion skin (§7.9)
- [x] Past/future counts (0–5), separate tints (blue past / orange future), opacity falloff
- [x] Tag-bounded vs global mode
- [x] Extra tinted layer sprites via the LUT shader `tint` (rgb + mix strength) / `layer_opacity`; drawn in front of the current frame by default ("Front" checkbox switches to behind); timeline info says when there are no neighboring frames
- [x] Auto-hide during playback; `F3` toggle; controls in the timeline toolbar

### Render tests
- [x] Golden PNG tests (real renderer) for LUT, transparency + opacity, cycling, onion skin (§11) — `tests/render/`, windowed only

**Exit:** waterfall demo (C3) runs at stated rate; onion skin at 3 past / 2 future stays ≥ 60 fps. ✅ Project → Open demo: Waterfall; `waterfall_test.gd` checks 12 steps/s over 10 s; `bench/onion_bench.gd` 4.3 ms/frame (231 fps), [ADR 0007](docs/adr/0007-onion-and-cycling-rendering.md). 262 tests, API coverage 100 %.

---

## M6 — File I/O & export (2 weeks)

### Infrastructure
- [x] `DocumentRepository` interface + `ZipDocumentRepository` (atomic: temp file then move) + `MemoryDocumentRepository` fake (§9.2 rule 4)
- [x] ~~`ImageCodec`~~ → `FileSink` interface (`DiskFileSink`, `MemoryFileSink`): exporters produce images/bytes, the sink reads/writes them

### Native format `.prism` (§9.6)
- [x] Writer: `ZIPPacker`, `document.json` (v1 schema) + `images/*.bin`
- [x] Reader: `ZIPReader` + `JSON.parse_string()`, field-by-field typed validation
- [x] Migration scaffold `infra/codecs/prism/migrations/`; clear error on unknown future version ("saved by a newer PRISM")
- [x] Round-trip tests (save → load → identical model); malformed/truncated inputs return errors

### Autosave & recovery
- [x] Autosave to `user://autosave/` every 60 s (when there are unsaved changes) on `WorkerThreadPool` using a deep-copied snapshot
- [x] Crash recovery prompt on startup (session lock file + autosave left behind = crash); unsaved-changes prompt on New/Open/Quit; `*` in the window title

### Import / export (§7.12)
- [x] Native file dialogs (`FileDialog.use_native_dialog = true`) with filters per format
- [x] PNG single frame import/export (RGBA); import maps colors to the nearest palette entry; "New from PNG" uses the image's own colors (≤ 255)
- [x] PNG sequence export (`name_0001.png` …)
- [x] Sprite sheet + JSON: row, column, grid, tight packing; frames, durations, tags in JSON; choose columns × rows (0 = auto), outer margin and spacing between frames
- [x] Godot `SpriteFrames` `.tres` + `sheet.png`: one animation per tag (or "default"), `AtlasTexture` regions, speed = 1000 / shortest frame, per-frame durations relative to it, loop on; must be saved inside a Godot project (res:// path from the nearest `project.godot`)
- [x] GIF encoder (LZW, global palette, per-frame delays without rounding drift, transparency index, loop forever); validated by an independent reader and by macOS `sips`
- [x] GIF / PNG-sequence cycling bake (LCM of periods, 500-frame cap, predicted frame-count warning); GIF frames carry local color tables (Risk 5)
- [x] Export compositing (layers, visibility, offsets, opacity) shared by all exporters: `FrameCompositor`; `FrameSchedule` gives play order + bake schedule

**Exit:** round-trip tests pass; generated `SpriteFrames` opens in Godot 4.7 and every tag plays correctly on an `AnimatedSprite2D`. ✅ `sprite_frames_godot_test.gd` exports into a scratch Godot project, imports it with a second Godot process and plays every tag at a fixed 60 fps; 316 tests, API coverage 100 %.

---

## M7 — Polish & playtest (2 weeks)

### Preferences (§7.13)
- [x] `ConfigFile` at `user://settings.cfg`: theme (dark/light), checkerboard colors, onion tints, autosave interval (0 = off), UI scale, key preset — Project → Preferences…
- [x] Light theme (built in code by `PrismTheme`, like the dark one; switching rebuilds the window, the document stays)
- [x] Key binding overrides in `user://keybindings.json` (`"action": ["Shift+V", …]`), applied at startup; Help → Edit key bindings file… writes a template
- [x] "Classic" (DPaint: 1/2 frames, `.` restore brush, V line) vs "Modern" key presets (Risk 3); default to be decided by the playtest

### Polish
- [x] Menu bar fully wired: Project, Edit, Picture, Brush, Mode, Anim, Effect (flip/rotate cel, outline, replace color), View + Help (shortcuts list, key bindings file, About/credits); menu items show their shortcuts
- [x] Keyboard map review: `.` conflict resolved per preset (Modern: `.` next frame, Shift+B restore brush; Classic: `.` restore brush, 1/2 frames); a test checks no preset binds one key twice
- [x] Tooltips with shortcuts (toolbox, timeline, panels), empty states (no cycles / ramps / locks, onion with no neighbors), error dialogs for every file and export failure
- [x] Performance benchmarks vs §9.4 budgets (`bench/budgets_bench.gd`): stroke 0.5 ms, undo 8 ms, playback ≥ 205 fps ✅; worst-case flood fill 50–53 ms ❌ by ≤ 7 % — open decision in [ADR 0003](docs/adr/0003-cpu-hot-paths.md)
- [x] 2-hour soak test (`bench/soak.gd`, `PRISM_SOAK_MINUTES`): random commands + background autosave + save/reload + undo/redo-all, with a fingerprint diff on failure. Found and fixed: palette colors are now stored as exact 8-bit RGB (were losing precision on save)

### Playtest
- [ ] Sessions with 3–5 artists (DPaint veteran, Aseprite user, game dev) running the §13 task script — kit ready: [docs/playtest/PLAYTEST.md](docs/playtest/PLAYTEST.md)
- [ ] Collect "feels like DPaint" / "feels like a modern sprite tool" ratings (target ≥ 4/5)
- [ ] Triage findings into the P1 backlog

**Exit:** all §13 success criteria met; prioritized post-prototype backlog.

---

## Post-prototype backlog (ordered, §10)

0. [ ] Decide flood fill worst case: accept, or GDExtension `RasterBackend` (ADR 0003 M7 update)
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

## Future: GitHub CI (deferred)

Not part of the prototype milestones; set up once the repository is on GitHub. Until then, run tests locally (see `README.md`).

- [ ] GitHub Actions: download pinned Godot 4.7.2, run gdUnit4 suites headless on every push
- [ ] GitHub Actions: render tests on Linux with a virtual display (`--rendering-driver opengl3`) (§11)
- [ ] Nightly export builds for the three desktop presets
- [ ] Log performance benchmarks per run

---

## Palette editing follow-ups

- [ ] Add and remove palette colors in the editor ("+" / "−" on the palette, undoable). Removing a color
      that pixels use must not silently change the picture: ask which color to remap those pixels to (or
      block removal while the color is in use). Keep ramps, cycles, stencil, FG/BG and the transparent
      index consistent when indices shift. Limits: 1–256 entries.
- [ ] "New palette…" with N blank entries or a gradient between two colors.
- [ ] Preference: default palette for new documents (instead of PRISM 32).

---

## Open questions to resolve (§12)

- [ ] Q1 — Shade mode at ramp ends: clamp (default) or wrap? (both implemented, toggle in the Ramps section; confirm the default in playtests)
- [ ] Q2 — `.aseprite` import worth the licensing review pre-1.0?
- [x] Q3 — Compatibility vs Forward+ as shipped default → Compatibility (ADR 0006)
- [ ] Q4 — Fixed layout vs dockable panels (fixed for prototype)
