## Windowed timeline checks (skipped under --headless; see main_smoke_test.gd).
extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self

var _runner: GdUnitSceneRunner
var _view: TimelineView


func before_test() -> void:
	EditorContext.new_document(Vector2i(16, 16))
	EditorContext.timeline.insert_frame(1)
	EditorContext.timeline.insert_frame(2)
	EditorContext.timeline.add_layer()
	EditorContext.state.set_frame(0)
	_runner = scene_runner("res://ui/scenes/main.tscn")
	await _runner.simulate_frames(3)
	_view = _runner.find_child("TimelineView") as TimelineView


func _click(local: Vector2, double: bool = false) -> void:
	var at: Vector2 = _view.get_global_transform_with_canvas() * local
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.double_click = double and pressed
		event.position = at
		event.global_position = at
		_view.get_viewport().push_input(event)
		await _runner.simulate_frames(1)


func _key(keycode: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	_view.get_viewport().push_input(event)
	await _runner.simulate_frames(1)


func test_clicking_a_cel_selects_layer_and_frame(do_skip: bool = DisplayServer.get_name() == "headless", skip_reason: String = "needs a window") -> void:
	await _click(_view.cel_rect(0, 2).get_center())
	assert_int(EditorContext.state.frame_index).is_equal(2)
	assert_int(EditorContext.state.layer_index).is_equal(0)


func test_eye_toggles_visibility(do_skip: bool = DisplayServer.get_name() == "headless", skip_reason: String = "needs a window") -> void:
	var row_y: float = _view.cel_rect(1, 0).get_center().y
	await _click(Vector2(10, row_y))
	assert_bool(EditorContext.bus.document.layers[1].visible).is_false()


func test_frame_keys_and_play(do_skip: bool = DisplayServer.get_name() == "headless", skip_reason: String = "needs a window") -> void:
	await _key(KEY_PERIOD)
	assert_int(EditorContext.state.frame_index).is_equal(1)
	await _key(KEY_COMMA)
	await _key(KEY_COMMA)
	assert_int(EditorContext.state.frame_index).is_equal(2)
	await _key(KEY_ENTER)
	assert_bool(EditorContext.playback.playing).is_true()
	await _runner.simulate_frames(20, 20)
	await _key(KEY_ENTER)
	assert_bool(EditorContext.playback.playing).is_false()


func test_double_click_layer_name_opens_rename(do_skip: bool = DisplayServer.get_name() == "headless", skip_reason: String = "needs a window") -> void:
	var row_y: float = _view.cel_rect(1, 0).get_center().y
	await _click(Vector2(80, row_y), true)
	var forms: Array[Node] = _runner.scene().find_children("*", "FormDialog", true, false)
	assert_int(forms.size()).is_equal(1)
	var form: FormDialog = forms[0] as FormDialog
	assert_str(form.title).is_equal("Rename Layer")
	form.queue_free()


func test_tab_toggles_cycling_and_f3_toggles_onion(do_skip: bool = DisplayServer.get_name() == "headless", skip_reason: String = "needs a window") -> void:
	assert_bool(EditorContext.cycling.is_requested(&"tab")).is_false()
	await _key(KEY_TAB)
	assert_bool(EditorContext.cycling.is_requested(&"tab")).is_true()
	await _key(KEY_TAB)
	assert_bool(EditorContext.cycling.is_requested(&"tab")).is_false()
	var onion_before: bool = EditorContext.state.onion_enabled
	await _key(KEY_F3)
	assert_bool(EditorContext.state.onion_enabled).is_not_equal(onion_before)
	await _key(KEY_F3)
