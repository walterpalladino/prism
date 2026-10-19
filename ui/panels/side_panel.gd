## Right-hand panel (concept C1): palette, brush, drawing mode and tool options.
## Stencil, layers and cycling sections arrive in M3-M5.
class_name SidePanel
extends PanelContainer

const MODE_NAMES: PackedStringArray = ["Color", "Replace", "Shade"]

var _state: EditorState
var _shape: OptionButton
var _size: SpinBox
var _brush_label: Label
var _mode: OptionButton
var _pixel_perfect: CheckBox
var _filled: CheckBox
var _global_fill: CheckBox


func setup(state: EditorState) -> void:
	_state = state
	custom_minimum_size = Vector2(220, 0)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	box.add_child(_heading("PALETTE"))
	var grid: PaletteGrid = PaletteGrid.new()
	grid.setup(state)
	box.add_child(grid)

	box.add_child(_heading("BRUSH"))
	var brush_row: HBoxContainer = HBoxContainer.new()
	_shape = OptionButton.new()
	_shape.add_item("Round", Brush.Shape.ROUND)
	_shape.add_item("Square", Brush.Shape.SQUARE)
	Signals.on(_shape.item_selected, func(_i: int) -> void: _apply_builtin())
	brush_row.add_child(_shape)
	_size = SpinBox.new()
	_size.min_value = 1
	_size.max_value = Brush.MAX_BUILTIN_SIZE
	_size.suffix = "px"
	Signals.on(_size.value_changed, func(_v: float) -> void: _apply_builtin())
	brush_row.add_child(_size)
	box.add_child(brush_row)
	_brush_label = Label.new()
	box.add_child(_brush_label)

	box.add_child(_heading("MODE"))
	_mode = OptionButton.new()
	for i: int in MODE_NAMES.size():
		_mode.add_item(MODE_NAMES[i], i)
	Signals.on(_mode.item_selected, func(i: int) -> void: _state.set_draw_mode(i as PrismEnums.DrawMode))
	box.add_child(_mode)

	box.add_child(_heading("OPTIONS"))
	_pixel_perfect = _check(box, "Pixel-perfect pencil", func(on: bool) -> void: _state.pixel_perfect = on)
	_filled = _check(box, "Filled shapes", func(on: bool) -> void: _state.filled_shapes = on)
	_global_fill = _check(box, "Global fill", func(on: bool) -> void: _state.global_fill = on)

	Signals.on(_state.changed, _refresh)
	_refresh()


func _apply_builtin() -> void:
	_state.set_builtin_brush(_shape.get_selected_id() as Brush.Shape, int(_size.value))


func _refresh() -> void:
	_shape.select(_shape.get_item_index(_state.builtin_shape))
	_size.set_value_no_signal(_state.builtin_size)
	var brush_size: Vector2i = _state.brush.get_size()
	_brush_label.text = ("Custom %d×%d  (Shift+B restores)" if _state.has_custom_brush else "Built-in %d×%d") % [brush_size.x, brush_size.y]
	_mode.select(_state.draw_mode)
	_pixel_perfect.set_pressed_no_signal(_state.pixel_perfect)
	_filled.set_pressed_no_signal(_state.filled_shapes)
	_global_fill.set_pressed_no_signal(_state.global_fill)


func _heading(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", PrismTheme.DIM)
	return label


func _check(parent: Container, text: String, on_toggle: Callable) -> CheckBox:
	var check: CheckBox = CheckBox.new()
	check.text = text
	check.focus_mode = Control.FOCUS_NONE
	Signals.on(check.toggled, on_toggle)
	parent.add_child(check)
	return check
