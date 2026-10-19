extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func _fx(rows: PackedStringArray) -> AppFixture:
	var fx: AppFixture = AppFixture.new(rows[0].length(), rows.size())
	fx.image().pixels = IndexedImage.from_rows(&"x", rows).pixels
	return fx


func test_flips_are_undoable() -> void:
	var fx: AppFixture = _fx(["120", "300"])
	var effects: CelEffects = CelEffects.new(fx.bus, fx.state)
	assert_str(effects.flip_horizontal()).is_empty()
	assert_that(fx.rows()).is_equal(PackedStringArray(["021", "003"]))
	effects.flip_vertical()
	assert_that(fx.rows()).is_equal(PackedStringArray(["003", "021"]))
	fx.bus.undo()
	fx.bus.undo()
	assert_that(fx.rows()).is_equal(PackedStringArray(["120", "300"]))


func test_rotate_90_on_a_square_canvas_is_exact() -> void:
	var fx: AppFixture = _fx(["120", "000", "003"])
	var effects: CelEffects = CelEffects.new(fx.bus, fx.state)
	assert_str(effects.rotate_90(true)).is_empty()
	assert_that(fx.rows()).is_equal(PackedStringArray(["001", "002", "300"]))
	assert_str(fx.bus.history.undo_label()).is_equal("Rotate Cel 90° CW")
	effects.rotate_90(false)
	assert_that(fx.rows()).is_equal(PackedStringArray(["120", "000", "003"]))
	for i: int in 4:
		effects.rotate_90(true)
	assert_that(fx.rows()).is_equal(PackedStringArray(["120", "000", "003"]))
	effects.rotate_90(false)
	assert_that(fx.rows()).is_equal(PackedStringArray(["003", "200", "100"]))
	assert_str(fx.bus.history.undo_label()).is_equal("Rotate Cel 90° CCW")


func test_rotate_90_on_a_wide_canvas_cuts_off_and_reports() -> void:
	var fx: AppFixture = _fx(["100004", "000000"])
	var effects: CelEffects = CelEffects.new(fx.bus, fx.state)
	var message: String = effects.rotate_90(true)
	assert_str(message).contains("2 pixels fell outside the 6×2 canvas")
	assert_int(fx.image().pixels.count(0)).is_equal(12)
	fx.bus.undo()
	assert_that(fx.rows()).is_equal(PackedStringArray(["100004", "000000"]))
	var center: AppFixture = _fx(["000000", "001100"])
	assert_str(CelEffects.new(center.bus, center.state).rotate_90(true)).is_empty()
	assert_int(center.image().pixels.count(1)).is_equal(2)


func test_rotated_position_maps_corners() -> void:
	assert_that(CelEffects.rotated_position(Vector2i(0, 0), Vector2i(3, 3), true)).is_equal(Vector2i(2, 0))
	assert_that(CelEffects.rotated_position(Vector2i(2, 0), Vector2i(3, 3), true)).is_equal(Vector2i(2, 2))
	assert_that(CelEffects.rotated_position(Vector2i(0, 0), Vector2i(3, 3), false)).is_equal(Vector2i(0, 2))
	assert_that(CelEffects.rotated_position(Vector2i(1, 1), Vector2i(4, 4), true)).is_equal(Vector2i(2, 1))


func test_outline_with_fg() -> void:
	var fx: AppFixture = _fx(["00000", "00300", "00000"])
	fx.state.set_fg(7)
	CelEffects.new(fx.bus, fx.state).outline_with_fg()
	assert_that(fx.rows()).is_equal(PackedStringArray(["00700", "07370", "00700"]))


func test_replace_fg_with_bg_respects_stencil() -> void:
	var fx: AppFixture = _fx(["3300", "0033"])
	fx.state.set_fg(3)
	fx.state.set_bg(5)
	CelEffects.new(fx.bus, fx.state).replace_fg_with_bg()
	assert_that(fx.rows()).is_equal(PackedStringArray(["5500", "0055"]))
	var locked: AppFixture = _fx(["3300", "0033"])
	locked.state.set_fg(3)
	locked.bus.document.stencil.set_locked(3, true)
	CelEffects.new(locked.bus, locked.state).replace_fg_with_bg()
	assert_bool(locked.bus.history.can_undo()).is_false()


func test_locked_layer_and_select_all() -> void:
	var fx: AppFixture = _fx(["12", "34"])
	var effects: CelEffects = CelEffects.new(fx.bus, fx.state)
	fx.bus.document.layers[0].locked = true
	for message: String in [effects.flip_horizontal(), effects.outline_with_fg(), effects.replace_fg_with_bg()]:
		assert_str(message).contains("locked")
	effects.select_all()
	assert_that(fx.state.selection).is_equal(Rect2i(0, 0, 2, 2))
