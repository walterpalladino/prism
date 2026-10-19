extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func _painter(image: IndexedImage, brush: Brush, mode: PrismEnums.DrawMode, stencil: Stencil = null,
		button: PrismEnums.PaintButton = PrismEnums.PaintButton.PRIMARY) -> Painter:
	var ctx: InkContext = InkContext.new(1, 2, button, PalettePresets.grayscale(8))
	return Painter.new(image, brush, Ink.for_mode(mode), ctx, stencil)


func test_stamp_centers_brush_on_anchor() -> void:
	var image: IndexedImage = IndexedImage.new(&"c", 5, 5)
	var painter: Painter = _painter(image, Brush.builtin(Brush.Shape.SQUARE, 3), PrismEnums.DrawMode.COLOR)
	assert_bool(painter.stamp(Vector2i(2, 2))).is_true()
	assert_that(image.to_rows()).is_equal(PackedStringArray(["00000", "01110", "01110", "01110", "00000"]))
	assert_that(painter.dirty).is_equal(Rect2i(1, 1, 3, 3))


func test_stamp_clips_at_edges() -> void:
	var image: IndexedImage = IndexedImage.new(&"c", 3, 3)
	var painter: Painter = _painter(image, Brush.builtin(Brush.Shape.SQUARE, 3), PrismEnums.DrawMode.COLOR)
	painter.stamp(Vector2i(0, 0))
	assert_that(image.to_rows()).is_equal(PackedStringArray(["110", "110", "000"]))
	assert_bool(painter.stamp(Vector2i(10, 10))).is_false()


func test_secondary_button_paints_bg() -> void:
	var image: IndexedImage = IndexedImage.new(&"c", 2, 1)
	var painter: Painter = _painter(image, Brush.builtin(Brush.Shape.SQUARE, 1), PrismEnums.DrawMode.COLOR, null, PrismEnums.PaintButton.SECONDARY)
	painter.stamp(Vector2i(1, 0))
	assert_that(image.to_rows()).is_equal(PackedStringArray(["02"]))


func test_stencil_blocks_locked_destinations() -> void:
	var image: IndexedImage = IndexedImage.from_rows(&"c", ["030", "333", "030"])
	var stencil: Stencil = Stencil.new()
	stencil.set_locked(3, true)
	var painter: Painter = _painter(image, Brush.builtin(Brush.Shape.SQUARE, 3), PrismEnums.DrawMode.COLOR, stencil)
	painter.stamp(Vector2i(1, 1))
	assert_that(image.to_rows()).is_equal(PackedStringArray(["131", "333", "131"]))


func test_custom_brush_transparency_in_color_and_replace() -> void:
	var brush_image: IndexedImage = IndexedImage.from_rows(&"b", ["50", "05"])
	var brush: Brush = Brush.new(brush_image, Vector2i.ZERO, 0, false)
	var a: IndexedImage = IndexedImage.from_rows(&"c", ["77", "77"])
	_painter(a, brush, PrismEnums.DrawMode.COLOR).stamp(Vector2i.ZERO)
	assert_that(a.to_rows()).is_equal(PackedStringArray(["17", "71"]))
	var b: IndexedImage = IndexedImage.from_rows(&"c", ["77", "77"])
	_painter(b, brush, PrismEnums.DrawMode.REPLACE).stamp(Vector2i.ZERO)
	assert_that(b.to_rows()).is_equal(PackedStringArray(["57", "75"]))


func test_each_pixel_changes_at_most_once_per_stroke() -> void:
	var image: IndexedImage = IndexedImage.new(&"c", 5, 1, 2)
	var painter: Painter = _painter(image, Brush.builtin(Brush.Shape.SQUARE, 3), PrismEnums.DrawMode.SHADE)
	var points: Array[Vector2i] = RasterOps.line_points(Vector2i(0, 0), Vector2i(4, 0))
	painter.stamp_points(points)
	assert_that(image.to_rows()).is_equal(PackedStringArray(["33333"]))
	var second: Painter = _painter(image, Brush.builtin(Brush.Shape.SQUARE, 1), PrismEnums.DrawMode.SHADE)
	second.stamp_points(points)
	assert_that(image.to_rows()).is_equal(PackedStringArray(["44444"]))


func test_shapes_through_painter_match_golden() -> void:
	var image: IndexedImage = IndexedImage.new(&"c", 16, 12)
	var painter: Painter = _painter(image, Brush.builtin(Brush.Shape.ROUND, 3), PrismEnums.DrawMode.COLOR)
	painter.stamp_points(RasterOps.ellipse_points(Rect2i(2, 2, 12, 8), false))
	assert_str(Golden.image_text(image)).is_equal(Golden.expect("raster/painter_round3_ellipse", Golden.image_text(image)))
