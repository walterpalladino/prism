# 0006 — Compatibility renderer

**Status:** Accepted · **Answers:** GDD Q3 · **Date:** 2026-10-19

## Measurements
- Frame time for 4 layers 512² @ 4×: Compatibility 1.25 ms, Forward+ 3.23 ms (ADR 0001).
- Startup to first frame (3 runs): Compatibility 0.81–0.90 s, Forward+ 0.71–1.10 s. No meaningful difference.
- The LUT shader renders identically on both.

## Decision
Ship with **Compatibility** (`gl_compatibility`; on this Mac the driver reported "OpenGL API 4.1 Metal"). It is faster for this
2D workload, runs on older GPUs and keeps the web-export path open. Forward+ offers nothing the editor needs.
