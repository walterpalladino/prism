# 0004 — Test coverage measurement

**Status:** Accepted · **Spike:** D · **Date:** 2026-10-19

## Context
GDD §11 asks for coverage reporting only if a reliable GDScript coverage tool works with 4.7.

## Findings
- gdUnit4 6.2.2 produces JUnit XML and HTML result reports but has no coverage feature.
- [jamie-pate/godot-code-coverage](https://github.com/jamie-pate/godot-code-coverage) targets Godot 3.5 and GUT.
  Its `godot4` branch was last updated in October 2023 ("Mostly fixed for Godot 4 … Blocked by" an engine issue).
  It instruments scripts by rewriting their source, which would also collide with the warnings-as-errors typing rules.
- No other maintained tool was found.

## Decision
- No line-coverage tooling.
- `tools/api_coverage.py` reports every public function in `core/`, `app/` and `infra/` that no test calls.
  The target is 100 %; run it before ticking a TODO item. `--strict` exits 1 on gaps, for future CI.
- Per-module checklist reviewed at each milestone exit: every public function tested, every command has an
  apply/revert test, every codec has round-trip + malformed-input tests, golden files reviewed by eye.

## Revisit when
gdUnit4 or the engine gains coverage support.
