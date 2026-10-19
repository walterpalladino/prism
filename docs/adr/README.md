# Architecture Decision Records

One file per decision: context, measurements, decision, consequences. Numbered in order; never renumber.
Superseding a decision means adding a new ADR and marking the old one *Superseded by NNNN*.

| # | Title | Status |
|---|---|---|
| [0001](0001-display-pipeline.md) | Display pipeline: R8 index textures + palette LUT, no tiling for ≤ 512² | Accepted |
| [0002](0002-stroke-input.md) | Stroke input: unaccumulated events + Bresenham, CPU cost per event | Accepted (manual latency check in M2) |
| [0003](0003-cpu-hot-paths.md) | CPU hot paths stay in GDScript for the prototype | Accepted |
| [0004](0004-test-coverage.md) | No line coverage; API-level coverage script + checklist | Accepted |
| [0005](0005-packed-array-semantics.md) | Packed arrays are shared by reference in Godot 4.7 | Accepted |
| [0006](0006-renderer.md) | Compatibility renderer is the shipped default (GDD Q3) | Accepted |

All measurements: Godot 4.7.2-stable, Apple M1 (macOS), 2026-10-19. Re-run the scripts in `bench/` on other machines and append results.
