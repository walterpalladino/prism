## DPaint-style toolbox: 2-column grid of tool buttons plus the FG/BG swatches (concept C1).
class_name Toolbox
extends VBoxContainer

## [tool id, icon name, tooltip]
const TOOLS: Array[Array] = [
	["pencil", "pencil", "Pencil (D)"],
	["eraser", "eraser", "Eraser (E)"],
	["line", "line", "Line (L) — Shift constrains angle"],
	["rect", "rect", "Rectangle (R, Shift+R filled) — Shift draws a square"],
	["ellipse", "ellipse", "Ellipse (O, Shift+O filled) — Shift draws a circle"],
	["fill", "fill", "Fill (F contiguous, Shift+F global)"],
	["picker", "picker", "Picker (I, or hold Alt) — LMB FG, RMB BG"],
	["select", "select", "Rect select (M) — Ctrl+C/X/V, arrows nudge"],
	["move", "move", "Move cel (V)"],
	["brush_pickup", "brush", "Brush pickup (B) — Shift+B restores the built-in brush"],
]

var _tools: ToolController
var _buttons: Dictionary[StringName, Button] = {}


func setup(tools: ToolController, state: EditorState) -> void:
	_tools = tools
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	add_child(grid)
	var group: ButtonGroup = ButtonGroup.new()
	for entry: Array in TOOLS:
		var id_text: String = entry[0]
		var icon_name: String = entry[1]
		var tooltip: String = entry[2]
		var id: StringName = StringName(id_text)
		var button: Button = Button.new()
		button.icon = PrismIcons.get_icon(icon_name)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.tooltip_text = tooltip
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(38, 36)
		Signals.on(button.pressed, func() -> void: _tools.activate(id))
		grid.add_child(button)
		_buttons[id] = button
	var swatches: ColorSwatches = ColorSwatches.new()
	swatches.setup(state)
	add_child(swatches)
	Signals.on(_tools.tool_changed, _on_tool_changed)
	_on_tool_changed(_tools.get_active_id())


func _on_tool_changed(tool_id: StringName) -> void:
	for id: StringName in _buttons:
		_buttons[id].set_pressed_no_signal(id == tool_id)
