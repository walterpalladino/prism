## Shared parts of inserting and removing palette entries (GDD §7.4). Entries above the edit
## point shift by one, and everything that stores a palette index — pixels, the transparent
## index, the stencil, ramps and cycles — shifts with them, so the picture is unchanged.
## Revert restores a snapshot of the non-pixel state; subclasses undo the pixel shift.
@abstract
class_name PaletteResizeCommand
extends Command

var _palette_before: Palette
var _cycles_before: Array[CycleRange] = []
var _stencil_before: PackedByteArray
var _transparent_before: int


func changes_palette() -> bool:
	return true


## new_value[old] after inserting (delta +1) or removing (delta -1) entry `at`. On removal,
## `at` maps to itself; the caller decides where its pixels go.
static func shift_table(at: int, delta: int) -> PackedByteArray:
	var table: PackedByteArray = PackedByteArray()
	var resize_error: int = table.resize(256)
	assert(resize_error == OK)
	for v: int in 256:
		if delta > 0:
			table[v] = mini(v + 1, 255) if v >= at else v
		else:
			table[v] = v - 1 if v > at else v
	return table


## An inclusive [start, end] span after inserting (delta +1) or removing (delta -1) entry `at`.
## An entry inserted inside the span grows it. Returns Palette.NO_RAMP when fewer than two
## entries are left.
static func shift_span(span: Vector2i, at: int, delta: int) -> Vector2i:
	var start: int = span.x
	var end: int = span.y
	if delta > 0:
		if at <= start:
			start += 1
			end += 1
		elif at <= end:
			end += 1
	else:
		if at < start:
			start -= 1
			end -= 1
		elif at <= end:
			end -= 1
	return Vector2i(start, end) if start < end else Palette.NO_RAMP


## The 256 stencil flags after inserting (unlocked) or removing entry `at`.
static func shift_locks(locked: PackedByteArray, at: int, delta: int) -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	var resize_error: int = result.resize(locked.size())
	assert(resize_error == OK)
	for i: int in locked.size():
		if i < at:
			result[i] = locked[i]
		elif delta > 0 and i + 1 < locked.size():
			result[i + 1] = locked[i]
		elif delta < 0 and i > at:
			result[i - 1] = locked[i]
	return result


func _save(doc: PrismDocument) -> void:
	_palette_before = doc.palette.duplicate_palette()
	_cycles_before.clear()
	for cycle: CycleRange in doc.cycles:
		_cycles_before.append(cycle.duplicate_cycle())
	_stencil_before = doc.stencil.locked.duplicate()
	_transparent_before = doc.transparent_index


func _restore(doc: PrismDocument) -> void:
	doc.palette.colors = _palette_before.colors.duplicate()
	doc.palette.ramps = _palette_before.ramps.duplicate()
	var cycles: Array[CycleRange] = []
	for cycle: CycleRange in _cycles_before:
		cycles.append(cycle.duplicate_cycle())
	doc.cycles = cycles
	doc.stencil.locked = _stencil_before.duplicate()
	doc.transparent_index = _transparent_before


## Shifts ramps, cycles, stencil and transparent index; a ramp or cycle left with fewer than
## two entries is dropped.
func _shift_references(doc: PrismDocument, at: int, delta: int, table: PackedByteArray) -> void:
	var ramps: Array[Vector2i] = []
	for ramp: Vector2i in doc.palette.ramps:
		var shifted: Vector2i = shift_span(ramp, at, delta)
		if shifted != Palette.NO_RAMP:
			ramps.append(shifted)
	doc.palette.ramps = ramps
	var cycles: Array[CycleRange] = []
	for cycle: CycleRange in doc.cycles:
		var span: Vector2i = shift_span(Vector2i(cycle.start_index, cycle.end_index), at, delta)
		if span != Palette.NO_RAMP:
			var copy: CycleRange = cycle.duplicate_cycle()
			copy.start_index = span.x
			copy.end_index = span.y
			cycles.append(copy)
	doc.cycles = cycles
	doc.stencil.locked = shift_locks(doc.stencil.locked, at, delta)
	doc.transparent_index = table[doc.transparent_index]


static func _remap_pixels(doc: PrismDocument, table: PackedByteArray) -> void:
	for image: IndexedImage in doc.images.values():
		var px: PackedByteArray = image.pixels
		for i: int in px.size():
			px[i] = table[px[i]]


func get_byte_size() -> int:
	if _palette_before == null:
		return 64
	return 64 +_palette_before.size() * 16 + 32 * _cycles_before.size() + 256
