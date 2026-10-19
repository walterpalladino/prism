## Palette color cycling (GDD §7.6, concept C3): animation by rotating palette slices.
## Pixels never change; only the colors their indices look up do.
##
## A forward cycle (step +1) moves each color one entry up per step, wrapping at the end of
## the range, so a waterfall painted dark-to-light "flows" toward higher indices.
class_name ColorCycler
extends RefCounted


## How many entries a cycle has rotated after `time_s` seconds (0 .. length-1).
static func offset_at(cycle: CycleRange, time_s: float) -> int:
	if not cycle.active or cycle.rate_hz <= 0.0 or cycle.length() < 2:
		return 0
	var steps: int = floori(time_s * cycle.rate_hz)
	return posmod(steps * cycle.step, cycle.length())


## Offsets of every cycle at `time_s`, in order (used to detect when colors actually change).
static func offsets_at(cycles: Array[CycleRange], time_s: float) -> PackedInt32Array:
	var offsets: PackedInt32Array = PackedInt32Array()
	var resize_error: int = offsets.resize(cycles.size())
	assert(resize_error == OK)
	for i: int in cycles.size():
		offsets[i] = offset_at(cycles[i], time_s)
	return offsets


## The palette colors as displayed at `time_s`.
static func cycled_colors(colors: PackedColorArray, cycles: Array[CycleRange], time_s: float) -> PackedColorArray:
	return rotated_colors(colors, cycles, offsets_at(cycles, time_s))


## The palette colors with each cycle rotated by its offset.
static func rotated_colors(colors: PackedColorArray, cycles: Array[CycleRange], offsets: PackedInt32Array) -> PackedColorArray:
	var result: PackedColorArray = colors.duplicate()
	for c: int in cycles.size():
		var cycle: CycleRange = cycles[c]
		var shift: int = offsets[c]
		if shift == 0 or cycle.end_index >= colors.size():
			continue
		var length: int = cycle.length()
		for k: int in length:
			result[cycle.start_index + (k + shift) % length] = colors[cycle.start_index + k]
	return result


## Seconds until every active cycle is back at its starting colors (the loop length for
## baking cycling into frames, M6). 0 if nothing cycles.
static func loop_seconds(cycles: Array[CycleRange]) -> float:
	var loop_steps: Array[float] = []
	for cycle: CycleRange in cycles:
		if cycle.active and cycle.rate_hz > 0.0 and cycle.length() >= 2:
			loop_steps.append(cycle.length() / cycle.rate_hz)
	if loop_steps.is_empty():
		return 0.0
	# Least common multiple of the periods, computed on a 1 ms grid.
	var result_ms: int = roundi(loop_steps[0] * 1000.0)
	for i: int in range(1, loop_steps.size()):
		var period_ms: int = roundi(loop_steps[i] * 1000.0)
		@warning_ignore("integer_division")
		result_ms = result_ms / _gcd(result_ms, period_ms) * period_ms
	return result_ms / 1000.0


static func _gcd(a: int, b: int) -> int:
	var x: int = a
	var y: int = b
	while y != 0:
		var t: int = x % y
		x = y
		y = t
	return maxi(x, 1)
