extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func _gray(count: int) -> Palette:
	return PalettePresets.grayscale(count)


func test_get_set_color() -> void:
	var palette: Palette = Palette.from_hex(["#000000", "#ffffff"])
	assert_int(palette.size()).is_equal(2)
	palette.set_color(1, Color.RED)
	assert_that(palette.get_color(1)).is_equal(Color.RED)
	assert_bool(palette.has_index(1)).is_true()
	assert_bool(palette.has_index(2)).is_false()


func test_constructor_copies_colors() -> void:
	var colors: PackedColorArray = [Color.BLACK]
	var palette: Palette = Palette.new(colors)
	colors[0] = Color.WHITE
	assert_that(palette.get_color(0)).is_equal(Color.BLACK)


func test_add_ramp_rejects_overlap_and_bad_ranges() -> void:
	var palette: Palette = Palette.new(PackedColorArray())
	palette.colors.resize(16)
	assert_bool(palette.add_ramp(2, 5)).is_true()
	assert_bool(palette.add_ramp(5, 8)).is_false()
	assert_bool(palette.add_ramp(0, 2)).is_false()
	assert_bool(palette.add_ramp(6, 6)).is_false()
	assert_bool(palette.add_ramp(10, 16)).is_false()
	assert_bool(palette.add_ramp(6, 9)).is_true()


func test_ramps_stay_sorted() -> void:
	var palette: Palette = Palette.new(PackedColorArray())
	palette.colors.resize(16)
	palette.add_ramp(10, 12)
	palette.add_ramp(1, 3)
	assert_that(palette.ramps[0]).is_equal(Vector2i(1, 3))


func test_find_and_remove_ramp() -> void:
	var palette: Palette = Palette.new(PackedColorArray())
	palette.colors.resize(16)
	palette.add_ramp(4, 7)
	assert_that(palette.find_ramp(5)).is_equal(Vector2i(4, 7))
	assert_that(palette.find_ramp(8)).is_equal(Palette.NO_RAMP)
	assert_bool(palette.remove_ramp(4)).is_true()
	assert_bool(palette.remove_ramp(4)).is_false()
	assert_that(palette.find_ramp(5)).is_equal(Palette.NO_RAMP)


func test_duplicate_is_independent() -> void:
	var palette: Palette = _gray(4)
	var copy: Palette = palette.duplicate_palette()
	copy.set_color(0, Color.RED)
	copy.remove_ramp(0)
	assert_that(palette.get_color(0)).is_equal(Color.BLACK)
	assert_int(palette.ramps.size()).is_equal(1)


func test_presets() -> void:
	var default_palette: Palette = PalettePresets.default_32()
	assert_int(default_palette.size()).is_equal(32)
	assert_that(default_palette.find_ramp(17)).is_equal(Vector2i(16, 21))
	assert_int(PalettePresets.pico8_style_16().size()).is_equal(16)
	assert_int(PalettePresets.ega_16().size()).is_equal(16)
	var gray: Palette = _gray(8)
	assert_that(gray.get_color(0)).is_equal(Color.BLACK)
	assert_that(gray.get_color(7)).is_equal(Color.WHITE)
	assert_that(gray.find_ramp(3)).is_equal(Vector2i(0, 7))
