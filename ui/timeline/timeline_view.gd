## The layers × frames grid (GDD §7.8, concept C2), drawn entirely in _draw() so it stays
## fast with hundreds of frames (§9.4.7). The left column doubles as the layers panel.
##
## Mouse: click a cel to edit it, Shift+click or drag to select frames, drag a frame header
## or layer name to reorder, click the eye/lock to toggle, double-click a layer name to
## rename, a duration to change it, a tag to edit it. Right-click for more.
class_name TimelineView
extends Control

enum Area { NONE, TAG, HEADER, DURATION, LAYER_NAME, LAYER_EYE, LAYER_LOCK, CEL }

const LAYER_COLUMN: float = 176.0
const TAG_ROW: float = 18.0
const HEADER_ROW: float = 18.0
const DURATION_ROW: float = 16.0
const ROW: float = 26.0
const CELL: float = 26.0
## Icons are drawn at their native 24 px; downscaling pixel icons looks noisy.
const ICON: float = 24.0
const TOP: float = TAG_ROW + HEADER_ROW + DURATION_ROW

## Emitted when the user asks for a form (handled by TimelineDock).
signal rename_layer_requested(layer: int)
signal duration_requested(frame_range: Vector2i)
signal tag_edit_requested(tag_index: int)
signal opacity_requested(layer: int)

var _bus: CommandBus
var _state: EditorState
var _actions: TimelineActions
var _empty_cache: Dictionary[StringName, bool] = {}
var _font: Font
var _menu: PopupMenu
var _menu_hit: Dictionary = {}

# Drag state.
var _drag_area: Area = Area.NONE
var _drag_from: int = -1
var _drag_to: int = -1
var _range_anchor: int = -1


func setup(bus: CommandBus, state: EditorState, actions: TimelineActions) -> void:
	_bus = bus
	_state = state
	_actions = actions
	focus_mode = Control.FOCUS_CLICK
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = ThemeDB.fallback_font
	_menu = PopupMenu.new()
	add_child(_menu)
	Signals.on(_menu.id_pressed, _on_menu_id)
	Signals.on(_bus.document_changed, func(_dirty: Rect2i) -> void: _refresh(true))
	Signals.on(_bus.document_replaced, func() -> void: _refresh(true))
	Signals.on(_bus.image_changed, func(image_id: StringName, _dirty: Rect2i) -> void:
		var _erased: bool = _empty_cache.erase(image_id)
		queue_redraw())
	Signals.on(_state.changed, queue_redraw)
	Signals.on(_state.frame_changed, func(_index: int) -> void: queue_redraw())
	_refresh(true)


func _refresh(structure: bool) -> void:
	if structure:
		_empty_cache.clear()
	var doc: PrismDocument = _bus.document
	custom_minimum_size = Vector2(LAYER_COLUMN + doc.frames.size() * CELL + 24.0, TOP + doc.layers.size() * ROW + 6.0)
	queue_redraw()


# --- geometry ----------------------------------------------------------------

func layer_for_row(row: int) -> int:
	return _bus.document.layers.size() - 1 - row


func row_for_layer(layer: int) -> int:
	return _bus.document.layers.size() - 1 - layer


func cel_rect(layer: int, frame: int) -> Rect2:
	return Rect2(LAYER_COLUMN + frame * CELL, TOP + row_for_layer(layer) * ROW, CELL, ROW)


## What is under a local point: {area, layer, frame, tag}.
func hit(pos: Vector2) -> Dictionary:
	var doc: PrismDocument = _bus.document
	var result: Dictionary = {"area": Area.NONE, "layer": -1, "frame": -1, "tag": -1}
	var frame: int = floori((pos.x - LAYER_COLUMN) / CELL)
	var in_frames: bool = pos.x >= LAYER_COLUMN and frame >= 0 and frame < doc.frames.size()
	if pos.y < TOP:
		if not in_frames:
			return result
		result["frame"] = frame
		if pos.y < TAG_ROW:
			var tag_index: int = doc.tag_index_at(frame)
			if tag_index != -1:
				result["area"] = Area.TAG
				result["tag"] = tag_index
		elif pos.y < TAG_ROW + HEADER_ROW:
			result["area"] = Area.HEADER
		else:
			result["area"] = Area.DURATION
		return result
	var row: int = floori((pos.y - TOP) / ROW)
	if row < 0 or row >= doc.layers.size():
		return result
	result["layer"] = layer_for_row(row)
	if pos.x < LAYER_COLUMN:
		if pos.x < 5.0 + ICON:
			result["area"] = Area.LAYER_EYE
		elif pos.x < 7.0 + 2.0 * ICON:
			result["area"] = Area.LAYER_LOCK
		else:
			result["area"] = Area.LAYER_NAME
	elif in_frames:
		result["area"] = Area.CEL
		result["frame"] = frame
	return result


# --- input -------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if button.pressed:
			_on_press(button)
		elif button.button_index == MOUSE_BUTTON_LEFT:
			_on_release(button)
		accept_event()
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _drag_area != Area.NONE:
		_on_drag(motion)
		accept_event()


func _on_press(button: InputEventMouseButton) -> void:
	grab_focus()
	var h: Dictionary = hit(button.position)
	var area: Area = h["area"]
	var layer: int = h["layer"]
	var frame: int = h["frame"]
	var tag: int = h["tag"]
	if button.button_index == MOUSE_BUTTON_RIGHT:
		_open_menu(h, button.global_position)
		return
	if button.double_click:
		match area:
			Area.LAYER_NAME:
				rename_layer_requested.emit(layer)
			Area.DURATION:
				duration_requested.emit(_state.frame_range if _state.frame_range.x <= frame and frame <= _state.frame_range.y else Vector2i(frame, frame))
			Area.TAG:
				tag_edit_requested.emit(tag)
		return
	match area:
		Area.LAYER_EYE:
			_actions.set_layer_visible(layer, not _bus.document.layers[layer].visible)
		Area.LAYER_LOCK:
			_actions.set_layer_locked(layer, not _bus.document.layers[layer].locked)
		Area.LAYER_NAME:
			_state.set_layer(layer)
			_begin_drag(Area.LAYER_NAME, layer)
		Area.HEADER:
			_select_frame(frame, button.shift_pressed)
			_begin_drag(Area.HEADER, frame)
		Area.DURATION:
			_select_frame(frame, button.shift_pressed)
		Area.TAG:
			var t: Tag = _bus.document.tags[tag]
			_state.set_frame(t.from_frame)
			_state.set_frame_range(t.from_frame, t.to_frame)
		Area.CEL:
			_state.set_layer(layer)
			_select_frame(frame, button.shift_pressed)
			_begin_drag(Area.CEL, frame)


func _select_frame(frame: int, extend: bool) -> void:
	if extend:
		_state.set_frame_range(_state.frame_index, frame)
		_range_anchor = _state.frame_index
	else:
		_state.set_frame(frame)
		_range_anchor = frame


func _begin_drag(area: Area, from: int) -> void:
	_drag_area = area
	_drag_from = from
	_drag_to = from


func _on_drag(motion: InputEventMouseMotion) -> void:
	var h: Dictionary = hit(Vector2(clampf(motion.position.x, LAYER_COLUMN, size.x), motion.position.y))
	match _drag_area:
		Area.CEL:
			var frame: int = h["frame"]
			if frame != -1:
				_state.set_frame_range(_range_anchor, frame)
		Area.HEADER:
			var header_frame: int = floori((motion.position.x - LAYER_COLUMN) / CELL)
			_drag_to = clampi(header_frame, 0, _bus.document.frames.size() - 1)
		Area.LAYER_NAME:
			var row: int = floori((motion.position.y - TOP) / ROW)
			_drag_to = layer_for_row(clampi(row, 0, _bus.document.layers.size() - 1))
	queue_redraw()


func _on_release(_button: InputEventMouseButton) -> void:
	match _drag_area:
		Area.HEADER:
			if _drag_to != _drag_from:
				_actions.move_frame(_drag_from, _drag_to)
		Area.LAYER_NAME:
			if _drag_to != _drag_from:
				_actions.move_layer(_drag_from, _drag_to)
	_drag_area = Area.NONE
	queue_redraw()


# --- context menu ------------------------------------------------------------

enum MenuId {
	NEW_FRAME, DUPLICATE_FRAME, DUPLICATE_LINKED, DELETE_FRAME, SET_DURATION, NEW_TAG,
	EDIT_TAG, DELETE_TAG, NEW_LAYER, DUPLICATE_LAYER, DELETE_LAYER, RENAME_LAYER, LAYER_OPACITY,
	LINK_CELS, UNLINK_CEL, CLEAR_CEL, COPY_CEL, PASTE_CEL,
}


func _open_menu(h: Dictionary, at: Vector2) -> void:
	var area: Area = h["area"]
	if area == Area.NONE:
		return
	_menu_hit = h
	_menu.clear()
	var layer: int = h["layer"]
	var frame: int = h["frame"]
	if area == Area.CEL:
		_state.set_layer(layer)
		if not (_state.frame_range.x <= frame and frame <= _state.frame_range.y):
			_state.set_frame(frame)
	if area in [Area.CEL, Area.HEADER, Area.DURATION, Area.TAG]:
		_menu.add_item("New frame", MenuId.NEW_FRAME)
		_menu.add_item("Duplicate frame", MenuId.DUPLICATE_FRAME)
		_menu.add_item("Duplicate frame (linked)", MenuId.DUPLICATE_LINKED)
		_menu.add_item("Delete frame", MenuId.DELETE_FRAME)
		_menu.add_item("Frame duration…", MenuId.SET_DURATION)
		_menu.add_separator()
		_menu.add_item("New tag from selection", MenuId.NEW_TAG)
	if area == Area.TAG:
		_menu.add_item("Edit tag…", MenuId.EDIT_TAG)
		_menu.add_item("Delete tag", MenuId.DELETE_TAG)
	if area == Area.CEL:
		_menu.add_separator()
		_menu.add_item("Link selected cels", MenuId.LINK_CELS)
		_menu.set_item_disabled(_menu.item_count - 1, _state.frame_range.x == _state.frame_range.y)
		_menu.add_item("Unlink cel", MenuId.UNLINK_CEL)
		_menu.set_item_disabled(_menu.item_count - 1, not _actions.is_linked(layer, frame))
		_menu.add_item("Clear cel", MenuId.CLEAR_CEL)
		_menu.add_item("Copy cel", MenuId.COPY_CEL)
		_menu.add_item("Paste cel", MenuId.PASTE_CEL)
		_menu.set_item_disabled(_menu.item_count - 1, _state.cel_clipboard == null)
	if area in [Area.LAYER_NAME, Area.LAYER_EYE, Area.LAYER_LOCK, Area.CEL]:
		_menu.add_separator()
		_menu.add_item("New layer", MenuId.NEW_LAYER)
		_menu.add_item("Duplicate layer", MenuId.DUPLICATE_LAYER)
		_menu.add_item("Delete layer", MenuId.DELETE_LAYER)
		_menu.set_item_disabled(_menu.item_count - 1, _bus.document.layers.size() <= 1)
		_menu.add_item("Rename layer…", MenuId.RENAME_LAYER)
		_menu.add_item("Layer opacity…", MenuId.LAYER_OPACITY)
	_menu.position = Vector2i(at)
	_menu.reset_size()
	_menu.popup()


func _on_menu_id(id: int) -> void:
	var layer: int = _menu_hit.get("layer", _state.layer_index)
	var frame: int = _menu_hit.get("frame", _state.frame_index)
	if layer == -1:
		layer = _state.layer_index
	if frame == -1:
		frame = _state.frame_index
	var tag: int = _menu_hit.get("tag", -1)
	match id:
		MenuId.NEW_FRAME:
			_actions.insert_frame(frame + 1)
		MenuId.DUPLICATE_FRAME:
			_actions.duplicate_frame(frame, false)
		MenuId.DUPLICATE_LINKED:
			_actions.duplicate_frame(frame, true)
		MenuId.DELETE_FRAME:
			var _deleted: bool = _actions.delete_frame(frame)
		MenuId.SET_DURATION:
			duration_requested.emit(_state.frame_range)
		MenuId.NEW_TAG:
			tag_edit_requested.emit(_actions.add_tag(_state.frame_range))
		MenuId.EDIT_TAG:
			tag_edit_requested.emit(tag)
		MenuId.DELETE_TAG:
			_actions.delete_tag(tag)
		MenuId.NEW_LAYER:
			_state.set_layer(layer)
			_actions.add_layer()
		MenuId.DUPLICATE_LAYER:
			_actions.duplicate_layer(layer)
		MenuId.DELETE_LAYER:
			var _removed: bool = _actions.delete_layer(layer)
		MenuId.RENAME_LAYER:
			rename_layer_requested.emit(layer)
		MenuId.LAYER_OPACITY:
			opacity_requested.emit(layer)
		MenuId.LINK_CELS:
			var _linked: bool = _actions.link_cels(layer, _state.frame_range)
		MenuId.UNLINK_CEL:
			var _unlinked: bool = _actions.unlink_cel(layer, frame)
		MenuId.CLEAR_CEL:
			var _cleared: bool = _actions.clear_cel(layer, frame)
		MenuId.COPY_CEL:
			var _copied: bool = _actions.copy_cel(layer, frame)
		MenuId.PASTE_CEL:
			var _pasted: bool = _actions.paste_cel(layer, frame)


# --- drawing -----------------------------------------------------------------

func _is_empty(image_id: StringName) -> bool:
	if not _empty_cache.has(image_id):
		_empty_cache[image_id] = _bus.document.is_image_empty(image_id)
	return _empty_cache[image_id]


func _draw() -> void:
	if _bus == null:
		return
	var doc: PrismDocument = _bus.document
	var frames: int = doc.frames.size()
	var grid_width: float = frames * CELL
	draw_rect(Rect2(Vector2.ZERO, size), PrismTheme.BG)

	# Selected frame range and current frame column.
	var selection: Rect2 = Rect2(LAYER_COLUMN + _state.frame_range.x * CELL, TAG_ROW, (_state.frame_range.y - _state.frame_range.x + 1) * CELL, size.y - TAG_ROW)
	draw_rect(selection, Color(PrismTheme.BLUE, 0.18))
	draw_rect(Rect2(LAYER_COLUMN + _state.frame_index * CELL, TAG_ROW, CELL, size.y - TAG_ROW), Color(PrismTheme.ORANGE, 0.10))

	_draw_tags(doc)
	_draw_header(doc, frames)
	_draw_layers(doc, frames, grid_width)

	# Playhead.
	var x: float = LAYER_COLUMN + _state.frame_index * CELL
	draw_line(Vector2(x + CELL * 0.5, TAG_ROW), Vector2(x + CELL * 0.5, TAG_ROW + 4.0), PrismTheme.ORANGE, 2.0)
	draw_rect(Rect2(x, TAG_ROW, CELL, HEADER_ROW), PrismTheme.ORANGE, false, 1.0)

	# Drop indicators while dragging a frame or layer.
	if _drag_area == Area.HEADER and _drag_to != _drag_from:
		var drop_x: float = LAYER_COLUMN + (_drag_to + (1 if _drag_to > _drag_from else 0)) * CELL
		draw_line(Vector2(drop_x, TAG_ROW), Vector2(drop_x, size.y), Color.WHITE, 2.0)
	if _drag_area == Area.LAYER_NAME and _drag_to != _drag_from:
		var drop_row: int = row_for_layer(_drag_to) + (0 if _drag_to > _drag_from else 1)
		var drop_y: float = TOP + drop_row * ROW
		draw_line(Vector2(0, drop_y), Vector2(LAYER_COLUMN, drop_y), Color.WHITE, 2.0)


func _draw_tags(doc: PrismDocument) -> void:
	for tag: Tag in doc.tags:
		var rect: Rect2 = Rect2(LAYER_COLUMN + tag.from_frame * CELL + 1.0, 2.0, (tag.to_frame - tag.from_frame + 1) * CELL - 2.0, TAG_ROW - 4.0)
		draw_rect(rect, tag.color)
		var glyph: String = ["→", "←", "↔"][tag.direction]
		var text_color: Color = Color.BLACK if tag.color.get_luminance() > 0.5 else Color.WHITE
		_text(rect.position + Vector2(4, 11), "%s %s" % [tag.tag_name, glyph], text_color, 10, rect.size.x - 6.0)


func _draw_header(doc: PrismDocument, frames: int) -> void:
	_text(Vector2(8, TAG_ROW + 13), "LAYERS", PrismTheme.DIM, 10)
	_text(Vector2(8, TAG_ROW + HEADER_ROW + 12), "ms", PrismTheme.DIM, 10)
	for f: int in frames:
		var x: float = LAYER_COLUMN + f * CELL
		var number_color: Color = Color.WHITE if f == _state.frame_index else PrismTheme.TEXT
		_text_centered(Vector2(x + CELL * 0.5, TAG_ROW + 13), str(f + 1), number_color, 11)
		var duration: int = doc.frames[f].duration_ms
		var held: bool = duration != Frame.DEFAULT_DURATION_MS
		_text_centered(Vector2(x + CELL * 0.5, TAG_ROW + HEADER_ROW + 12), str(duration), PrismTheme.ORANGE if held else PrismTheme.DIM, 9)
	draw_line(Vector2(0, TOP - 0.5), Vector2(size.x, TOP - 0.5), PrismTheme.BORDER, 1.0)


func _draw_layers(doc: PrismDocument, frames: int, grid_width: float) -> void:
	var icons: ImageTexture = PrismIcons.atlas()
	for layer_index: int in doc.layers.size():
		var layer: Layer = doc.layers[layer_index]
		var y: float = TOP + row_for_layer(layer_index) * ROW
		var row_rect: Rect2 = Rect2(0, y, LAYER_COLUMN, ROW)
		if layer_index == _state.layer_index:
			draw_rect(row_rect, PrismTheme.PANEL_2)
			draw_rect(Rect2(0, y, 3, ROW), PrismTheme.ORANGE)
		draw_texture_rect_region(icons, Rect2(4, y + 1, ICON, ICON), PrismIcons.atlas_region("eye" if layer.visible else "eye_off"), PrismTheme.TEXT if layer.visible else PrismTheme.DIM)
		draw_texture_rect_region(icons, Rect2(6 + ICON, y + 1, ICON, ICON), PrismIcons.atlas_region("lock" if layer.locked else "unlock"), PrismTheme.ORANGE if layer.locked else PrismTheme.DIM)
		var name_text: String = layer.layer_name
		if layer.opacity < 255:
			name_text += "  %d%%" % roundi(layer.opacity / 2.55)
		_text(Vector2(12 + 2 * ICON, y + 17), name_text, PrismTheme.TEXT if layer.visible else PrismTheme.DIM, 12, LAYER_COLUMN - 16.0 - 2.0 * ICON)
		draw_line(Vector2(0, y + ROW - 0.5), Vector2(LAYER_COLUMN + grid_width, y + ROW - 0.5), Color(PrismTheme.BORDER, 0.6), 1.0)
		for f: int in frames:
			_draw_cel(doc, layer_index, f, y)
	draw_line(Vector2(LAYER_COLUMN - 0.5, TAG_ROW), Vector2(LAYER_COLUMN - 0.5, size.y), PrismTheme.BORDER, 1.0)


func _draw_cel(doc: PrismDocument, layer_index: int, frame: int, y: float) -> void:
	var cel: Cel = doc.get_cel(layer_index, frame)
	if cel == null:
		return
	var center: Vector2 = Vector2(LAYER_COLUMN + frame * CELL + CELL * 0.5, y + ROW * 0.5)
	var linked: bool = doc.count_image_users(cel.image_id) > 1
	var color: Color = PrismTheme.BLUE if linked else PrismTheme.TEXT
	if linked and frame + 1 < doc.frames.size():
		var next: Cel = doc.get_cel(layer_index, frame + 1)
		if next != null and next.image_id == cel.image_id:
			draw_line(center, center + Vector2(CELL, 0), PrismTheme.BLUE, 2.0)
	if _is_empty(cel.image_id):
		draw_arc(center, 4.5, 0.0, TAU, 16, color, 1.5)
	else:
		draw_circle(center, 5.0, color)
	if layer_index == _state.layer_index and frame == _state.frame_index:
		draw_rect(Rect2(center - Vector2(CELL, ROW) * 0.5 + Vector2(1, 1), Vector2(CELL, ROW) - Vector2(2, 2)), PrismTheme.ORANGE, false, 1.5)


func _text(at: Vector2, text: String, color: Color, font_size: int, max_width: float = -1.0) -> void:
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, max_width, font_size, color)


func _text_centered(at: Vector2, text: String, color: Color, font_size: int) -> void:
	var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(_font, at - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
