## Swatch grid of the document palette. LMB sets FG, RMB sets BG (DPaint heritage).
## FG is outlined in orange, BG in blue. Full palette editing arrives in M3.
class_name PaletteGrid
extends Control

const COLUMNS: int = 8
const SWATCH: int = 22
const GAP: int = 2

var _state: EditorState


func setup(state: EditorState) -> void:
	_state = state
	Signals.on(_state.changed, queue_redraw)
	Signals.on(_state.bus.document_replaced, _resize_to_palette)
	_resize_to_palette()


func _resize_to_palette() -> void:
	var rows: int = ceili(_state.palette_size() / float(COLUMNS))
	custom_minimum_size = Vector2(COLUMNS * (SWATCH + GAP), rows * (SWATCH + GAP))
	queue_redraw()


func index_at(local: Vector2) -> int:
	var cell: Vector2i = Vector2i((local / (SWATCH + GAP)).floor())
	if cell.x < 0 or cell.x >= COLUMNS or cell.y < 0:
		return -1
	var index: int = cell.y * COLUMNS + cell.x
	return index if index < _state.palette_size() else -1


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	var index: int = index_at(button.position)
	if index == -1:
		return
	if button.button_index == MOUSE_BUTTON_LEFT:
		_state.set_fg(index)
	elif button.button_index == MOUSE_BUTTON_RIGHT:
		_state.set_bg(index)
	accept_event()


func _get_tooltip(at_position: Vector2) -> String:
	var index: int = index_at(at_position)
	if index == -1:
		return ""
	return "%d  #%s" % [index, _state.bus.document.palette.get_color(index).to_html(false)]


func _draw() -> void:
	if _state == null:
		return
	var palette: Palette = _state.bus.document.palette
	for i: int in palette.size():
		var rect: Rect2 = _swatch_rect(i)
		draw_rect(rect, palette.get_color(i))
		draw_rect(rect, PrismTheme.BORDER, false, 1.0)
	draw_rect(_swatch_rect(_state.bg).grow(1), PrismTheme.BLUE, false, 2.0)
	draw_rect(_swatch_rect(_state.fg).grow(1), PrismTheme.ORANGE, false, 2.0)


func _swatch_rect(index: int) -> Rect2:
	return Rect2(Vector2((index % COLUMNS) * (SWATCH + GAP), floori(index / float(COLUMNS)) * (SWATCH + GAP)), Vector2(SWATCH, SWATCH))
