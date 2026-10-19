extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func _image(rows: PackedStringArray) -> IndexedImage:
	return IndexedImage.from_rows(&"t", rows)


# --- write_pixel / rects -----------------------------------------------------

func test_write_pixel_respects_bounds_and_stencil() -> void:
	var image: IndexedImage = _image(["12", "00"])
	var stencil: Stencil = Stencil.new()
	stencil.set_locked(1, true)
	assert_bool(RasterOps.write_pixel(image, 0, 0, 5, stencil)).is_false()
	assert_bool(RasterOps.write_pixel(image, 1, 0, 5, stencil)).is_true()
	assert_bool(RasterOps.write_pixel(image, 1, 0, 5, stencil)).is_false()
	assert_bool(RasterOps.write_pixel(image, 9, 9, 5, null)).is_false()
	assert_that(image.to_rows()).is_equal(PackedStringArray(["15", "00"]))


func test_read_write_rect_round_trip() -> void:
	var image: IndexedImage = _image(["0123", "4567", "89ab"])
	var data: PackedByteArray = RasterOps.read_rect(image, Rect2i(1, 1, 2, 2))
	assert_that(data).is_equal(PackedByteArray([5, 6, 9, 10]))
	data[0] = 0
	assert_int(image.get_index(1, 1)).is_equal(5)
	RasterOps.write_rect(image, Rect2i(2, 0, 2, 2), data)
	assert_that(image.to_rows()).is_equal(PackedStringArray(["0106", "459a", "89ab"]))


# --- lines -------------------------------------------------------------------

func test_line_includes_endpoints_and_is_connected() -> void:
	var points: Array[Vector2i] = RasterOps.line_points(Vector2i(0, 0), Vector2i(7, 3))
	assert_that(points.front()).is_equal(Vector2i(0, 0))
	assert_that(points.back()).is_equal(Vector2i(7, 3))
	assert_int(points.size()).is_equal(8)
	for i: int in range(1, points.size()):
		var step: Vector2i = (points[i] - points[i - 1]).abs()
		assert_bool(step.x <= 1 and step.y <= 1).is_true()


func test_single_point_line() -> void:
	assert_int(RasterOps.line_points(Vector2i(3, 3), Vector2i(3, 3)).size()).is_equal(1)


func test_line_is_reversible() -> void:
	var a: Array[Vector2i] = RasterOps.line_points(Vector2i(1, 1), Vector2i(6, 9))
	var b: Array[Vector2i] = RasterOps.line_points(Vector2i(6, 9), Vector2i(1, 1))
	assert_int(a.size()).is_equal(b.size())


func test_lines_match_golden() -> void:
	var text: String = ""
	for end: Vector2i in [Vector2i(11, 0), Vector2i(11, 5), Vector2i(11, 11), Vector2i(5, 11), Vector2i(3, 10)]:
		text += "to %s\n" % end + Golden.points_text(RasterOps.line_points(Vector2i.ZERO, end), 12, 12)
	assert_str(text).is_equal(Golden.expect("raster/lines", text))


func test_constrain_line_end() -> void:
	var o: Vector2i = Vector2i(10, 10)
	assert_that(RasterOps.constrain_line_end(o, Vector2i(20, 11))).is_equal(Vector2i(20, 10))
	assert_that(RasterOps.constrain_line_end(o, Vector2i(18, 17))).is_equal(Vector2i(18, 18))
	assert_that(RasterOps.constrain_line_end(o, Vector2i(20, 15))).is_equal(Vector2i(20, 15))
	assert_that(RasterOps.constrain_line_end(o, Vector2i(9, 2))).is_equal(Vector2i(10, 2))
	assert_that(RasterOps.constrain_line_end(o, Vector2i(5, 0))).is_equal(Vector2i(5, 0))
	assert_that(RasterOps.constrain_line_end(o, o)).is_equal(o)


# --- rect / ellipse ----------------------------------------------------------

func test_rect_points() -> void:
	assert_int(RasterOps.rect_points(Rect2i(0, 0, 4, 3), false).size()).is_equal(10)
	assert_int(RasterOps.rect_points(Rect2i(0, 0, 4, 3), true).size()).is_equal(12)
	assert_int(RasterOps.rect_points(Rect2i(2, 2, 1, 1), false).size()).is_equal(1)


func test_ellipses_match_golden() -> void:
	var text: String = ""
	for size: Vector2i in [Vector2i(1, 1), Vector2i(2, 2), Vector2i(5, 5), Vector2i(8, 8), Vector2i(11, 7), Vector2i(16, 5), Vector2i(3, 12)]:
		for filled: bool in [false, true]:
			var points: Array[Vector2i] = RasterOps.ellipse_points(Rect2i(Vector2i.ZERO, size), filled)
			text += "%dx%d %s\n" % [size.x, size.y, "filled" if filled else "outline"]
			text += Golden.points_text(points, size.x, size.y)
	assert_str(text).is_equal(Golden.expect("raster/ellipses", text))


func test_ellipses_are_symmetric_and_touch_their_box() -> void:
	for w: int in range(1, 20):
		for h: int in range(1, 20):
			for filled: bool in [false, true]:
				var image: IndexedImage = IndexedImage.new(&"e", w, h)
				for p: Vector2i in RasterOps.ellipse_points(Rect2i(0, 0, w, h), filled):
					image.set_index(p.x, p.y, 1)
				assert_that(RasterOps.flipped_h(image).pixels).is_equal(image.pixels)
				assert_that(RasterOps.flipped_v(image).pixels).is_equal(image.pixels)
				var rows: PackedStringArray = image.to_rows()
				assert_bool(rows[0].contains("1") and rows[h - 1].contains("1")).is_true()
				var left: bool = false
				for row: String in rows:
					left = left or row.begins_with("1")
				assert_bool(left).is_true()


# --- pixel perfect -----------------------------------------------------------

func test_pixel_perfect_removes_l_corners() -> void:
	var points: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)]
	var expected: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 2)]
	assert_array(RasterOps.pixel_perfect(points)).is_equal(expected)


func test_pixel_perfect_keeps_straight_lines_and_dedupes() -> void:
	var points: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var expected: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	assert_array(RasterOps.pixel_perfect(points)).is_equal(expected)


# --- fills -------------------------------------------------------------------

func test_flood_fill_is_four_way() -> void:
	var image: IndexedImage = _image([
		"00100",
		"00100",
		"11011",
		"00100",
	])
	var dirty: Rect2i = RasterOps.flood_fill(image, Vector2i(0, 0), 2, null)
	assert_that(image.to_rows()).is_equal(PackedStringArray(["22100", "22100", "11011", "00100"]))
	assert_that(dirty).is_equal(Rect2i(0, 0, 2, 2))


func test_flood_fill_handles_concave_shapes() -> void:
	var image: IndexedImage = _image([
		"0000000",
		"0111110",
		"0100010",
		"0101010",
		"0001000",
	])
	RasterOps.flood_fill(image, Vector2i(2, 2), 3, null)
	assert_that(image.to_rows()).is_equal(PackedStringArray([
		"3333333",
		"3111113",
		"3133313",
		"3131313",
		"3331333",
	]))


func test_flood_fill_noop_cases() -> void:
	var image: IndexedImage = _image(["11", "11"])
	assert_bool(RasterOps.flood_fill(image, Vector2i(0, 0), 1, null).has_area()).is_false()
	assert_bool(RasterOps.flood_fill(image, Vector2i(5, 0), 2, null).has_area()).is_false()
	var stencil: Stencil = Stencil.new()
	stencil.set_locked(1, true)
	assert_bool(RasterOps.flood_fill(image, Vector2i(0, 0), 2, stencil).has_area()).is_false()
	assert_int(image.pixels.count(1)).is_equal(4)


func test_replace_index_is_global() -> void:
	var image: IndexedImage = _image(["1001", "0000", "0010"])
	var dirty: Rect2i = RasterOps.replace_index(image, 1, 4, null)
	assert_that(image.to_rows()).is_equal(PackedStringArray(["4004", "0000", "0040"]))
	assert_that(dirty).is_equal(Rect2i(0, 0, 4, 3))
	var stencil: Stencil = Stencil.new()
	stencil.set_locked(4, true)
	assert_bool(RasterOps.replace_index(image, 4, 2, stencil).has_area()).is_false()


func test_backend_delegates() -> void:
	var backend: RasterBackend = GDScriptRasterBackend.new()
	var image: IndexedImage = _image(["00", "01"])
	assert_that(backend.flood_fill(image, Vector2i.ZERO, 2, null)).is_equal(Rect2i(0, 0, 2, 2))
	assert_that(backend.replace_index(image, 1, 3, null)).is_equal(Rect2i(1, 1, 1, 1))
	assert_that(image.to_rows()).is_equal(PackedStringArray(["22", "23"]))


# --- blit / copy / transforms -----------------------------------------------

func test_blit_skips_transparent_and_locked_and_clips() -> void:
	var dst: IndexedImage = _image(["000", "050", "000"])
	var src: IndexedImage = _image(["12", "30"])
	var stencil: Stencil = Stencil.new()
	stencil.set_locked(5, true)
	var dirty: Rect2i = RasterOps.blit(dst, src, Vector2i(1, 1), 0, stencil)
	assert_that(dst.to_rows()).is_equal(PackedStringArray(["000", "052", "030"]))
	assert_that(dirty).is_equal(Rect2i(1, 1, 2, 2))
	assert_bool(RasterOps.blit(dst, src, Vector2i(5, 5), 0, null).has_area()).is_false()


func test_copy_region_clips() -> void:
	var image: IndexedImage = _image(["123", "456"])
	var region: IndexedImage = RasterOps.copy_region(image, Rect2i(1, 0, 5, 5), &"b")
	assert_that(region.to_rows()).is_equal(PackedStringArray(["23", "56"]))


func test_flips_and_rotation() -> void:
	var image: IndexedImage = _image(["123", "456"])
	assert_that(RasterOps.flipped_h(image).to_rows()).is_equal(PackedStringArray(["321", "654"]))
	assert_that(RasterOps.flipped_v(image).to_rows()).is_equal(PackedStringArray(["456", "123"]))
	assert_that(RasterOps.rotated_90_cw(image).to_rows()).is_equal(PackedStringArray(["41", "52", "63"]))
	var full_turn: IndexedImage = image
	for i: int in 4:
		full_turn = RasterOps.rotated_90_cw(full_turn)
	assert_that(full_turn.pixels).is_equal(image.pixels)
