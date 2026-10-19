extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func test_pixel_patch_apply_and_revert() -> void:
	var doc: PrismDocument = PrismDocument.create(4, 2)
	var image: IndexedImage = doc.get_cel_image(0, 0)
	var patch: PixelPatch = PixelPatch.new(image.id, Rect2i(1, 0, 2, 2), PackedByteArray([0, 0, 0, 0]), PackedByteArray([1, 2, 3, 4]), "Test")
	patch.apply(doc)
	assert_that(image.to_rows()).is_equal(PackedStringArray(["0120", "0340"]))
	patch.revert(doc)
	assert_that(image.to_rows()).is_equal(PackedStringArray(["0000", "0000"]))
	assert_str(patch.get_label()).is_equal("Test")
	assert_int(patch.get_byte_size()).is_equal(8)
	assert_str(String(patch.get_image_id())).is_equal(String(image.id))
	assert_that(patch.get_dirty_rect()).is_equal(Rect2i(1, 0, 2, 2))


func test_pixel_patch_capture() -> void:
	var before: IndexedImage = IndexedImage.from_rows(&"I", ["00", "00"])
	var after: IndexedImage = IndexedImage.from_rows(&"I", ["05", "00"])
	var patch: PixelPatch = PixelPatch.capture(before, after, Rect2i(1, 0, 1, 1), "Dot")
	assert_that(patch.before).is_equal(PackedByteArray([0]))
	assert_that(patch.after).is_equal(PackedByteArray([5]))


func test_move_cel_command() -> void:
	var doc: PrismDocument = PrismDocument.create(4, 4)
	var command: MoveCelCommand = MoveCelCommand.new(Vector2i(0, 0), Vector2i.ZERO, Vector2i(2, -1))
	command.apply(doc)
	assert_that(doc.get_cel(0, 0).offset).is_equal(Vector2i(2, -1))
	command.revert(doc)
	assert_that(doc.get_cel(0, 0).offset).is_equal(Vector2i.ZERO)
	assert_str(command.get_label()).is_equal("Move Cel")
	assert_int(command.get_byte_size()).is_greater(0)
	assert_str(String(command.get_image_id())).is_empty()
	assert_bool(command.get_dirty_rect().has_area()).is_false()
