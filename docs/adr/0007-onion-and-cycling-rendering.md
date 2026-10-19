# 0007 — Onion skin and color-cycling rendering

**Status:** Accepted · **Milestone:** M5 · **Date:** 2026-10-19

## Decisions
- **Color cycling rotates the palette LUT, never pixels.** `ColorCycler` computes the displayed colors for a
  time `t`; `ColorCycling` (app) runs the clock while any requester is active (Tab preview, timeline playback,
  preview-window playback) and emits only when a cycle actually steps. `PaletteDisplay` (infra) is the single
  writer of the shared 256×1 LUT texture: cycled colors while cycling runs, the document palette otherwise.
- **Onion skin = extra tinted `CelStack`s**, sharing the cel textures (no extra uploads). They are drawn
  **in front** of the current frame by default (translucent), because behind it they vanish whenever the
  current frame is opaque or identical (e.g. right after Duplicate frame) — reported as "onion not working".
  A "Front" option draws them behind instead. The LUT shader's `tint` is `rgb` + mix strength in `a`; opacity falls off linearly with distance.
  Hidden during playback; rebuilt only when the onion settings or frame list change.

## Measurements (`bench/onion_bench.gd`, Apple M1, Compatibility, vsync off)

| Scene | Frame time |
|---|---|
| 256×256, 4 layers, 8 frames, onion 3 past / 2 future (5 extra stacks = 20 sprites) + cycling every step | 4.32 ms (231 fps) |

Budget: ≥ 60 fps (≤ 16.7 ms). Met with ~4× headroom.

## Consequences
- Render goldens (`tests/render/`) read back the real canvas; they need a window and wait for
  `RenderingServer.frame_post_draw` before capturing. A blank capture fails the test.
- Services that are `RefCounted` must connect signals with method callables, not lambdas using `self`:
  a lambda held by the bus keeps the service (and the bus) alive in a reference cycle.
