## Swatch grid of the document palette (GDD §7.4, §7.5, concept C1).
## LMB sets FG, RMB sets BG (DPaint heritage). Double-click opens the color editor.
## Ctrl+click toggles the stencil lock.
## Drag a swatch to reorder: pixels follow their color (remap); Shift+drag keeps pixel indices.
## FG is outlined in orange, BG in blue; locked entries get an orange underline, shading
## ramps a blue bar above their span and color-cycle ranges a teal bracket below (C1).
class_name PaletteGrid
extends Control

## A swatch was double-clicked: open the editor for that entry.
signal edit_requested(index: int)

const COLUMNS: int = 8
const SWATCH: int = 20
## Below each swatch: lock underline (2 px), cycle bracket (3 px); above: ramp bar.
const GAP: int = 9
const DRAG_THRESHOLD: float = 4.0
## Room for the 2 px FG/BG outlines around edge swatches.
const MARGIN: int = 2

var _state: EditorState
var _actions: PaletteActions
var _press_index: int = -1
var _press_pos: Vector2
var _dragging: bool = false
var _drop_index: int = -1


func setup(state: EditorState, actions: PaletteActions) -> void:
	_state = state
	_actions = actions
	Signals.on(_state.changed, queue_redraw)
	Signals.on(_state.bus.palette_changed, _resize_to_palette)
	Signals.on(_state.bus.document_replaced, _resize_to_palette)
	_resize_to_palette()


func _resize_to_palette() -> void:
	var rows: int = ceili(_state.palette_size() / float(COLUMNS))
	custom_minimum_size = Vector2(COLUMNS * (SWATCH + GAP) + MARGIN, rows * (SWATCH + GAP) + GAP)
	queue_redraw()


func index_at(local: Vector2) -> int:
	var cell: Vector2i = Vector2i(((local - Vector2(MARGIN, GAP)) / (SWATCH + GAP)).floor())
	if cell.x < 0 or cell.x >= COLUMNS or cell.y < 0:
		return -1
	var index: int = cell.y * COLUMNS + cell.x
	return index if index < _state.palette_size() else -1


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null:
		_handle_button(button)
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _press_index != -1:
		if not _dragging and motion.position.distance_to(_press_pos) > DRAG_THRESHOLD:
			_dragging = true
		if _dragging:
			_drop_index = index_at(motion.position)
			queue_redraw()
		accept_event()


func _handle_button(button: InputEventMouseButton) -> void:
	var index: int = index_at(button.position)
	if button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
		if _dragging and _drop_index != -1:
			_actions.reorder(_press_index, _drop_index, not button.shift_pressed)
		_press_index = -1
		_dragging = false
		_drop_index = -1
		queue_redraw()
		accept_event()
		return
	if not button.pressed or index == -1:
		return
	if button.button_index == MOUSE_BUTTON_LEFT and button.double_click:
		_press_index = -1
		edit_requested.emit(index)
	elif button.button_index == MOUSE_BUTTON_LEFT and button.is_command_or_control_pressed():
		_actions.toggle_lock(index)
	elif button.button_index == MOUSE_BUTTON_LEFT:
		_state.set_fg(index)
		_press_index = index
		_press_pos = button.position
	elif button.button_index == MOUSE_BUTTON_RIGHT:
		_state.set_bg(index)
	accept_event()


func _get_tooltip(at_position: Vector2) -> String:
	var index: int = index_at(at_position)
	if index == -1:
		return ""
	var doc: PrismDocument = _state.bus.document
	var lines: PackedStringArray = ["%d  #%s" % [index, doc.palette.get_color(index).to_html(false)]]
	if doc.stencil.is_locked(index):
		lines.append_array(["Locked by stencil"])
	for cycle: CycleRange in doc.cycles:
		if cycle.contains(index):
			lines.append_array(["Cycle %d–%d at %s steps/s%s" % [cycle.start_index, cycle.end_index, String.num(cycle.rate_hz, 2), "" if cycle.active else " (off)"]])
	var ramp: Vector2i = doc.palette.find_ramp(index)
	if ramp != Palette.NO_RAMP:
		lines.append_array(["Ramp %d–%d" % [ramp.x, ramp.y]])
	if index == doc.transparent_index:
		lines.append_array(["Transparent"])
	lines.append_array(["LMB FG · RMB BG · double-click to edit · Ctrl+click lock · drag to reorder (Shift: keep pixel indices)"])
	return "\n".join(lines)


func _draw() -> void:
	if _state == null:
		return
	var doc: PrismDocument = _state.bus.document
	var palette: Palette = doc.palette
	for i: int in palette.size():
		var rect: Rect2 = swatch_rect(i)
		draw_rect(rect, palette.get_color(i))
		draw_rect(rect, PrismTheme.BORDER, false, 1.0)
	for ramp: Vector2i in palette.ramps:
		for i: int in range(ramp.x, ramp.y + 1):
			var rect: Rect2 = swatch_rect(i)
			var extend: float = float(GAP) if i != ramp.y and (i + 1) % COLUMNS != 0 else 0.0
			draw_rect(Rect2(rect.position - Vector2(0, 3), Vector2(SWATCH + extend, 2)), PrismTheme.BLUE)
	for cycle: CycleRange in doc.cycles:
		var color: Color = PrismTheme.CYCLE if cycle.active else PrismTheme.DIM
		for i: int in range(cycle.start_index, mini(cycle.end_index + 1, palette.size())):
			var cell: Rect2 = swatch_rect(i)
			var joins_next: bool = i != cycle.end_index and (i + 1) % COLUMNS != 0
			var y: float = cell.position.y + SWATCH + 4.0
			draw_rect(Rect2(cell.position.x, y, SWATCH + (float(GAP) if joins_next else 0.0), 2), color)
			if i == cycle.start_index:
				draw_rect(Rect2(cell.position.x, y - 3.0, 2, 3), color)
			if i == cycle.end_index:
				draw_rect(Rect2(cell.end.x - 2.0, y - 3.0, 2, 3), color)
	for i: int in palette.size():
		if doc.stencil.is_locked(i):
			var locked_rect: Rect2 = swatch_rect(i)
			draw_rect(Rect2(locked_rect.position + Vector2(0, SWATCH), Vector2(SWATCH, 2)), PrismTheme.ORANGE)
	draw_rect(swatch_rect(_state.bg).grow(1), PrismTheme.BLUE, false, 2.0)
	draw_rect(swatch_rect(_state.fg).grow(1), PrismTheme.ORANGE, false, 2.0)
	if _dragging and _drop_index != -1:
		var target: Rect2 = swatch_rect(_drop_index)
		draw_rect(Rect2(target.position - Vector2(3, 0), Vector2(2, SWATCH)), Color.WHITE)


func swatch_rect(index: int) -> Rect2:
	var column: int = index % COLUMNS
	var row: int = floori(index / float(COLUMNS))
	return Rect2(Vector2(MARGIN + column * (SWATCH + GAP), GAP + row * (SWATCH + GAP)), Vector2(SWATCH, SWATCH))
