extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func _expect_error(result: PaletteResult, fragment: String) -> void:
	assert_bool(result.is_ok()).is_false()
	assert_object(result.palette).is_null()
	assert_str(result.error).contains(fragment)


# --- .gpl --------------------------------------------------------------------

func test_gpl_round_trip() -> void:
	var palette: Palette = PalettePresets.default_32()
	var result: PaletteResult = PaletteCodecs.decode_gpl(PaletteCodecs.encode_gpl(palette, "PRISM"))
	assert_bool(result.is_ok()).is_true()
	assert_int(result.palette.size()).is_equal(32)
	for i: int in 32:
		assert_str(result.palette.get_color(i).to_html(false)).is_equal(palette.get_color(i).to_html(false))


func test_gpl_accepts_comments_names_tabs_and_crlf() -> void:
	var text: String = "GIMP Palette\r\nName: Test\r\nColumns: 4\r\n# comment\r\n\r\n255   0   0\tRed\r\n0\t255\t0 Green\r\n  0   0 255\r\n"
	var result: PaletteResult = PaletteCodecs.decode_gpl(text)
	assert_bool(result.is_ok()).is_true()
	assert_int(result.palette.size()).is_equal(3)
	assert_that(result.palette.get_color(1)).is_equal(Color8(0, 255, 0))


func test_gpl_malformed() -> void:
	_expect_error(PaletteCodecs.decode_gpl(""), "header")
	_expect_error(PaletteCodecs.decode_gpl("JASC-PAL\n0100\n"), "header")
	_expect_error(PaletteCodecs.decode_gpl("GIMP Palette\n10 20\n"), "line 2")
	_expect_error(PaletteCodecs.decode_gpl("GIMP Palette\n10 20 300\n"), "0-255")
	_expect_error(PaletteCodecs.decode_gpl("GIMP Palette\n10 x 30\n"), "'x'")
	_expect_error(PaletteCodecs.decode_gpl("GIMP Palette\n# only comments\n"), "no colors")
	var lines: PackedStringArray = ["GIMP Palette"]
	for i: int in 257:
		lines.append("1 2 3")
	_expect_error(PaletteCodecs.decode_gpl("\n".join(lines)), "max 256")


# --- .hex --------------------------------------------------------------------

func test_hex_round_trip() -> void:
	var palette: Palette = PalettePresets.pico8_style_16()
	var result: PaletteResult = PaletteCodecs.decode_hex(PaletteCodecs.encode_hex(palette))
	assert_int(result.palette.size()).is_equal(16)
	assert_str(result.palette.get_color(8).to_html(false)).is_equal("ff004d")


func test_hex_accepts_hash_and_blank_lines() -> void:
	var result: PaletteResult = PaletteCodecs.decode_hex("#ff0000\n\n00FF00\r\n")
	assert_int(result.palette.size()).is_equal(2)


func test_hex_malformed() -> void:
	_expect_error(PaletteCodecs.decode_hex(""), "no colors")
	_expect_error(PaletteCodecs.decode_hex("ff00\n"), "line 1")
	_expect_error(PaletteCodecs.decode_hex("ff0000\nzz0000\n"), "line 2")
	_expect_error(PaletteCodecs.decode_hex("ff0000ff\n"), "RRGGBB")


# --- PNG ---------------------------------------------------------------------

func test_png_strip_round_trip() -> void:
	var palette: Palette = PalettePresets.ega_16()
	var bytes: PackedByteArray = PaletteCodecs.encode_png_image(palette).save_png_to_buffer()
	var result: PaletteResult = PaletteCodecs.decode_png(bytes)
	assert_int(result.palette.size()).is_equal(16)
	assert_str(result.palette.get_color(4).to_html(false)).is_equal("aa0000")


func test_png_skips_transparent_and_duplicate_pixels() -> void:
	var image: Image = Image.create_empty(4, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	image.set_pixel(0, 0, Color.RED)
	image.set_pixel(1, 0, Color.RED)
	image.set_pixel(3, 1, Color(0, 0, 1, 0.5))
	var result: PaletteResult = PaletteCodecs.decode_png_image(image)
	assert_int(result.palette.size()).is_equal(2)
	assert_float(result.palette.get_color(1).a).is_equal(1.0)


func test_png_malformed() -> void:
	_expect_error(PaletteCodecs.decode_png(PackedByteArray()), "PNG")
	_expect_error(PaletteCodecs.decode_png(PackedByteArray([1, 2, 3, 4])), "PNG")
	_expect_error(PaletteCodecs.decode_png_image(null), "empty")
	var blank: Image = Image.create_empty(2, 2, false, Image.FORMAT_RGBA8)
	_expect_error(PaletteCodecs.decode_png_image(blank), "no colors")
	var many: Image = Image.create_empty(300, 1, false, Image.FORMAT_RGBA8)
	for x: int in 300:
		many.set_pixel(x, 0, Color8(x % 256, x >> 8, 7))
	_expect_error(PaletteCodecs.decode_png_image(many), "more than 256")


func test_result_helpers() -> void:
	assert_bool(PaletteResult.ok(Palette.new([Color.RED])).is_ok()).is_true()
	assert_bool(PaletteResult.fail("x").is_ok()).is_false()
