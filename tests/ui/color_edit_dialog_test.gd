extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self

var _fx: AppFixture
var _dialog: ColorEditDialog


func before_test() -> void:
	_fx = AppFixture.new(4, 4)
	_dialog = ColorEditDialog.new()
	_dialog.setup(_fx.palette)
	add_child(_dialog)


func after_test() -> void:
	_dialog.queue_free()


func test_ok_records_one_undo_step() -> void:
	var original: Color = _fx.bus.document.palette.get_color(9)
	_dialog.edit(9)
	assert_bool(_dialog.visible).is_true()
	assert_int(_dialog.get_edit_index()).is_equal(9)
	_dialog.set_current_color(Color.RED)
	_dialog.set_current_color(Color.BLUE)
	assert_that(_fx.bus.document.palette.get_color(9)).is_equal(Color.BLUE)
	_dialog.accept()
	assert_bool(_dialog.visible).is_false()
	assert_int(_fx.bus.history.undo_count()).is_equal(1)
	_fx.bus.undo()
	assert_that(_fx.bus.document.palette.get_color(9)).is_equal(original)


func test_cancel_and_close_restore_the_original() -> void:
	var original: Color = _fx.bus.document.palette.get_color(9)
	_dialog.edit(9)
	_dialog.set_current_color(Color.RED)
	_dialog.cancel()
	assert_that(_fx.bus.document.palette.get_color(9)).is_equal(original)
	assert_bool(_fx.bus.history.can_undo()).is_false()
	_dialog.edit(9)
	_dialog.set_current_color(Color.GREEN)
	_dialog.close_requested.emit()
	assert_that(_fx.bus.document.palette.get_color(9)).is_equal(original)
	assert_int(_dialog.get_edit_index()).is_equal(-1)


func test_original_swatch_stays_while_editing() -> void:
	_dialog.edit(9)
	var original: Color = _fx.bus.document.palette.get_color(9)
	_dialog.set_current_color(Color.RED)
	var swatches: Array[Node] = _dialog.find_children("*", "ColorRect", true, false)
	var colors: Array[Color] = []
	for node: Node in swatches:
		colors.append((node as ColorRect).color)
	assert_array(colors).contains([original, Color.RED])
	assert_that(_dialog.get_current_color()).is_equal(Color.RED)
	_dialog.cancel()
