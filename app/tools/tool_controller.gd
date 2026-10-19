## Routes pointer input to the active tool. Primary button paints FG, secondary BG
## (DPaint heritage). Holding Alt while pressing temporarily uses the picker.
class_name ToolController
extends RefCounted

signal tool_changed(tool_id: StringName)

var tools: Dictionary[StringName, Tool] = {}

var _active: Tool
var _previous_id: StringName = &""
## The tool handling the current stroke (may be the Alt picker), or null.
var _stroke_tool: Tool


## Registers a tool; the first one registered becomes active.
func register(tool: Tool) -> void:
	tools[tool.get_id()] = tool
	if _active == null:
		_active = tool


func activate(tool_id: StringName) -> void:
	assert(tools.has(tool_id), "unknown tool %s" % tool_id)
	if _active != null and _active.get_id() == tool_id:
		return
	cancel()
	if _active != null:
		_previous_id = _active.get_id()
	_active = tools[tool_id]
	tool_changed.emit(tool_id)


func get_active() -> Tool:
	return _active


func get_active_id() -> StringName:
	return _active.get_id()


func is_stroke_active() -> bool:
	return _stroke_tool != null


func press(pos: Vector2i, button: PrismEnums.PaintButton, mods: int) -> void:
	if _stroke_tool != null:
		return
	var use_picker: bool = (mods & Tool.MOD_ALT) != 0 and tools.has(&"picker")
	_stroke_tool = tools[&"picker"] if use_picker else _active
	_stroke_tool.begin(pos, button, mods)


func motion(pos: Vector2i, mods: int) -> void:
	if _stroke_tool != null:
		_stroke_tool.drag(pos, mods)


func release(pos: Vector2i, mods: int) -> void:
	if _stroke_tool == null:
		return
	var tool: Tool = _stroke_tool
	_stroke_tool = null
	tool.end(pos, mods)
	if tool == _active and tool.returns_to_previous_tool() and _previous_id != &"":
		activate(_previous_id)


## Esc: abandons the current stroke without an undo entry.
func cancel() -> void:
	if _stroke_tool == null:
		return
	var tool: Tool = _stroke_tool
	_stroke_tool = null
	tool.cancel()
