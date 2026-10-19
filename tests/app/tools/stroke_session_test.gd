extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func test_commit_produces_patch_for_changes_only() -> void:
	var image: IndexedImage = IndexedImage.new(&"I", 4, 4)
	var session: StrokeSession = StrokeSession.new(image)
	assert_object(session.commit("None")).is_null()
	image.set_index(1, 1, 5)
	session.add_dirty(Rect2i(1, 1, 1, 1))
	session.add_dirty(Rect2i())
	var patch: PixelPatch = session.commit("Dot")
	assert_that(patch.rect).is_equal(Rect2i(1, 1, 1, 1))
	assert_that(patch.after).is_equal(PackedByteArray([5]))


func test_unchanged_dirty_area_gives_no_patch() -> void:
	var image: IndexedImage = IndexedImage.new(&"I", 4, 4)
	var session: StrokeSession = StrokeSession.new(image)
	session.add_dirty(Rect2i(0, 0, 2, 2))
	assert_object(session.commit("Noop")).is_null()


func test_restore_and_cancel() -> void:
	var image: IndexedImage = IndexedImage.new(&"I", 4, 4)
	var session: StrokeSession = StrokeSession.new(image)
	image.fill(3)
	session.restore(Rect2i(0, 0, 2, 2))
	assert_int(image.pixels.count(0)).is_equal(4)
	session.add_dirty(Rect2i(-5, -5, 50, 50))
	session.cancel()
	assert_int(image.pixels.count(0)).is_equal(16)
	assert_bool(session.dirty.has_area()).is_false()
