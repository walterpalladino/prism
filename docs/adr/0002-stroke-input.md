# 0002 — Stroke input

**Status:** Accepted; end-to-end latency to be checked by hand in M2 · **Spike:** B · **Date:** 2026-10-19

## Context
Budget: paint stroke latency < 8 ms at 512² (GDD §9.4). Plan: `Input.use_accumulated_input = false`
while a stroke is active, Bresenham interpolation between motion events.

## Findings
- APIs exist in 4.7.2: `Input.use_accumulated_input` (default `true`), `InputEventMouseMotion.pressure`,
  `.tilt`, `.pen_inverted`.
- CPU cost per motion event (`bench/cpu_bench.gd`), a 16 px segment on a 512² cel:

  | Brush | Cost |
  |---|---|
  | round 1 | 0.03 ms |
  | round 4 | 0.15 ms |
  | round 8 | 0.56 ms |

  Plus `Painter.new` once per stroke (0.01 ms) and the texture upload (0.15 ms, ADR 0001).
- Worst realistic CPU total per event: ~0.7 ms, about 10× under budget.

## Decision
Adopt the GDD plan. Toggle `use_accumulated_input` off on stroke start and back on at stroke end.
One `Painter` per stroke; it guarantees each pixel changes at most once per stroke.

## Open
True input-to-photon latency depends on the OS and display and cannot be measured in a script.
Check by hand in M2 (fast circular strokes at 800% zoom; ghost brush must not trail the cursor).
