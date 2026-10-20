## Color-cycling ranges (GDD §7.6): up to 4 non-overlapping palette spans that rotate over
## time. Tab previews cycling; it also runs during playback.
class_name CyclePanel
extends VBoxContainer

const DIRECTIONS: PackedStringArray = ["Forward", "Reverse"]

var _state: EditorState
var _actions: PaletteActions
var _cycling: ColorCycling
var _list: VBoxContainer
var _preview: CheckBox
var _error: Label


func setup(state: EditorState, actions: PaletteActions, cycling: ColorCycling) -> void:
	_state = state
	_actions = actions
	_cycling = cycling
	_list = VBoxContainer.new()
	add_child(_list)
	var row: HBoxContainer = HBoxContainer.new()
	add_child(row)
	var add: Button = Button.new()
	add.text = "Cycle FG–BG"
	add.tooltip_text = "Make the span between the FG and BG entries a color-cycle range"
	add.focus_mode = Control.FOCUS_NONE
	add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Signals.on(add.pressed, func() -> void: _show_error(_actions.add_cycle_between_fg_and_bg()))
	row.add_child(add)
	_preview = CheckBox.new()
	_preview.text = "Preview (Tab)"
	_preview.focus_mode = Control.FOCUS_NONE
	Signals.on(_preview.toggled, func(on: bool) -> void: _cycling.request(&"tab", on))
	row.add_child(_preview)
	_error = Label.new()
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.add_theme_color_override("font_color", PrismTheme.ORANGE)
	_error.visible = false
	add_child(_error)
	Signals.on(_state.bus.palette_changed, _refresh)
	Signals.on(_state.bus.document_replaced, _refresh)
	Signals.on(_cycling.running_changed, func(_running: bool) -> void: _refresh())
	_refresh()


func _show_error(message: String) -> void:
	_error.text = message
	_error.visible = message != ""


func _refresh() -> void:
	_preview.set_pressed_no_signal(_cycling.is_requested(&"tab"))
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var cycles: Array[CycleRange] = _state.bus.document.cycles
	if cycles.is_empty():
		var empty: Label = Label.new()
		empty.text = "No cycles. Max %d." % DocumentValidator.MAX_CYCLES
		empty.add_theme_color_override("font_color", PrismTheme.DIM)
		_list.add_child(empty)
	for i: int in cycles.size():
		_list.add_child(_row(i, cycles[i]))


func _row(index: int, cycle: CycleRange) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var active: CheckBox = CheckBox.new()
	active.button_pressed = cycle.active
	active.focus_mode = Control.FOCUS_NONE
	active.tooltip_text = "Cycle on/off"
	Signals.on(active.toggled, func(on: bool) -> void:
		_show_error(_actions.update_cycle(index, cycle.start_index, cycle.end_index, cycle.rate_hz, cycle.step, on)))
	row.add_child(active)
	var label: Label = Label.new()
	label.text = "%d–%d  %s/s %s" % [cycle.start_index, cycle.end_index, String.num(cycle.rate_hz, 2), "fwd" if cycle.step > 0 else "rev"]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var edit: Button = Button.new()
	edit.text = "Edit"
	edit.focus_mode = Control.FOCUS_NONE
	Signals.on(edit.pressed, func() -> void: _edit(index))
	row.add_child(edit)
	var remove: Button = Button.new()
	remove.icon = PrismIcons.get_icon("trash")
	remove.tooltip_text = "Delete this cycle"
	remove.focus_mode = Control.FOCUS_NONE
	Signals.on(remove.pressed, func() -> void: _actions.delete_cycle(index))
	row.add_child(remove)
	return row


func _edit(index: int) -> void:
	var cycle: CycleRange = _state.bus.document.cycles[index]
	var last: int = _state.palette_size() - 1
	var form: FormDialog = FormDialog.new()
	form.title = "Color Cycle"
	form.add_number("start", "First entry", cycle.start_index, 0, last)
	form.add_number("end", "Last entry", cycle.end_index, 0, last)
	form.add_number("rate", "Steps / second", roundi(cycle.rate_hz), 1, 60)
	form.add_choice("direction", "Direction", DIRECTIONS, 0 if cycle.step > 0 else 1)
	Signals.on(form.submitted, func(values: Dictionary) -> void:
		var start: int = values["start"]
		var end: int = values["end"]
		var rate: int = values["rate"]
		var direction: int = values["direction"]
		_show_error(_actions.update_cycle(index, start, end, float(rate), 1 if direction == 0 else -1, cycle.active)))
	form.open(self)
