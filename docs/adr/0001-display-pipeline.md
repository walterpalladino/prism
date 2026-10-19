# 0001 — Display pipeline

**Status:** Accepted · **Spike:** A · **Date:** 2026-10-19

## Context
GDD §9.4 plans one `FORMAT_R8` `ImageTexture` per cel, colored by a shared 256×1 palette texture in
`palette_lut.gdshader`. `ImageTexture.update()` re-uploads the whole texture, so the GDD proposed 64×64
tiles for canvases above 256×256 if uploads proved too slow.

## Measurements
`bench/display_bench.gd` (window, vsync off) and `bench/lut_check.gd`:

| Measurement | Compatibility | Forward+ |
|---|---|---|
| `set_data` + `update` 256² R8 | 0.04 ms | 0.01 ms |
| `set_data` + `update` 512² R8 | 0.15 ms | 0.04 ms |
| `set_data` + `update` 1024² R8 | 0.61 ms | 0.18 ms |
| Frame, 4 layers 512² @ 4× zoom | 1.25 ms (797 fps) | 3.23 ms (310 fps) |
| Frame + full 512² upload every frame | 1.36 ms (735 fps) | 3.01 ms |
| Frame + one 64² tile upload every frame | 1.07 ms (934 fps) | 3.08 ms |

`lut_check.gd` reads the framebuffer back: indices 1, 9, 27, 31 render their exact palette colors and the
transparent index is discarded, on both renderers.

## Decision
- Use the GDD pipeline as written: R8 index texture per cel + shared palette LUT shader.
- **No texture tiling in the prototype.** A full 512² upload costs ~0.15 ms of CPU, roughly 50× under the
  8 ms stroke budget. Upload at most once per rendered frame, after the stroke has written its pixels.
- The tile size, if tiling is ever needed (canvases > 1024² or slow GPUs), is 64×64.

## Consequences
- `CanvasView` (M2) stays simple: one `Sprite2D` per visible cel.
- Revisit if the canvas limit (`PrismDocument.MAX_CANVAS_SIZE`, 512) is raised.
