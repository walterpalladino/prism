## Runs color cycling over time (GDD §7.6). Cycling shows while anything requests it: the
## Tab preview, timeline playback or the preview window's playback. Pure: advance() takes
## elapsed time; colors_changed fires only when a cycle actually steps.
class_name ColorCycling
extends RefCounted

## Displayed palette colors changed (cycled, or back to the real palette when stopping).
signal colors_changed(colors: PackedColorArray)
signal running_changed(running: bool)

var bus: CommandBus
var time_s: float = 0.0

var _requests: Dictionary[StringName, bool] = {}
var _offsets: PackedInt32Array = PackedInt32Array()


func _init(p_bus: CommandBus) -> void:
	bus = p_bus
	# Method callables, not lambdas: a lambda that uses self would keep this service and the
	# bus alive in a reference cycle.
	Signals.on(bus.palette_changed, _refresh)
	Signals.on(bus.document_replaced, _on_document_replaced)


## Turns one requester on or off (e.g. &"tab", &"playback", &"preview").
func request(source: StringName, on: bool) -> void:
	var was_running: bool = is_running()
	if on:
		_requests[source] = true
	else:
		var _erased: bool = _requests.erase(source)
	if was_running != is_running():
		running_changed.emit(is_running())
		_refresh()


func is_requested(source: StringName) -> bool:
	return _requests.has(source)


func toggle(source: StringName) -> void:
	request(source, not is_requested(source))


func is_running() -> bool:
	return not _requests.is_empty()


func advance(delta_s: float) -> void:
	if not is_running() or bus.document.cycles.is_empty():
		return
	time_s += delta_s
	var offsets: PackedInt32Array = ColorCycler.offsets_at(bus.document.cycles, time_s)
	if offsets != _offsets:
		_offsets = offsets
		colors_changed.emit(current_colors())


## What the palette looks like right now.
func current_colors() -> PackedColorArray:
	var doc: PrismDocument = bus.document
	if not is_running():
		return doc.palette.colors
	return ColorCycler.rotated_colors(doc.palette.colors, doc.cycles, ColorCycler.offsets_at(doc.cycles, time_s))


func _on_document_replaced() -> void:
	var was_running: bool = is_running()
	_requests.clear()
	time_s = 0.0
	if was_running:
		running_changed.emit(false)
	_refresh()


func _refresh() -> void:
	_offsets = ColorCycler.offsets_at(bus.document.cycles, time_s) if is_running() else PackedInt32Array()
	colors_changed.emit(current_colors())
