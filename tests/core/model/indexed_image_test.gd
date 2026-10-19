extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func test_new_image_is_zeroed_with_correct_size() -> void:
	var image: IndexedImage = IndexedImage.new(&"I1", 4, 3)
	assert_int(image.pixels.size()).is_equal(12)
	assert_int(image.pixels.count(0)).is_equal(12)


func test_fill_value_in_constructor() -> void:
	var image: IndexedImage = IndexedImage.new(&"I1", 2, 2, 7)
	assert_int(image.pixels.count(7)).is_equal(4)


func test_get_and_set_index_are_row_major() -> void:
	var image: IndexedImage = IndexedImage.new(&"I1", 3, 2)
	image.set_index(2, 1, 9)
	assert_int(image.get_index(2, 1)).is_equal(9)
	assert_int(image.pixels[5]).is_equal(9)


func test_has_point_bounds() -> void:
	var image: IndexedImage = IndexedImage.new(&"I1", 3, 2)
	assert_bool(image.has_point(0, 0)).is_true()
	assert_bool(image.has_point(2, 1)).is_true()
	assert_bool(image.has_point(3, 1)).is_false()
	assert_bool(image.has_point(-1, 0)).is_false()


func test_duplicate_is_independent() -> void:
	var image: IndexedImage = IndexedImage.new(&"I1", 2, 2)
	var copy: IndexedImage = image.duplicate_image(&"I2")
	copy.set_index(0, 0, 5)
	assert_int(image.get_index(0, 0)).is_equal(0)
	assert_str(String(copy.id)).is_equal("I2")


func test_rows_round_trip() -> void:
	var rows: PackedStringArray = ["012", "a0f"]
	var image: IndexedImage = IndexedImage.from_rows(&"I1", rows)
	assert_int(image.get_index(0, 1)).is_equal(10)
	assert_that(image.to_rows()).is_equal(rows)


func test_rect_and_size() -> void:
	var image: IndexedImage = IndexedImage.new(&"I1", 5, 4)
	assert_that(image.get_rect()).is_equal(Rect2i(0, 0, 5, 4))
	assert_that(image.get_size()).is_equal(Vector2i(5, 4))
	image.fill(3)
	assert_int(image.pixels.count(3)).is_equal(20)
