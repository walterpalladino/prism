## Popup editor for one palette entry (GDD §7.4), opened by double-clicking a swatch.
## Shows the original color beside the edited one; hex entry plus RGB and HSV sliders.
## Edits preview live on the canvas. OK records one undo step; Cancel or closing restores
## the original and records nothing.
class_name ColorEditDialog
extends Window

const SWATCH_SIZE: Vector2 = Vector2(64, 48)

var _actions: PaletteActions
var _index: int = -1
var _original: Color
var _original_swatch: ColorRect
var _current_swatch: ColorRect
var _hex: LineEdit
var _sliders: Dictionary[String, HSlider] = {}
var _values: Dictionary[String, Label] = {}
var _updating: bool = false


func setup(actions: PaletteActions) -> void:
	_actions = actions
	title = "Edit Color"
	exclusive = true
	transient = true
	unresizable = true
	visible = false
	wrap_controls = true
	Signals.on(close_requested, cancel)

	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	var compare: HBoxContainer = HBoxContainer.new()
	compare.add_theme_constant_override("separation", 0)
	_original_swatch = _swatch(compare, "Original — click to restore it")
	Signals.on(_original_swatch.gui_input, _on_original_input)
	_current_swatch = _swatch(compare, "New")
	box.add_child(compare)
	var captions: HBoxContainer = HBoxContainer.new()
	captions.add_child(_caption("Original"))
	captions.add_child(_caption("New"))
	box.add_child(captions)

	_hex = LineEdit.new()
	_hex.max_length = 7
	_hex.tooltip_text = "Hex color (Enter to apply)"
	Signals.on(_hex.text_submitted, _on_hex_submitted)
	box.add_child(_hex)
	for channel: String in ["R", "G", "B", "H", "S", "V"]:
		_add_slider(box, channel, 360.0 if channel == "H" else (100.0 if channel in ["S", "V"] else 255.0))

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	var cancel_button: Button = Button.new()
	cancel_button.text = "Cancel"
	Signals.on(cancel_button.pressed, cancel)
	buttons.add_child(cancel_button)
	var ok_button: Button = Button.new()
	ok_button.text = "OK"
	Signals.on(ok_button.pressed, accept)
	buttons.add_child(ok_button)
	box.add_child(buttons)


## Opens the editor for palette entry `index`.
func edit(index: int) -> void:
	_actions.commit_color()
	_index = index
	_original = _actions.palette().get_color(index)
	title = "Edit Color %d" % index
	_original_swatch.color = _original
	_show(_original)
	popup_centered(Vector2i(300, 0))
	_hex.grab_focus()


func get_edit_index() -> int:
	return _index


func get_current_color() -> Color:
	return _current_swatch.color


## Previews `color` on the canvas and in the "New" swatch.
func set_current_color(color: Color) -> void:
	_actions.preview_color(_index, color)
	_show(color)


func accept() -> void:
	_actions.commit_color()
	_close()


func cancel() -> void:
	_actions.cancel_preview()
	_close()


func _close() -> void:
	_index = -1
	hide()


func _show(color: Color) -> void:
	_updating = true
	_current_swatch.color = color
	if not _hex.has_focus() or _hex.text.trim_prefix("#").to_lower() != color.to_html(false):
		_hex.text = "#" + color.to_html(false)
	var values: Dictionary[String, float] = {
		"R": color.r8, "G": color.g8, "B": color.b8,
		"H": roundf(color.h * 360.0), "S": roundf(color.s * 100.0), "V": roundf(color.v * 100.0),
	}
	for channel: String in _sliders:
		# Hue and saturation are undefined for grays and black: leave those sliders where they are.
		var keep: bool = (channel == "H" and color.s == 0.0) or (channel in ["H", "S"] and color.v == 0.0)
		if not keep:
			_sliders[channel].set_value_no_signal(values[channel])
		_values[channel].text = str(int(_sliders[channel].value))
	_updating = false


func _on_slider_changed(channel: String) -> void:
	if _updating or _index == -1:
		return
	var color: Color
	if channel in ["R", "G", "B"]:
		color = Color8(int(_sliders["R"].value), int(_sliders["G"].value), int(_sliders["B"].value))
	else:
		color = Color.from_hsv(_sliders["H"].value / 360.0, _sliders["S"].value / 100.0, _sliders["V"].value / 100.0)
	set_current_color(color)


func _on_hex_submitted(text: String) -> void:
	var cleaned: String = text.strip_edges().trim_prefix("#")
	if cleaned.length() == 6 and cleaned.is_valid_hex_number():
		set_current_color(Color.html(cleaned))
	else:
		_show(_current_swatch.color)


func _on_original_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		set_current_color(_original)


func _add_slider(parent: Container, channel: String, max_value: float) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = channel
	label.custom_minimum_size = Vector2(14, 0)
	row.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.max_value = max_value
	slider.step = 1.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	Signals.on(slider.value_changed, func(_v: float) -> void: _on_slider_changed(channel))
	row.add_child(slider)
	var value: Label = Label.new()
	value.custom_minimum_size = Vector2(30, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	parent.add_child(row)
	_sliders[channel] = slider
	_values[channel] = value


func _swatch(parent: Container, tooltip: String) -> ColorRect:
	var rect: ColorRect = ColorRect.new()
	rect.custom_minimum_size = SWATCH_SIZE
	rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rect.tooltip_text = tooltip
	parent.add_child(rect)
	return rect


func _caption(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", PrismTheme.DIM)
	return label
