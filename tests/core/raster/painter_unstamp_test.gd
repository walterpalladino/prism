extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func test_unstamp_restores_and_allows_repaint() -> void:
	var image: IndexedImage = IndexedImage.from_rows(&"c", ["050"])
	var snapshot: IndexedImage = image.duplicate_image(&"c")
	var ctx: InkContext = InkContext.new(1, 0, PrismEnums.PaintButton.PRIMARY, PalettePresets.grayscale(8))
	var painter: Painter = Painter.new(image, Brush.builtin(Brush.Shape.SQUARE, 1), ColorInk.new(), ctx, null)
	painter.stamp(Vector2i(1, 0))
	assert_that(image.to_rows()[0]).is_equal("010")
	painter.unstamp(Vector2i(1, 0), snapshot)
	assert_that(image.to_rows()[0]).is_equal("050")
	assert_bool(painter.stamp(Vector2i(1, 0))).is_true()
	painter.unstamp(Vector2i(9, 9), snapshot)
