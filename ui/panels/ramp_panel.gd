## Shading ramps (GDD §7.4): contiguous palette spans used by Shade mode.
class_name RampPanel
extends VBoxContainer

var _state: EditorState
var _actions: PaletteActions
var _summary: Label
var _shade_wrap: CheckBox


func setup(state: EditorState, actions: PaletteActions) -> void:
	_state = state
	_actions = actions
	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_summary)
	var row: HBoxContainer = HBoxContainer.new()
	add_child(row)
	var add: Button = Button.new()
	add.text = "Ramp FG–BG"
	add.tooltip_text = "Make the span between the FG and BG entries a shading ramp (dark to light)"
	add.focus_mode = Control.FOCUS_NONE
	add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Signals.on(add.pressed, func() -> void:
		var _added: bool = _actions.add_ramp_between_fg_and_bg())
	row.add_child(add)
	var remove: Button = Button.new()
	remove.text = "Remove"
	remove.tooltip_text = "Remove the ramp that contains the FG entry"
	remove.focus_mode = Control.FOCUS_NONE
	Signals.on(remove.pressed, func() -> void:
		var _removed: bool = _actions.remove_ramp_at(_state.fg))
	row.add_child(remove)
	_shade_wrap = CheckBox.new()
	_shade_wrap.text = "Shade wraps at ramp ends"
	_shade_wrap.focus_mode = Control.FOCUS_NONE
	Signals.on(_shade_wrap.toggled, func(on: bool) -> void: _state.shade_wrap = on)
	add_child(_shade_wrap)
	Signals.on(_state.bus.palette_changed, _refresh)
	Signals.on(_state.bus.document_replaced, _refresh)
	_refresh()


func _refresh() -> void:
	var ramps: Array[Vector2i] = _state.bus.document.palette.ramps
	if ramps.is_empty():
		_summary.text = "No ramps. Shade mode needs at least one."
	else:
		var spans: PackedStringArray = PackedStringArray()
		for ramp: Vector2i in ramps:
			spans.append_array(["%d–%d" % [ramp.x, ramp.y]])
		_summary.text = "Ramps: " + ", ".join(spans)
	_shade_wrap.set_pressed_no_signal(_state.shade_wrap)
