# 0005 — Packed arrays are shared by reference

**Status:** Accepted · **Date:** 2026-10-19

## Context
GDD §6.2 and risk 1c describe `PackedByteArray` as copy-on-write and warn about hidden full-buffer copies.

## Finding
Verified on 4.7.2: assigning a packed array to another variable, or passing it as an argument, **shares**
the buffer. Writing through the alias changes the original:

```gdscript
var local: PackedByteArray = image.pixels
local[0] = 7   # image.pixels[0] is now 7
```

## Decision
- Hot loops may take a local alias (`var px: PackedByteArray = image.pixels`) and write through it.
  This is fast and has no hidden copy.
- Any code that needs an independent copy (undo snapshots, duplicated or unlinked cels, autosave snapshots)
  must call `duplicate()` explicitly. Model classes provide `duplicate_*()` helpers that do this.
- Risk 1c changes from "hidden copies" to "accidental sharing". Tests for every `duplicate_*()` check independence.
