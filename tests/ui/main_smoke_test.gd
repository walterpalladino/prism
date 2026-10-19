## M2 exit check: real mouse events on the canvas draw a stroke, and Ctrl/Cmd+Z undoes it.
## Events are pushed into the scene's viewport, so they go through Godot's GUI routing and
## hit-testing. Godot's headless display server does not route mouse input to the GUI, so
## these tests skip under --headless; run them with a window (see CLAUDE.md, "Tests").
extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self

var _runner: GdUnitSceneRunner
var _canvas: CanvasView
var _mouse: Vector2 = Vector2.ZERO


func before_test() -> void:
	EditorContext.new_document(Vector2i(64, 64))
	EditorContext.tools.activate(&"pencil")
	EditorContext.state.set_builtin_brush(Brush.Shape.SQUARE, 1)
	EditorContext.state.set_fg(9)
	_runner = scene_runner("res://ui/scenes/main.tscn")
	await _runner.simulate_frames(3)
	_canvas = _runner.find_child("CanvasView") as CanvasView


func _screen(pixel: Vector2i) -> Vector2:
	return _canvas.get_global_transform_with_canvas() * _canvas.pixel_to_local(pixel)


func _image() -> IndexedImage:
	return EditorContext.bus.document.get_cel_image(0, 0)


func _push(event: InputEvent) -> void:
	_canvas.get_viewport().push_input(event)
	await _runner.simulate_frames(1)


func _mouse_button(pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = _mouse
	event.global_position = _mouse
	await _push(event)


func _mouse_move(pixel: Vector2i, held: bool) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	var target: Vector2 = _screen(pixel)
	event.relative = target - _mouse
	_mouse = target
	event.position = _mouse
	event.global_position = _mouse
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	await _push(event)


func _key(keycode: Key, command: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	if command:
		if OS.has_feature("macos"):
			event.meta_pressed = true
		else:
			event.ctrl_pressed = true
	await _push(event)


func test_stroke_then_undo(do_skip: bool = DisplayServer.get_name() == "headless", skip_reason: String = "needs a window: GUI mouse input is not routed in headless mode") -> void:
	await _mouse_move(Vector2i(10, 20), false)
	await _mouse_button(true)
	await _mouse_move(Vector2i(20, 20), true)
	await _mouse_button(false)

	assert_str(_image().to_rows()[20].substr(10, 11)).is_equal("99999999999")
	assert_int(EditorContext.bus.history.undo_count()).is_equal(1)

	await _key(KEY_Z, true)
	assert_int(_image().pixels.count(EditorContext.bus.document.transparent_index)).is_equal(64 * 64)
	assert_bool(EditorContext.bus.history.can_redo()).is_true()


func test_tool_shortcut_and_status_bar(do_skip: bool = DisplayServer.get_name() == "headless", skip_reason: String = "needs a window: GUI mouse input is not routed in headless mode") -> void:
	await _key(KEY_L, false)
	assert_str(String(EditorContext.tools.get_active_id())).is_equal("line")
	await _mouse_move(Vector2i(5, 6), false)
	var status: StatusBar = _runner.find_child("StatusBar") as StatusBar
	assert_str(status.get_text()).contains("x 5  y 6")
	assert_str(status.get_text()).contains("Line")
