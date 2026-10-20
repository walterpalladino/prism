## Windowed checks for palette and stencil UI (skipped under --headless; see main_smoke_test.gd).
extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self

var _runner: GdUnitSceneRunner
var _grid: PaletteGrid
var _canvas: CanvasView


func before_test() -> void:
	EditorContext.new_document(Vector2i(32, 32))
	EditorContext.palette.load_palette(PalettePresets.default_32(), "Reset")
	EditorContext.palette.clear_stencil()
	EditorContext.tools.activate(&"pencil")
	_runner = scene_runner("res://ui/scenes/main.tscn")
	await _runner.simulate_frames(3)
	_grid = _runner.find_child("PaletteGrid") as PaletteGrid
	_canvas = _runner.find_child("CanvasView") as CanvasView


func _click_swatch(index: int, ctrl: bool) -> void:
	var at: Vector2 = _grid.get_global_transform_with_canvas() * _grid.swatch_rect(index).get_center()
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		if ctrl:
			if OS.has_feature("macos"):
				event.meta_pressed = true
			else:
				event.ctrl_pressed = true
		_grid.get_viewport().push_input(event)
		await _runner.simulate_frames(1)


func test_click_sets_fg_and_ctrl_click_locks(do_skip: bool = DisplayServer.get_name() == "headless", skip_reason: String = "needs a window") -> void:
	await _click_swatch(12, false)
	assert_int(EditorContext.state.fg).is_equal(12)
	await _click_swatch(5, true)
	assert_bool(EditorContext.bus.document.stencil.is_locked(5)).is_true()
	assert_int(EditorContext.state.fg).is_equal(12)


func test_painting_on_a_locked_color_flashes(do_skip: bool = DisplayServer.get_name() == "headless", skip_reason: String = "needs a window") -> void:
	EditorContext.bus.document.get_cel_image(0, 0).fill(4)
	EditorContext.bus.notify_document_changed()
	await _click_swatch(4, true)
	EditorContext.tools.press(Vector2i(3, 3), PrismEnums.PaintButton.PRIMARY, 0)
	EditorContext.tools.release(Vector2i(3, 3), 0)
	assert_bool(_canvas.is_flashing()).is_true()
	assert_int(EditorContext.bus.document.get_cel_image(0, 0).get_index(3, 3)).is_equal(4)


func test_double_click_opens_the_color_editor(do_skip: bool = DisplayServer.get_name() == "headless", skip_reason: String = "needs a window") -> void:
	var at: Vector2 = _grid.get_global_transform_with_canvas() * _grid.swatch_rect(7).get_center()
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.double_click = true
	event.position = at
	event.global_position = at
	_grid.get_viewport().push_input(event)
	await _runner.simulate_frames(2)
	var dialog: ColorEditDialog = _runner.find_child("ColorEditDialog") as ColorEditDialog
	assert_bool(dialog.visible).is_true()
	assert_int(dialog.get_edit_index()).is_equal(7)
	dialog.cancel()


func _press_button(name: String) -> void:
	var button: Button = _runner.find_child(name) as Button
	var at: Vector2 = button.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		button.get_viewport().push_input(event)
		await _runner.simulate_frames(1)


func test_plus_and_minus_add_and_remove_colors(do_skip: bool = DisplayServer.get_name() == "headless", skip_reason: String = "needs a window") -> void:
	await _click_swatch(10, false)
	await _press_button("AddColor")
	assert_int(EditorContext.bus.document.palette.size()).is_equal(33)
	assert_int(EditorContext.state.fg).is_equal(11)
	await _press_button("RemoveColor")
	assert_int(EditorContext.bus.document.palette.size()).is_equal(32)


func test_minus_on_a_used_color_asks_for_a_remap_target(do_skip: bool = DisplayServer.get_name() == "headless", skip_reason: String = "needs a window") -> void:
	EditorContext.bus.document.get_cel_image(0, 0).fill(4)
	EditorContext.bus.notify_document_changed()
	await _click_swatch(4, false)
	await _press_button("RemoveColor")
	assert_int(EditorContext.bus.document.palette.size()).is_equal(32)
	var dialog: ConfirmationDialog = _runner.find_child("RemapDialog") as ConfirmationDialog
	assert_object(dialog).is_not_null()
	var choice: OptionButton = dialog.find_child("RemapTarget", true, false) as OptionButton
	var target: int = choice.get_selected_id()
	assert_int(target).is_not_equal(4)
	var target_color: Color = EditorContext.bus.document.palette.get_color(target)
	dialog.get_ok_button().pressed.emit()
	await _runner.simulate_frames(2)
	var doc: PrismDocument = EditorContext.bus.document
	assert_int(doc.palette.size()).is_equal(31)
	assert_that(doc.palette.get_color(doc.get_cel_image(0, 0).get_index(0, 0))).is_equal(target_color)
