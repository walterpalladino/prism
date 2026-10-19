## Bottom dock (GDD §8.1): playback/frame/layer toolbar above the scrollable TimelineView.
## Hidden and shown with Ctrl+T.
class_name TimelineDock
extends PanelContainer

const DIRECTIONS: PackedStringArray = ["Forward", "Reverse", "Ping-pong"]

var view: TimelineView

var _bus: CommandBus
var _state: EditorState
var _actions: TimelineActions
var _playback: Playback
var _play_button: Button
var _info: Label
var _onion: Button
var _onion_past: SpinBox
var _onion_future: SpinBox
var _onion_tag: CheckBox
var _onion_front: CheckBox


func setup(bus: CommandBus, state: EditorState, actions: TimelineActions, playback: Playback) -> void:
	_bus = bus
	_state = state
	_actions = actions
	_playback = playback
	custom_minimum_size = Vector2(0, 168)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	add_child(box)

	var bar: HBoxContainer = HBoxContainer.new()
	box.add_child(bar)
	_tool_button(bar, "play", "Play / stop (Enter)", func() -> void: _playback.toggle(_state.frame_index))
	_play_button = bar.get_child(bar.get_child_count() - 1) as Button
	_tool_button(bar, "prev", "Previous frame (,)", _actions.previous_frame)
	_tool_button(bar, "next", "Next frame (.)", _actions.next_frame)
	bar.add_child(VSeparator.new())
	_tool_button(bar, "plus", "New frame after the current one (Alt+N)", func() -> void: _actions.insert_frame(_state.frame_index + 1))
	_tool_button(bar, "duplicate", "Duplicate frame (Alt+D)", func() -> void: _actions.duplicate_frame(_state.frame_index, false))
	_tool_button(bar, "trash", "Delete frame", func() -> void:
		var _deleted: bool = _actions.delete_frame(_state.frame_index))
	bar.add_child(VSeparator.new())
	_text_button(bar, "+Layer", "New layer above the current one", _actions.add_layer)
	_text_button(bar, "−Layer", "Delete the current layer", func() -> void:
		var _deleted: bool = _actions.delete_layer(_state.layer_index))
	_text_button(bar, "+Tag", "New tag from the selected frames", func() -> void: _edit_tag(_actions.add_tag(_state.frame_range)))
	bar.add_child(VSeparator.new())
	_onion = Button.new()
	_onion.text = "Onion"
	_onion.toggle_mode = true
	_onion.focus_mode = Control.FOCUS_NONE
	_onion.tooltip_text = "Onion skin: show neighboring frames (F3)"
	Signals.on(_onion.toggled, func(_on: bool) -> void: _apply_onion())
	bar.add_child(_onion)
	_onion_past = _onion_spin(bar, "Past frames (blue)")
	_onion_future = _onion_spin(bar, "Future frames (orange)")
	_onion_tag = CheckBox.new()
	_onion_tag.text = "Tag only"
	_onion_tag.focus_mode = Control.FOCUS_NONE
	_onion_tag.tooltip_text = "Only show frames inside the current tag"
	Signals.on(_onion_tag.toggled, func(_on: bool) -> void: _apply_onion())
	bar.add_child(_onion_tag)
	_onion_front = CheckBox.new()
	_onion_front.text = "Front"
	_onion_front.focus_mode = Control.FOCUS_NONE
	_onion_front.tooltip_text = "Draw onion frames over the current frame (otherwise behind it)"
	Signals.on(_onion_front.toggled, func(on: bool) -> void: _state.set_onion_in_front(on))
	bar.add_child(_onion_front)
	_info = Label.new()
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_info.add_theme_color_override("font_color", PrismTheme.DIM)
	bar.add_child(_info)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	view = TimelineView.new()
	view.name = "TimelineView"
	view.setup(bus, state, actions)
	scroll.add_child(view)

	Signals.on(view.rename_layer_requested, _rename_layer)
	Signals.on(view.duration_requested, _edit_duration)
	Signals.on(view.tag_edit_requested, _edit_tag)
	Signals.on(view.opacity_requested, _edit_opacity)
	Signals.on(_playback.playing_changed, _on_playing_changed)
	Signals.on(_state.changed, _refresh_info)
	Signals.on(_state.changed, _refresh_onion)
	Signals.on(_state.frame_changed, func(_index: int) -> void: _refresh_info())
	Signals.on(_bus.document_changed, func(_dirty: Rect2i) -> void: _refresh_info())
	_refresh_info()
	_refresh_onion()


func _onion_spin(parent: Container, tooltip: String) -> SpinBox:
	var spin: SpinBox = SpinBox.new()
	spin.min_value = 0
	spin.max_value = EditorState.ONION_MAX
	spin.tooltip_text = tooltip
	spin.custom_minimum_size = Vector2(56, 0)
	Signals.on(spin.value_changed, func(_v: float) -> void: _apply_onion())
	parent.add_child(spin)
	return spin


func _apply_onion() -> void:
	_state.set_onion(_onion.button_pressed, int(_onion_past.value), int(_onion_future.value), _onion_tag.button_pressed)


func _refresh_onion() -> void:
	_onion.set_pressed_no_signal(_state.onion_enabled)
	_onion_past.set_value_no_signal(_state.onion_past)
	_onion_future.set_value_no_signal(_state.onion_future)
	_onion_tag.set_pressed_no_signal(_state.onion_tag_bounded)
	_onion_front.set_pressed_no_signal(_state.onion_in_front)


func _on_playing_changed(playing: bool) -> void:
	_play_button.icon = PrismIcons.get_icon("pause" if playing else "play")
	_refresh_info()


func _refresh_info() -> void:
	var doc: PrismDocument = _bus.document
	var frame: Frame = doc.frames[clampi(_state.frame_index, 0, doc.frames.size() - 1)]
	var parts: PackedStringArray = ["frame %d/%d" % [_state.frame_index + 1, doc.frames.size()], "%d ms" % frame.duration_ms]
	var tag_index: int = doc.tag_index_at(_state.frame_index)
	if tag_index != -1:
		parts.append_array(["tag " + doc.tags[tag_index].tag_name])
	if _playback.playing:
		parts.append_array(["playing"])
	elif _state.onion_enabled:
		var shown: int = _state.onion_frames().size()
		parts.append_array(["onion: %d frame%s" % [shown, "" if shown == 1 else "s"] if shown > 0 else "onion: no neighboring frames"])
	_info.text = "  ·  ".join(parts) + "  "


# --- forms -------------------------------------------------------------------

func _rename_layer(layer: int) -> void:
	var form: FormDialog = FormDialog.new()
	form.title = "Rename Layer"
	form.add_text("name", "Name", _bus.document.layers[layer].layer_name)
	Signals.on(form.submitted, func(values: Dictionary) -> void:
		var new_name: String = values["name"]
		_actions.rename_layer(layer, new_name))
	form.open(self)


func _edit_opacity(layer: int) -> void:
	var form: FormDialog = FormDialog.new()
	form.title = "Layer Opacity"
	form.add_number("opacity", "Opacity", roundi(_bus.document.layers[layer].opacity / 2.55), 0, 100, "%")
	Signals.on(form.submitted, func(values: Dictionary) -> void:
		var percent: int = values["opacity"]
		_actions.set_layer_opacity(layer, roundi(percent * 2.55)))
	form.open(self)


func _edit_duration(frame_range: Vector2i) -> void:
	var form: FormDialog = FormDialog.new()
	var count: int = frame_range.y - frame_range.x + 1
	form.title = "Frame Duration" if count == 1 else "Duration of %d Frames" % count
	form.add_number("ms", "Duration", _bus.document.frames[frame_range.x].duration_ms, TimelineActions.MIN_DURATION_MS, TimelineActions.MAX_DURATION_MS, " ms")
	Signals.on(form.submitted, func(values: Dictionary) -> void:
		var ms: int = values["ms"]
		_actions.set_duration(frame_range, ms))
	form.open(self)


func _edit_tag(tag_index: int) -> void:
	if tag_index < 0 or tag_index >= _bus.document.tags.size():
		return
	var tag: Tag = _bus.document.tags[tag_index]
	var frames: int = _bus.document.frames.size()
	var form: FormDialog = FormDialog.new()
	form.title = "Tag"
	form.add_text("name", "Name", tag.tag_name)
	form.add_number("from", "First frame", tag.from_frame + 1, 1, frames)
	form.add_number("to", "Last frame", tag.to_frame + 1, 1, frames)
	form.add_choice("direction", "Direction", DIRECTIONS, tag.direction)
	form.add_color("color", "Color", tag.color)
	Signals.on(form.submitted, func(values: Dictionary) -> void:
		var tag_name: String = values["name"]
		var first: int = values["from"]
		var last: int = values["to"]
		var direction: int = values["direction"]
		var color: Color = values["color"]
		_actions.update_tag(tag_index, tag_name, Vector2i(first - 1, last - 1), direction as PrismEnums.TagDirection, color))
	form.open(self)


func _tool_button(parent: Container, icon_name: String, tooltip: String, action: Callable) -> void:
	var button: Button = Button.new()
	button.icon = PrismIcons.get_icon(icon_name)
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(30, 28)
	Signals.on(button.pressed, action)
	parent.add_child(button)


func _text_button(parent: Container, text: String, tooltip: String, action: Callable) -> void:
	var button: Button = Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	Signals.on(button.pressed, action)
	parent.add_child(button)
