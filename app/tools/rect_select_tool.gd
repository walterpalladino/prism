## Rect select (`M`): drag a canvas-space selection. A click without dragging clears it.
class_name RectSelectTool
extends Tool

var _anchor: Vector2i
var _active: bool = false
var _before: Rect2i


func get_id() -> StringName:
	return &"select"


func begin(pos: Vector2i, _button: PrismEnums.PaintButton, _mods: int) -> void:
	_anchor = _clamp(pos)
	_before = state.selection
	_active = true
	state.set_selection(Rect2i())


func drag(pos: Vector2i, mods: int) -> void:
	if _active:
		state.set_selection(_rect_to(pos, mods))


func end(pos: Vector2i, mods: int) -> void:
	if not _active:
		return
	_active = false
	var rect: Rect2i = _rect_to(pos, mods)
	state.set_selection(rect if rect.size != Vector2i.ONE else Rect2i())


func cancel() -> void:
	if _active:
		_active = false
		state.set_selection(_before)


func _rect_to(pos: Vector2i, mods: int) -> Rect2i:
	var corner: Vector2i = _clamp(pos)
	if (mods & MOD_SHIFT) != 0:
		corner = _clamp(Tool.square_corner(_anchor, corner))
	return Tool.rect_from_corners(_anchor, corner)


func _clamp(pos: Vector2i) -> Vector2i:
	return pos.clamp(Vector2i.ZERO, Vector2i(bus.document.width - 1, bus.document.height - 1))
