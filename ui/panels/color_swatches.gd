## FG/BG swatch block under the toolbox: FG front-left, BG behind to the bottom-right.
class_name ColorSwatches
extends Control

const SIZE: float = 30.0
const OFFSET: float = 14.0

var _state: EditorState


func setup(state: EditorState) -> void:
	_state = state
	custom_minimum_size = Vector2(SIZE + OFFSET, SIZE + OFFSET)
	Signals.on(_state.changed, queue_redraw)
	Signals.on(_state.bus.document_replaced, queue_redraw)
	Signals.on(_state.bus.palette_changed, queue_redraw)


func _get_tooltip(_at_position: Vector2) -> String:
	return "FG %d · BG %d   ([ ] and { } step)" % [_state.fg, _state.bg]


func _draw() -> void:
	if _state == null:
		return
	var palette: Palette = _state.bus.document.palette
	var bg_rect: Rect2 = Rect2(Vector2(OFFSET, OFFSET), Vector2(SIZE, SIZE))
	var fg_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(SIZE, SIZE))
	draw_rect(bg_rect, palette.get_color(_state.bg))
	draw_rect(bg_rect, Color.WHITE, false, 1.0)
	draw_rect(fg_rect, palette.get_color(_state.fg))
	draw_rect(fg_rect, Color.WHITE, false, 1.0)
