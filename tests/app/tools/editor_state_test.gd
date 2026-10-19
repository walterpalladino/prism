extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func test_fg_bg_stepping_wraps() -> void:
	var fx: AppFixture = AppFixture.new()
	fx.state.set_fg(0)
	fx.state.step_fg(-1)
	assert_int(fx.state.fg).is_equal(31)
	fx.state.step_fg(1)
	assert_int(fx.state.fg).is_equal(0)
	fx.state.set_bg(31)
	fx.state.step_bg(1)
	assert_int(fx.state.bg).is_equal(0)
	fx.state.set_fg(99)
	assert_int(fx.state.fg).is_equal(31)


func test_changed_signal() -> void:
	var fx: AppFixture = AppFixture.new()
	var count: Array[int] = [0]
	fx.state.changed.connect(func() -> void: count[0] += 1)
	fx.state.set_fg(3)
	fx.state.set_draw_mode(PrismEnums.DrawMode.SHADE)
	assert_int(count[0]).is_equal(2)


func test_brush_management() -> void:
	var fx: AppFixture = AppFixture.new()
	fx.state.set_builtin_brush(Brush.Shape.SQUARE, 12)
	assert_int(fx.state.builtin_size).is_equal(Brush.MAX_BUILTIN_SIZE)
	assert_that(fx.state.brush.get_size()).is_equal(Vector2i(8, 8))
	var custom: Brush = Brush.from_image(IndexedImage.from_rows(&"b", ["120", "000"]), 0)
	fx.state.set_custom_brush(custom)
	assert_bool(fx.state.has_custom_brush).is_true()
	fx.state.flip_brush_h()
	assert_that(fx.state.brush.image.to_rows()).is_equal(PackedStringArray(["021", "000"]))
	fx.state.flip_brush_v()
	assert_that(fx.state.brush.image.to_rows()).is_equal(PackedStringArray(["000", "021"]))
	fx.state.rotate_brush()
	assert_that(fx.state.brush.get_size()).is_equal(Vector2i(2, 3))
	fx.state.restore_builtin_brush()
	assert_bool(fx.state.has_custom_brush).is_false()
	assert_that(fx.state.brush.get_size()).is_equal(Vector2i(8, 8))


func test_ink_context_uses_state() -> void:
	var fx: AppFixture = AppFixture.new()
	fx.state.set_fg(4)
	fx.state.set_bg(9)
	fx.state.shade_wrap = true
	var ctx: InkContext = fx.state.make_ink_context(AppFixture.SECONDARY)
	assert_int(ctx.paint_index()).is_equal(9)
	assert_bool(ctx.shade_wrap).is_true()


func test_editable_image_respects_layer_flags() -> void:
	var fx: AppFixture = AppFixture.new()
	assert_object(fx.state.editable_image()).is_not_null()
	fx.bus.document.layers[0].locked = true
	assert_object(fx.state.editable_image()).is_null()
	fx.bus.document.layers[0].locked = false
	fx.bus.document.layers[0].visible = false
	assert_object(fx.state.editable_image()).is_null()
	fx.state.layer_index = 5
	assert_object(fx.state.editable_image()).is_null()


func test_coordinates_and_index_lookup() -> void:
	var fx: AppFixture = AppFixture.new()
	fx.state.current_cel().offset = Vector2i(2, 1)
	assert_that(fx.state.to_image_space(Vector2i(3, 3))).is_equal(Vector2i(1, 2))
	assert_that(fx.state.current_cel_key()).is_equal(Vector2i(0, 0))
	fx.image().set_index(1, 2, 7)
	assert_int(fx.state.index_at(Vector2i(3, 3))).is_equal(7)
	assert_int(fx.state.index_at(Vector2i(0, 0))).is_equal(0)


func test_selection_and_pickup_rects() -> void:
	var fx: AppFixture = AppFixture.new()
	fx.state.set_selection(Rect2i(1, 1, 2, 2))
	fx.state.set_pickup_rect(Rect2i(0, 0, 1, 1))
	assert_that(fx.state.selection).is_equal(Rect2i(1, 1, 2, 2))
	assert_that(fx.state.pickup_rect).is_equal(Rect2i(0, 0, 1, 1))
	assert_int(fx.state.palette_size()).is_equal(32)


func test_frame_navigation_and_selection() -> void:
	var fx: AppFixture = AppFixture.new()
	fx.timeline.insert_frame(1)
	fx.timeline.insert_frame(2)
	var shown: Array[int] = []
	Signals.on(fx.state.frame_changed, func(i: int) -> void: shown.append(i))
	fx.state.set_frame(0)
	fx.state.set_frame_range(2, 1)
	assert_that(fx.state.frame_range).is_equal(Vector2i(1, 2))
	fx.state.show_frame(1)
	assert_int(fx.state.frame_index).is_equal(1)
	assert_that(fx.state.frame_range).is_equal(Vector2i(1, 2))
	fx.state.set_frame(9)
	assert_int(fx.state.frame_index).is_equal(2)
	assert_that(fx.state.frame_range).is_equal(Vector2i(2, 2))
	assert_array(shown).is_equal([0, 1, 2])


func test_clamp_to_document() -> void:
	var fx: AppFixture = AppFixture.new()
	fx.state.frame_index = 5
	fx.state.layer_index = 3
	fx.state.frame_range = Vector2i(4, 6)
	fx.state.clamp_to_document()
	assert_int(fx.state.frame_index).is_equal(0)
	assert_int(fx.state.layer_index).is_equal(0)
	assert_that(fx.state.frame_range).is_equal(Vector2i.ZERO)
