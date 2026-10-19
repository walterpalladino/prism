## Stencil controls (GDD §7.5): lock FG, invert, lock all except FG, clear, and the
## flash-on-block option. `~` shows/hides this section.
class_name StencilPanel
extends VBoxContainer

var _state: EditorState
var _actions: PaletteActions
var _summary: Label


func setup(state: EditorState, actions: PaletteActions) -> void:
	_state = state
	_actions = actions
	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_summary)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	add_child(grid)
	_button(grid, "Lock FG", "Toggle the lock on the FG entry (or Ctrl+click any swatch)", func() -> void: _actions.toggle_lock(_state.fg))
	_button(grid, "Invert", "Lock every unlocked entry and unlock the rest", _actions.invert_stencil)
	_button(grid, "All but FG", "Lock every entry except FG", _actions.lock_all_except_fg)
	_button(grid, "Clear", "Unlock every entry", _actions.clear_stencil)
	var flash: CheckBox = CheckBox.new()
	flash.text = "Flash blocked pixels"
	flash.focus_mode = Control.FOCUS_NONE
	flash.button_pressed = _state.flash_stencil
	Signals.on(flash.toggled, func(on: bool) -> void: _state.flash_stencil = on)
	add_child(flash)
	Signals.on(_state.bus.palette_changed, _refresh)
	Signals.on(_state.bus.document_replaced, _refresh)
	_refresh()


func _button(parent: Container, text: String, tooltip: String, action: Callable) -> void:
	var button: Button = Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Signals.on(button.pressed, action)
	parent.add_child(button)


func _refresh() -> void:
	var locked: PackedInt32Array = _state.bus.document.stencil.locked_indices()
	if locked.is_empty():
		_summary.text = "No entries locked."
	elif locked.size() <= 12:
		var names: PackedStringArray = PackedStringArray()
		for index: int in locked:
			names.append_array([str(index)])
		_summary.text = "Locked: " + ", ".join(names)
	else:
		_summary.text = "%d entries locked." % locked.size()
