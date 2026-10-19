## Frame playback (GDD §7.8, §10 M4). Pure: call advance() with elapsed time; it never
## reads the clock. Time left over when a frame ends carries into the next frame instead of
## being dropped, so playback never drifts from the frame durations.
class_name Playback
extends RefCounted

signal frame_changed(index: int)
signal playing_changed(playing: bool)

var bus: CommandBus
var playing: bool = false
var frame: int = 0
## Inclusive frame range being played.
var play_range: Vector2i = Vector2i.ZERO
var direction: PrismEnums.TagDirection = PrismEnums.TagDirection.FORWARD

## Time spent on the current frame, in ms.
var _elapsed_ms: float = 0.0
## Ping-pong travel direction (+1 / -1).
var _step: int = 1


func _init(p_bus: CommandBus) -> void:
	bus = p_bus


## Range and direction to play from `frame_index`: the first tag containing it, else every frame forward.
static func scope_for(doc: PrismDocument, frame_index: int) -> Array:
	var tag_index: int = doc.tag_index_at(frame_index)
	if tag_index == -1:
		return [Vector2i(0, doc.frames.size() - 1), PrismEnums.TagDirection.FORWARD]
	var tag: Tag = doc.tags[tag_index]
	return [Vector2i(tag.from_frame, tag.to_frame), tag.direction]


## Starts playing the tag around `from_frame` (or the whole timeline).
func play_from(from_frame: int) -> void:
	var scope: Array = scope_for(bus.document, from_frame)
	var range_value: Vector2i = scope[0]
	var direction_value: PrismEnums.TagDirection = scope[1]
	play(range_value, direction_value, from_frame)


func play(p_range: Vector2i, p_direction: PrismEnums.TagDirection, start_frame: int) -> void:
	play_range = p_range
	direction = p_direction
	_step = -1 if direction == PrismEnums.TagDirection.REVERSE else 1
	var start: int = start_frame
	if start < play_range.x or start > play_range.y:
		start = play_range.y if direction == PrismEnums.TagDirection.REVERSE else play_range.x
	_elapsed_ms = 0.0
	_set_frame(start)
	if not playing:
		playing = true
		playing_changed.emit(true)


func stop() -> void:
	if playing:
		playing = false
		playing_changed.emit(false)


func toggle(from_frame: int) -> void:
	if playing:
		stop()
	else:
		play_from(from_frame)


## Advances playback by `delta_ms`, possibly across several frames.
func advance(delta_ms: float) -> void:
	if not playing:
		return
	var frames: Array[Frame] = bus.document.frames
	if frames.is_empty():
		stop()
		return
	_elapsed_ms += delta_ms
	var guard: int = 0
	while _elapsed_ms >= _duration(frame) and guard < 10000:
		_elapsed_ms -= _duration(frame)
		_set_frame(next_frame(frame))
		guard += 1


## Time already spent on the current frame (ms).
func elapsed_in_frame() -> float:
	return _elapsed_ms


## The frame after `current` for the current range and direction (updates ping-pong travel).
func next_frame(current: int) -> int:
	if play_range.x == play_range.y:
		return play_range.x
	match direction:
		PrismEnums.TagDirection.REVERSE:
			return play_range.y if current <= play_range.x else current - 1
		PrismEnums.TagDirection.PING_PONG:
			var candidate: int = current + _step
			if candidate > play_range.y or candidate < play_range.x:
				_step = -_step
				candidate = current + _step
			return candidate
	return play_range.x if current >= play_range.y else current + 1


func _duration(index: int) -> float:
	var frames: Array[Frame] = bus.document.frames
	return float(frames[clampi(index, 0, frames.size() - 1)].duration_ms)


func _set_frame(index: int) -> void:
	var clamped: int = clampi(index, 0, bus.document.frames.size() - 1)
	if clamped != frame:
		frame = clamped
		frame_changed.emit(frame)
	else:
		frame = clamped
