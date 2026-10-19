## Which frame shows when, for exporting animations (GDD §7.6, §7.12).
##
## A schedule is a list of Vector3i(frame_index, start_ms, duration_ms). Without cycling it is
## one loop of the play order. With cycling baked in, frames are split wherever a cycle steps,
## and the schedule covers the least common multiple of the animation loop and the cycle loop,
## capped at `max_frames` (GDD risk 5).
class_name FrameSchedule
extends RefCounted

const DEFAULT_MAX_FRAMES: int = 500


## One loop of frame indices for a range and direction. Ping-pong does not repeat the ends.
static func play_order(frame_range: Vector2i, direction: PrismEnums.TagDirection) -> PackedInt32Array:
	var order: PackedInt32Array = PackedInt32Array()
	match direction:
		PrismEnums.TagDirection.REVERSE:
			for i: int in range(frame_range.y, frame_range.x - 1, -1):
				@warning_ignore("return_value_discarded")
				order.append(i)
		PrismEnums.TagDirection.PING_PONG:
			for i: int in range(frame_range.x, frame_range.y + 1):
				@warning_ignore("return_value_discarded")
				order.append(i)
			for i: int in range(frame_range.y - 1, frame_range.x, -1):
				@warning_ignore("return_value_discarded")
				order.append(i)
		_:
			for i: int in range(frame_range.x, frame_range.y + 1):
				@warning_ignore("return_value_discarded")
				order.append(i)
	return order


static func loop_ms(doc: PrismDocument, order: PackedInt32Array) -> int:
	var total: int = 0
	for index: int in order:
		total += doc.frames[index].duration_ms
	return total


## The schedule for `order`; see the class comment.
static func build(doc: PrismDocument, order: PackedInt32Array, bake_cycles: bool, max_frames: int = DEFAULT_MAX_FRAMES) -> Array[Vector3i]:
	var entries: Array[Vector3i] = []
	var anim_ms: int = loop_ms(doc, order)
	var cycle_ms: int = roundi(ColorCycler.loop_seconds(doc.cycles) * 1000.0)
	if not bake_cycles or cycle_ms == 0 or order.is_empty():
		var start: int = 0
		for index: int in order:
			if entries.size() >= max_frames:
				break
			entries.append(Vector3i(index, start, doc.frames[index].duration_ms))
			start += doc.frames[index].duration_ms
		return entries
	var total_ms: int = _lcm(anim_ms, cycle_ms)
	var changes: PackedInt32Array = _change_points(doc, order, anim_ms, total_ms, max_frames)
	for i: int in changes.size():
		var start_ms: int = changes[i]
		var end_ms: int = changes[i + 1] if i + 1 < changes.size() else total_ms
		if entries.size() >= max_frames or end_ms <= start_ms:
			break
		entries.append(Vector3i(frame_at(doc, order, start_ms % anim_ms), start_ms, end_ms - start_ms))
	return entries


## Frames a bake would produce if it were not capped (to warn before exporting).
static func predicted_count(doc: PrismDocument, order: PackedInt32Array, bake_cycles: bool) -> int:
	return build(doc, order, bake_cycles, 1 << 20).size()


## Index of the frame showing `ms` into one loop of `order`.
static func frame_at(doc: PrismDocument, order: PackedInt32Array, ms: int) -> int:
	var t: int = 0
	for index: int in order:
		t += doc.frames[index].duration_ms
		if ms < t:
			return index
	return order[order.size() - 1]


static func _change_points(doc: PrismDocument, order: PackedInt32Array, anim_ms: int, total_ms: int, cap: int) -> PackedInt32Array:
	var points: Dictionary[int, bool] = {0: true}
	@warning_ignore("integer_division")
	var loops: int = total_ms / anim_ms
	var t: int = 0
	for _loop: int in loops:
		for index: int in order:
			points[t] = true
			t += doc.frames[index].duration_ms
			if points.size() > cap * 2:
				break
	for cycle: CycleRange in doc.cycles:
		if not cycle.active or cycle.rate_hz <= 0.0 or cycle.length() < 2:
			continue
		var k: int = 0
		while points.size() <= cap * 2:
			var ms: int = roundi(k * 1000.0 / cycle.rate_hz)
			if ms >= total_ms:
				break
			points[ms] = true
			k += 1
	var sorted: Array[int] = points.keys()
	sorted.sort()
	var result: PackedInt32Array = PackedInt32Array()
	for ms: int in sorted:
		if ms < total_ms:
			@warning_ignore("return_value_discarded")
			result.append(ms)
	return result


static func _lcm(a: int, b: int) -> int:
	var x: int = a
	var y: int = b
	while y != 0:
		var r: int = x % y
		x = y
		y = r
	@warning_ignore("integer_division")
	return a / maxi(x, 1) * b
