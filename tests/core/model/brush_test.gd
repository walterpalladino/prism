extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func test_builtin_square_is_solid_mask() -> void:
	var brush: Brush = Brush.builtin(Brush.Shape.SQUARE, 3)
	assert_bool(brush.is_mask).is_true()
	assert_int(brush.image.pixels.count(Brush.MASK_VALUE)).is_equal(9)
	assert_that(brush.anchor).is_equal(Vector2i(1, 1))


func test_builtin_anchor_rounds_down_for_even_sizes() -> void:
	assert_that(Brush.builtin(Brush.Shape.SQUARE, 4).anchor).is_equal(Vector2i(1, 1))
	assert_that(Brush.builtin(Brush.Shape.SQUARE, 1).anchor).is_equal(Vector2i(0, 0))


func test_builtin_round_brushes_match_golden() -> void:
	var text: String = ""
	for size: int in range(1, Brush.MAX_BUILTIN_SIZE + 1):
		text += "size %d\n" % size + Golden.image_text(Brush.builtin(Brush.Shape.ROUND, size).image)
	assert_str(text).is_equal(Golden.expect("brush/round_1_to_8", text))


func test_round_brushes_are_symmetric() -> void:
	for size: int in range(1, Brush.MAX_BUILTIN_SIZE + 1):
		var image: IndexedImage = Brush.builtin(Brush.Shape.ROUND, size).image
		assert_that(RasterOps.flipped_h(image).pixels).is_equal(image.pixels)
		assert_that(RasterOps.flipped_v(image).pixels).is_equal(image.pixels)


func test_from_image_keeps_pixels() -> void:
	var image: IndexedImage = IndexedImage.from_rows(&"b", ["120", "003"])
	var brush: Brush = Brush.from_image(image, 0)
	assert_bool(brush.is_mask).is_false()
	assert_that(brush.anchor).is_equal(Vector2i(1, 0))


func test_flip_and_rotate_move_anchor() -> void:
	var image: IndexedImage = IndexedImage.from_rows(&"b", ["1200", "0003"])
	var brush: Brush = Brush.new(image, Vector2i(0, 0), 0, false)
	var flipped: Brush = brush.flipped_h()
	assert_that(flipped.image.to_rows()).is_equal(PackedStringArray(["0021", "3000"]))
	assert_that(flipped.anchor).is_equal(Vector2i(3, 0))
	assert_that(brush.flipped_v().anchor).is_equal(Vector2i(0, 1))
	var rotated: Brush = brush.rotated_90()
	assert_that(rotated.get_size()).is_equal(Vector2i(2, 4))
	assert_that(rotated.image.to_rows()).is_equal(PackedStringArray(["01", "02", "00", "30"]))
	assert_that(rotated.anchor).is_equal(Vector2i(1, 0))
