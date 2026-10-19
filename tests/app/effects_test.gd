extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func _fx(rows: PackedStringArray) -> AppFixture:
	var fx: AppFixture = AppFixture.new(rows[0].length(), rows.size())
	fx.image().pixels = IndexedImage.from_rows(&"x", rows).pixels
	return fx


func test_flips_and_rotate_are_undoable() -> void:
	var fx: AppFixture = _fx(["120", "300"])
	var effects: CelEffects = CelEffects.new(fx.bus, fx.state)
	assert_str(effects.flip_horizontal()).is_empty()
	assert_that(fx.rows()).is_equal(PackedStringArray(["021", "003"]))
	effects.flip_vertical()
	assert_that(fx.rows()).is_equal(PackedStringArray(["003", "021"]))
	fx.bus.undo()
	fx.bus.undo()
	effects.rotate_180()
	assert_that(fx.rows()).is_equal(PackedStringArray(["003", "021"]))
	assert_str(fx.bus.history.undo_label()).is_equal("Rotate Cel 180°")


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
