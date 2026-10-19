## Move cel (`V`): drags the current cel's offset; one MoveCelCommand on release.
class_name MoveCelTool
extends Tool

var _cel: Cel
var _start_pos: Vector2i
var _start_offset: Vector2i


func get_id() -> StringName:
	return &"move"


func begin(pos: Vector2i, _button: PrismEnums.PaintButton, _mods: int) -> void:
	if state.editable_image() == null:
		return
	_cel = state.current_cel()
	_start_pos = pos
	_start_offset = _cel.offset


func drag(pos: Vector2i, _mods: int) -> void:
	if _cel == null:
		return
	_cel.offset = _start_offset + pos - _start_pos
	bus.notify_document_changed()


func end(pos: Vector2i, mods: int) -> void:
	if _cel == null:
		return
	drag(pos, mods)
	if _cel.offset != _start_offset:
		bus.record(MoveCelCommand.new(state.current_cel_key(), _start_offset, _cel.offset))
	_cel = null


func cancel() -> void:
	if _cel == null:
		return
	_cel.offset = _start_offset
	bus.notify_document_changed()
	_cel = null
