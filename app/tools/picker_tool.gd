## Picker (`I`, or hold Alt with any tool): primary button picks FG, secondary picks BG,
## from the topmost visible layer at the cursor.
class_name PickerTool
extends Tool

var _button: PrismEnums.PaintButton


func get_id() -> StringName:
	return &"picker"


func begin(pos: Vector2i, button: PrismEnums.PaintButton, _mods: int) -> void:
	_button = button
	_pick(pos)


func drag(pos: Vector2i, _mods: int) -> void:
	_pick(pos)


func _pick(pos: Vector2i) -> void:
	if not Rect2i(Vector2i.ZERO, Vector2i(bus.document.width, bus.document.height)).has_point(pos):
		return
	var index: int = state.index_at(pos)
	if _button == PrismEnums.PaintButton.PRIMARY:
		state.set_fg(index)
	else:
		state.set_bg(index)
