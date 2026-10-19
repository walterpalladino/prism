extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self

const PRIMARY: PrismEnums.PaintButton = PrismEnums.PaintButton.PRIMARY
const SECONDARY: PrismEnums.PaintButton = PrismEnums.PaintButton.SECONDARY


func _ctx(button: PrismEnums.PaintButton) -> InkContext:
	var palette: Palette = PalettePresets.grayscale(8)
	palette.remove_ramp(0)
	palette.add_ramp(2, 5)
	return InkContext.new(3, 7, button, palette)


func test_context_button_mapping() -> void:
	assert_int(_ctx(PRIMARY).paint_index()).is_equal(3)
	assert_int(_ctx(SECONDARY).paint_index()).is_equal(7)
	assert_int(_ctx(PRIMARY).direction()).is_equal(1)
	assert_int(_ctx(SECONDARY).direction()).is_equal(-1)


func test_color_ink_paints_fg_or_bg() -> void:
	var ink: Ink = ColorInk.new()
	assert_int(ink.apply(0, 9, false, _ctx(PRIMARY))).is_equal(3)
	assert_int(ink.apply(0, 9, false, _ctx(SECONDARY))).is_equal(7)


func test_replace_ink_copies_custom_brush_pixels() -> void:
	var ink: Ink = ReplaceInk.new()
	assert_int(ink.apply(0, 6, false, _ctx(PRIMARY))).is_equal(6)
	assert_int(ink.apply(0, 1, true, _ctx(SECONDARY))).is_equal(7)


func test_shade_ink_steps_within_ramp_and_clamps() -> void:
	var ink: Ink = ShadeInk.new()
	assert_int(ink.apply(3, 1, true, _ctx(PRIMARY))).is_equal(4)
	assert_int(ink.apply(3, 1, true, _ctx(SECONDARY))).is_equal(2)
	assert_int(ink.apply(5, 1, true, _ctx(PRIMARY))).is_equal(Ink.SKIP)
	assert_int(ink.apply(2, 1, true, _ctx(SECONDARY))).is_equal(Ink.SKIP)
	assert_int(ink.apply(7, 1, true, _ctx(PRIMARY))).is_equal(Ink.SKIP)


func test_shade_ink_wraps_when_enabled() -> void:
	var ink: Ink = ShadeInk.new()
	var ctx: InkContext = _ctx(PRIMARY)
	ctx.shade_wrap = true
	assert_int(ink.apply(5, 1, true, ctx)).is_equal(2)
	ctx.button = SECONDARY
	assert_int(ink.apply(2, 1, true, ctx)).is_equal(5)


func test_for_mode() -> void:
	assert_bool(Ink.for_mode(PrismEnums.DrawMode.COLOR) is ColorInk).is_true()
	assert_bool(Ink.for_mode(PrismEnums.DrawMode.REPLACE) is ReplaceInk).is_true()
	assert_bool(Ink.for_mode(PrismEnums.DrawMode.SHADE) is ShadeInk).is_true()
