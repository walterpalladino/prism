## Bottom status line (GDD §8.1): cursor, index + hex under the cursor, zoom, tool, frame, mode.
## The mode is shown in color when it is not Color, so odd-looking paint has an explanation (§8.4).
class_name StatusBar
extends PanelContainer

const TOOL_NAMES: Dictionary[StringName, String] = {
	&"pencil": "Pencil", &"eraser": "Eraser", &"line": "Line", &"rect": "Rectangle", &"ellipse": "Ellipse",
	&"fill": "Fill", &"picker": "Picker", &"select": "Select", &"move": "Move", &"brush_pickup": "Brush pickup",
}

var _state: EditorState
var _tools: ToolController
var _info: Label
var _mode: Label
var _cursor: Vector2i = Vector2i.ZERO
var _inside: bool = false
var _zoom: int = 1


func setup(state: EditorState, tools: ToolController, canvas: CanvasView) -> void:
	_state = state
	_tools = tools
	var row: HBoxContainer = HBoxContainer.new()
	add_child(row)
	_info = Label.new()
	_info.add_theme_color_override("font_color", PrismTheme.DIM)
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_info)
	_mode = Label.new()
	row.add_child(_mode)
	Signals.on(canvas.cursor_moved, _on_cursor_moved)
	Signals.on(canvas.zoom_changed, _on_zoom_changed)
	_zoom = canvas.zoom
	Signals.on(state.changed, _refresh)
	Signals.on(state.frame_changed, func(_index: int) -> void: _refresh())
	Signals.on(tools.tool_changed, func(_id: StringName) -> void: _refresh())
	Signals.on(state.bus.document_changed, func(_dirty: Rect2i) -> void: _refresh())
	_refresh()


func _on_cursor_moved(pixel: Vector2i, inside: bool) -> void:
	_cursor = pixel
	_inside = inside
	_refresh()


func _on_zoom_changed(zoom: int) -> void:
	_zoom = zoom
	_refresh()


func get_text() -> String:
	return _info.text


func _refresh() -> void:
	var doc: PrismDocument = _state.bus.document
	var parts: PackedStringArray = PackedStringArray()
	if _inside:
		var index: int = _state.index_at(_cursor)
		parts.append_array(["x %d  y %d" % [_cursor.x, _cursor.y], "idx %d #%s" % [index, doc.palette.get_color(index).to_html(false)]])
	else:
		parts.append_array(["%d×%d" % [doc.width, doc.height]])
	var tool_id: StringName = _tools.get_active_id()
	var tool_name: String = TOOL_NAMES.get(tool_id, String(tool_id))
	if tool_id == &"pencil" and _state.pixel_perfect:
		tool_name += " (pixel-perfect)"
	parts.append_array(["zoom %d%%" % (_zoom * 100), tool_name, "frame %d/%d" % [_state.frame_index + 1, doc.frames.size()], "layer %s" % doc.layers[clampi(_state.layer_index, 0, doc.layers.size() - 1)].layer_name])
	_info.text = "  ·  ".join(parts)
	var mode_name: String = SidePanel.MODE_NAMES[_state.draw_mode]
	_mode.text = "Mode: " + mode_name
	_mode.add_theme_color_override("font_color", PrismTheme.DIM if _state.draw_mode == PrismEnums.DrawMode.COLOR else PrismTheme.ORANGE)
