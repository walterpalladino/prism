# 0003 — CPU hot paths stay in GDScript

**Status:** Accepted, with one open item (see *M7 update*) · **Spike:** C · **Date:** 2026-10-19

## Context
GDD §9.4 budgets: flood fill 512² < 50 ms; full-canvas undo < 16 ms. Spike C also times LZW-encoding
64 frames of 256² for GIF export. Escape hatch: `RasterBackend` (GDExtension-ready interface).

## Measurements (`bench/cpu_bench.gd`, median of 7)

| Operation | Time | Budget |
|---|---|---|
| Flood fill blank 512² (whole canvas) | 34 ms | 50 ms ✅ |
| Flood fill 512², 30 % noise walls | 49.7 ms | 50 ms ✅ (borderline) |
| Global replace 512² | 10 ms | — |
| `write_rect` 512² (full-canvas undo) | 8 ms | 16 ms ✅ |
| `read_rect` 512² | 10 ms | — |
| GIF LZW, 64 × 256² sprite-like frames | 307 ms | — |
| GIF LZW, 64 × 256² pure noise (worst case) | 991 ms | — |

What it took to get flood fill under budget, as lessons for every GDScript hot loop:
1. The first version allocated an `[y - 1, y + 1]` array per span and resized the stack on every pop: 65 ms.
2. Replacing `for … in range()` with `while` loops made it *slower* (68 ms). Typed `for … in range()` is the
   fastest loop form in GDScript 4.7.
3. A preallocated seed stack with a manual stack pointer, `for`-range loops, and the two neighbor-row scans
   written out inline (no helper call per run): 49.7 ms.

The GIF LZW string table is a flat `PackedInt32Array` of 4096 × 256 entries indexed by `prefix << 8 | byte`,
cleared with native `fill(0)` on table reset, instead of a `Dictionary`.

## Decision
- **No GDExtension for the prototype.** Every budget is met in GDScript on the reference machine.
- Flood fill and global replace go through `RasterBackend` (`GDScriptRasterBackend` today), so a C++
  backend can be dropped in without touching callers.
- GIF encoding runs on a `WorkerThreadPool` task in M6 with a progress indicator; one second for a
  worst-case 64-frame export is acceptable.

## Revisit when
- The noise-case flood fill misses 50 ms on a slower machine (it has ~0 % headroom on an M1), or
- the canvas limit rises above 512², or
- profiling in M7 shows `read_rect` / `write_rect` in stroke commit paths (row slicing could be optimized).

## M7 update — §9.4 budget review (`bench/budgets_bench.gd`)

| Budget | Measured | Result |
|---|---|---|
| Stroke < 8 ms (16 px drag, 8 px brush, 512², incl. texture upload) | 0.5 ms | ✅ |
| Full-canvas undo < 16 ms (512², incl. texture upload) | 8.0–8.4 ms | ✅ |
| Playback 60 fps (256² × 4 layers × 8 frames, onion 3/2 on) | 205–715 fps | ✅ |
| Flood fill 512² < 50 ms, worst case (30 % noise walls) | **50.2–53.3 ms** | ❌ by ≤ 7 % |
| Flood fill 512², whole blank canvas | 34 ms | ✅ |

Tried for the worst case and **rejected** (measured slower on noisy images, where ~100k tiny spans make
per-span overhead dominate):
- Skipping the parent span when scanning back (classic scanline optimization): 59–82 ms. It does help
  large open areas (blank 512²: 34 → 27 ms) but not the budget case.
- Replacing `mini()`/`maxi()` with plain comparisons: kept (cheaper), no measurable change.

**Open decision:** the worst case misses the budget by a few percent; real fills (sprite regions, open
areas) are well inside it. Options: accept for the prototype, or move `RasterBackend.flood_fill` to a
GDExtension (C++) implementation, which is the escape hatch this ADR planned. Listed in the
post-prototype backlog.
