## "+" / "−" under the palette grid (GDD §7.4). "+" inserts a copy of the FG color after it;
## "−" removes the FG entry. When pixels use that entry, a dialog asks which color to repaint
## them with (nearest color preselected), so removing never changes the picture silently.
## Both are undoable.
class_name PaletteEntryBar
extends HBoxContainer

const SWATCH_ICON: int = 14

var _state: EditorState
var _actions: PaletteActions
var _add: Button
var _remove: Button
var _count: Label
var _message: AcceptDialog


func setup(state: EditorState, actions: PaletteActions) -> void:
	_state = state
	_actions = actions
	_add = _button("plus", "Add a color: a copy of FG, inserted after it (palettes hold up to %d)" % Palette.MAX_COLORS)
	_add.name = "AddColor"
	Signals.on(_add.pressed, _on_add)
	_remove = _button("minus", "Remove the FG color (pixels using it are repainted with a color you choose)")
	_remove.name = "RemoveColor"
	Signals.on(_remove.pressed, _on_remove)
	_count = Label.new()
	_count.add_theme_color_override("font_color", PrismTheme.DIM)
	add_child(_count)
	_message = AcceptDialog.new()
	_message.title = "Palette"
	add_child(_message)
	Signals.on(_state.changed, _refresh)
	Signals.on(_state.bus.palette_changed, _refresh)
	Signals.on(_state.bus.document_replaced, _refresh)
	_refresh()


func _button(icon_name: String, tip: String) -> Button:
	var button: Button = Button.new()
	button.icon = PrismIcons.get_icon(icon_name)
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	add_child(button)
	return button


func _refresh() -> void:
	var size: int = _state.palette_size()
	_add.disabled = size >= Palette.MAX_COLORS
	_remove.disabled = _actions.removal_blocker(_state.fg) != ""
	_remove.tooltip_text = _actions.removal_blocker(_state.fg) if _remove.disabled else "Remove the FG color (pixels using it are repainted with a color you choose)"
	_count.text = "%d / %d colors" % [size, Palette.MAX_COLORS]


func _on_add() -> void:
	_show_error(_actions.add_color_after_fg())


func _on_remove() -> void:
	var index: int = _state.fg
	var blocker: String = _actions.removal_blocker(index)
	if blocker != "":
		_show_error(blocker)
		return
	var used: int = _actions.usage_count(index)
	if used == 0:
		_show_error(_actions.remove_color(index))
		return
	var _dialog: ConfirmationDialog = open_remap_dialog(index, used)


## Asks which entry should replace `index` in the `used` pixels that use it, then removes it.
func open_remap_dialog(index: int, used: int) -> ConfirmationDialog:
	var palette: Palette = _actions.palette()
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.name = "RemapDialog"
	dialog.title = "Remove color %d" % index
	dialog.ok_button_text = "Remove"
	var box: VBoxContainer = VBoxContainer.new()
	var text: Label = Label.new()
	text.text = "%d pixel%s use%s entry %d (#%s).\nRepaint them with:" % [used, "" if used == 1 else "s", "s" if used == 1 else "", index, palette.get_color(index).to_html(false)]
	box.add_child(text)
	var choice: OptionButton = OptionButton.new()
	choice.name = "RemapTarget"
	var nearest: int = palette.nearest_index(palette.get_color(index), index)
	for i: int in palette.size():
		if i == index:
			continue
		choice.add_icon_item(_swatch_icon(palette.get_color(i)), "%d  #%s" % [i, palette.get_color(i).to_html(false)], i)
		if i == nearest:
			choice.select(choice.item_count - 1)
	box.add_child(choice)
	dialog.add_child(box)
	add_child(dialog)
	Signals.on(dialog.confirmed, func() -> void:
		var target: int = choice.get_selected_id()
		dialog.queue_free()
		_show_error(_actions.remove_color(index, target)))
	Signals.on(dialog.canceled, dialog.queue_free)
	dialog.popup_centered()
	return dialog


static func _swatch_icon(color: Color) -> ImageTexture:
	var image: Image = Image.create_empty(SWATCH_ICON, SWATCH_ICON, false, Image.FORMAT_RGB8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _show_error(error: String) -> void:
	if error == "":
		return
	_message.dialog_text = error
	_message.popup_centered()
