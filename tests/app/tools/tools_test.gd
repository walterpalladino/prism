extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self

const PRIMARY: PrismEnums.PaintButton = PrismEnums.PaintButton.PRIMARY
const SECONDARY: PrismEnums.PaintButton = PrismEnums.PaintButton.SECONDARY


func _fixture() -> AppFixture:
	var fx: AppFixture = AppFixture.new(6, 4)
	fx.state.set_fg(1)
	fx.state.set_bg(2)
	return fx


# --- pencil / eraser ---------------------------------------------------------

func test_pencil_stroke_is_one_undo_step() -> void:
	var fx: AppFixture = _fixture()
	fx.stroke(&"pencil", [Vector2i(0, 0), Vector2i(5, 0)])
	assert_that(fx.rows()).is_equal(PackedStringArray(["111111", "000000", "000000", "000000"]))
	assert_int(fx.bus.history.undo_count()).is_equal(1)
	assert_str(fx.bus.history.undo_label()).is_equal("Pencil")
	fx.bus.undo()
	assert_int(fx.image().pixels.count(0)).is_equal(24)


func test_pencil_interpolates_between_events() -> void:
	var fx: AppFixture = _fixture()
	fx.state.pixel_perfect = false
	fx.stroke(&"pencil", [Vector2i(0, 0), Vector2i(3, 3)])
	assert_that(fx.rows()).is_equal(PackedStringArray(["100000", "010000", "001000", "000100"]))


func test_secondary_button_paints_bg() -> void:
	var fx: AppFixture = _fixture()
	fx.click(&"pencil", Vector2i(2, 2), SECONDARY)
	assert_int(fx.image().get_index(2, 2)).is_equal(2)


func test_pixel_perfect_removes_corners() -> void:
	var fx: AppFixture = _fixture()
	var staircase: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2), Vector2i(3, 2)]
	fx.stroke(&"pencil", staircase)
	assert_that(fx.rows()).is_equal(PackedStringArray(["100000", "010000", "001100", "000000"]))
	var plain: AppFixture = _fixture()
	plain.state.pixel_perfect = false
	plain.stroke(&"pencil", staircase)
	assert_that(plain.rows()).is_equal(PackedStringArray(["110000", "011000", "001100", "000000"]))


func test_pixel_perfect_restores_original_pixels() -> void:
	var fx: AppFixture = _fixture()
	fx.image().set_index(1, 0, 5)
	fx.stroke(&"pencil", [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)])
	assert_int(fx.image().get_index(1, 0)).is_equal(5)


func test_eraser_paints_transparent_and_respects_stencil() -> void:
	var fx: AppFixture = _fixture()
	fx.image().fill(3)
	fx.image().set_index(2, 0, 4)
	fx.bus.document.stencil.set_locked(4, true)
	fx.stroke(&"eraser", [Vector2i(0, 0), Vector2i(3, 0)])
	assert_that(fx.rows()[0]).is_equal("004033")
	assert_str(fx.bus.history.undo_label()).is_equal("Erase")


func test_cancel_restores_and_leaves_no_undo() -> void:
	var fx: AppFixture = _fixture()
	fx.controller.activate(&"pencil")
	fx.controller.press(Vector2i(0, 0), PRIMARY, 0)
	fx.controller.motion(Vector2i(5, 3), 0)
	assert_bool(fx.controller.is_stroke_active()).is_true()
	fx.controller.cancel()
	fx.controller.release(Vector2i(5, 3), 0)
	assert_int(fx.image().pixels.count(0)).is_equal(24)
	assert_bool(fx.bus.history.can_undo()).is_false()


func test_locked_layer_is_not_painted() -> void:
	var fx: AppFixture = _fixture()
	fx.bus.document.layers[0].locked = true
	for id: StringName in [&"pencil", &"line", &"fill", &"move", &"brush_pickup"]:
		fx.click(id, Vector2i(1, 1))
	assert_int(fx.image().pixels.count(0)).is_equal(24)
	assert_bool(fx.bus.history.can_undo()).is_false()


func test_offset_cel_paints_in_image_space() -> void:
	var fx: AppFixture = _fixture()
	fx.state.current_cel().offset = Vector2i(1, 1)
	fx.click(&"pencil", Vector2i(1, 1))
	assert_int(fx.image().get_index(0, 0)).is_equal(1)


# --- shapes ------------------------------------------------------------------

func test_line_preview_redraws_from_snapshot() -> void:
	var fx: AppFixture = _fixture()
	fx.stroke(&"line", [Vector2i(0, 0), Vector2i(5, 3), Vector2i(5, 0)])
	assert_that(fx.rows()).is_equal(PackedStringArray(["111111", "000000", "000000", "000000"]))
	assert_int(fx.bus.history.undo_count()).is_equal(1)


func test_line_shift_constrains() -> void:
	var fx: AppFixture = _fixture()
	fx.stroke(&"line", [Vector2i(0, 0), Vector2i(5, 1)], PRIMARY, Tool.MOD_SHIFT)
	assert_that(fx.rows()[0]).is_equal("111111")


func test_rect_outline_and_filled() -> void:
	var fx: AppFixture = _fixture()
	fx.stroke(&"rect", [Vector2i(4, 3), Vector2i(1, 0)])
	assert_that(fx.rows()).is_equal(PackedStringArray(["011110", "010010", "010010", "011110"]))
	var filled: AppFixture = _fixture()
	filled.state.filled_shapes = true
	filled.stroke(&"rect", [Vector2i(1, 1), Vector2i(2, 2)])
	assert_that(filled.rows()).is_equal(PackedStringArray(["000000", "011000", "011000", "000000"]))
	assert_str(filled.bus.history.undo_label()).is_equal("Rectangle")


func test_rect_shift_makes_square() -> void:
	var fx: AppFixture = _fixture()
	fx.state.filled_shapes = true
	fx.stroke(&"rect", [Vector2i(0, 0), Vector2i(5, 1)], PRIMARY, Tool.MOD_SHIFT)
	assert_that(fx.rows()).is_equal(PackedStringArray(["111111", "111111", "111111", "111111"]))


func test_ellipse_matches_raster_ops() -> void:
	var fx: AppFixture = AppFixture.new(8, 8)
	fx.state.set_fg(1)
	fx.stroke(&"ellipse", [Vector2i(0, 0), Vector2i(7, 7)])
	assert_that(fx.rows()[0]).is_equal("00111100")
	assert_str(fx.bus.history.undo_label()).is_equal("Ellipse")


func test_shape_cancel() -> void:
	var fx: AppFixture = _fixture()
	fx.controller.activate(&"rect")
	fx.controller.press(Vector2i(0, 0), PRIMARY, 0)
	fx.controller.motion(Vector2i(3, 3), 0)
	fx.controller.cancel()
	assert_int(fx.image().pixels.count(0)).is_equal(24)
	assert_bool(fx.bus.history.can_undo()).is_false()


func test_rect_helpers() -> void:
	assert_that(Tool.rect_from_corners(Vector2i(3, 1), Vector2i(1, 2))).is_equal(Rect2i(1, 1, 3, 2))
	assert_that(Tool.square_corner(Vector2i(0, 0), Vector2i(-2, 5))).is_equal(Vector2i(-5, 5))


# --- fill / picker -----------------------------------------------------------

func test_fill_contiguous_and_global() -> void:
	var fx: AppFixture = _fixture()
	fx.stroke(&"line", [Vector2i(2, 0), Vector2i(2, 3)])
	fx.state.set_fg(5)
	fx.click(&"fill", Vector2i(0, 0))
	assert_that(fx.rows()[0]).is_equal("551000")
	fx.state.global_fill = true
	fx.state.set_bg(7)
	fx.click(&"fill", Vector2i(2, 0), SECONDARY)
	assert_that(fx.rows()[0]).is_equal("557000")
	assert_int(fx.bus.history.undo_count()).is_equal(3)
	fx.click(&"fill", Vector2i(20, 20))
	assert_int(fx.bus.history.undo_count()).is_equal(3)


func test_picker_and_alt_hold() -> void:
	var fx: AppFixture = _fixture()
	fx.image().set_index(1, 1, 9)
	fx.click(&"picker", Vector2i(1, 1))
	assert_int(fx.state.fg).is_equal(9)
	fx.click(&"picker", Vector2i(0, 0), SECONDARY)
	assert_int(fx.state.bg).is_equal(0)
	fx.image().set_index(3, 3, 12)
	fx.click(&"pencil", Vector2i(3, 3), PRIMARY, Tool.MOD_ALT)
	assert_int(fx.state.fg).is_equal(12)
	assert_str(String(fx.controller.get_active_id())).is_equal("pencil")
	assert_bool(fx.bus.history.can_undo()).is_false()


# --- select / move / pickup --------------------------------------------------

func test_rect_select_and_click_clears() -> void:
	var fx: AppFixture = _fixture()
	fx.stroke(&"select", [Vector2i(1, 1), Vector2i(9, 9)])
	assert_that(fx.state.selection).is_equal(Rect2i(1, 1, 5, 3))
	fx.click(&"select", Vector2i(2, 2))
	assert_bool(fx.state.selection.has_area()).is_false()


func test_select_cancel_restores_previous() -> void:
	var fx: AppFixture = _fixture()
	fx.state.set_selection(Rect2i(0, 0, 2, 2))
	fx.controller.activate(&"select")
	fx.controller.press(Vector2i(3, 3), PRIMARY, 0)
	fx.controller.motion(Vector2i(4, 3), 0)
	fx.controller.cancel()
	assert_that(fx.state.selection).is_equal(Rect2i(0, 0, 2, 2))


func test_move_cel_and_undo() -> void:
	var fx: AppFixture = _fixture()
	fx.stroke(&"move", [Vector2i(1, 1), Vector2i(3, 0)])
	assert_that(fx.state.current_cel().offset).is_equal(Vector2i(2, -1))
	assert_str(fx.bus.history.undo_label()).is_equal("Move Cel")
	fx.bus.undo()
	assert_that(fx.state.current_cel().offset).is_equal(Vector2i.ZERO)


func test_move_cel_cancel() -> void:
	var fx: AppFixture = _fixture()
	fx.controller.activate(&"move")
	fx.controller.press(Vector2i(0, 0), PRIMARY, 0)
	fx.controller.motion(Vector2i(2, 2), 0)
	fx.controller.cancel()
	assert_that(fx.state.current_cel().offset).is_equal(Vector2i.ZERO)


func test_brush_pickup_returns_to_previous_tool_in_replace_mode() -> void:
	var fx: AppFixture = _fixture()
	fx.image().set_index(1, 1, 4)
	fx.image().set_index(2, 1, 5)
	fx.controller.activate(&"pencil")
	fx.stroke(&"brush_pickup", [Vector2i(1, 1), Vector2i(2, 2)])
	assert_bool(fx.state.has_custom_brush).is_true()
	assert_that(fx.state.brush.image.to_rows()).is_equal(PackedStringArray(["45", "00"]))
	assert_int(fx.state.draw_mode).is_equal(PrismEnums.DrawMode.REPLACE)
	assert_str(String(fx.controller.get_active_id())).is_equal("pencil")
	assert_bool(fx.state.pickup_rect.has_area()).is_false()
	fx.state.brush.anchor = Vector2i.ZERO
	fx.click(&"pencil", Vector2i(4, 2))
	assert_that(fx.rows()[2]).is_equal("000045")


func test_controller_ignores_second_press_and_unknown_release() -> void:
	var fx: AppFixture = _fixture()
	fx.controller.release(Vector2i.ZERO, 0)
	fx.controller.activate(&"pencil")
	fx.controller.press(Vector2i(0, 0), PRIMARY, 0)
	fx.controller.press(Vector2i(5, 3), SECONDARY, 0)
	fx.controller.release(Vector2i(0, 0), 0)
	assert_int(fx.image().pixels.count(1)).is_equal(1)
	assert_object(fx.controller.get_active()).is_not_null()


func test_tool_changed_signal_and_brush_preview_flags() -> void:
	var fx: AppFixture = _fixture()
	var ids: Array[StringName] = []
	fx.controller.tool_changed.connect(func(id: StringName) -> void: ids.append(id))
	fx.controller.activate(&"line")
	fx.controller.activate(&"line")
	assert_array(ids).is_equal([&"line"])
	assert_bool(fx.controller.tools[&"pencil"].shows_brush_preview()).is_true()
	assert_bool(fx.controller.tools[&"fill"].shows_brush_preview()).is_false()


# --- selection actions -------------------------------------------------------

func test_copy_cut_paste() -> void:
	var fx: AppFixture = _fixture()
	fx.image().set_index(0, 0, 3)
	fx.image().set_index(1, 0, 4)
	assert_bool(fx.selection.copy()).is_false()
	fx.state.set_selection(Rect2i(0, 0, 2, 1))
	assert_bool(fx.selection.cut()).is_true()
	assert_that(fx.rows()[0]).is_equal("000000")
	fx.state.set_selection(Rect2i(3, 2, 1, 1))
	assert_bool(fx.selection.paste()).is_true()
	assert_that(fx.rows()[2]).is_equal("000340")
	assert_that(fx.state.selection).is_equal(Rect2i(3, 2, 2, 1))
	assert_str(fx.bus.history.undo_label()).is_equal("Paste")
	fx.bus.undo()
	fx.bus.undo()
	assert_that(fx.rows()[0]).is_equal("340000")


func test_nudge_moves_pixels() -> void:
	var fx: AppFixture = _fixture()
	fx.image().set_index(1, 1, 6)
	fx.state.set_selection(Rect2i(1, 1, 1, 1))
	assert_bool(fx.selection.nudge(Vector2i(1, 0))).is_true()
	assert_that(fx.rows()[1]).is_equal("006000")
	assert_that(fx.state.selection.position).is_equal(Vector2i(2, 1))
	assert_bool(fx.selection.has_selection()).is_true()
	fx.state.set_selection(Rect2i())
	assert_bool(fx.selection.nudge(Vector2i(1, 0))).is_false()
	assert_bool(fx.selection.paste()).is_false()
