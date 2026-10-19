extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func _patch(doc: PrismDocument, x: int, value: int) -> PixelPatch:
	var image: IndexedImage = doc.get_cel_image(0, 0)
	return PixelPatch.new(image.id, Rect2i(x, 0, 1, 1), PackedByteArray([image.get_index(x, 0)]), PackedByteArray([value]), "P%d" % x)


func test_undo_redo_round_trip() -> void:
	var doc: PrismDocument = PrismDocument.create(4, 1)
	var history: History = History.new()
	var patch: PixelPatch = _patch(doc, 1, 7)
	patch.apply(doc)
	history.push(patch)
	assert_bool(history.can_undo()).is_true()
	assert_str(history.undo_label()).is_equal("P1")
	assert_object(history.undo(doc)).is_same(patch)
	assert_int(doc.get_cel_image(0, 0).get_index(1, 0)).is_equal(0)
	assert_bool(history.can_redo()).is_true()
	assert_str(history.redo_label()).is_equal("P1")
	history.redo(doc)
	assert_int(doc.get_cel_image(0, 0).get_index(1, 0)).is_equal(7)
	assert_object(history.redo(doc)).is_null()


func test_empty_history_returns_null() -> void:
	var history: History = History.new()
	assert_object(history.undo(PrismDocument.create(1, 1))).is_null()
	assert_str(history.undo_label()).is_empty()
	assert_str(history.redo_label()).is_empty()


func test_push_clears_redo() -> void:
	var doc: PrismDocument = PrismDocument.create(4, 1)
	var history: History = History.new()
	history.push(_patch(doc, 0, 1))
	history.undo(doc)
	history.push(_patch(doc, 1, 1))
	assert_int(history.redo_count()).is_equal(0)
	assert_int(history.undo_count()).is_equal(1)
	assert_int(history.total_bytes()).is_equal(2)


func test_count_limit_drops_oldest() -> void:
	var doc: PrismDocument = PrismDocument.create(4, 1)
	var history: History = History.new(3)
	for i: int in 5:
		history.push(_patch(doc, i % 4, 1))
	assert_int(history.undo_count()).is_equal(3)
	assert_int(history.total_bytes()).is_equal(6)


func test_byte_limit_keeps_at_least_one() -> void:
	var doc: PrismDocument = PrismDocument.create(4, 1)
	var history: History = History.new(100, 3)
	history.push(_patch(doc, 0, 1))
	history.push(_patch(doc, 1, 1))
	assert_int(history.undo_count()).is_equal(1)
	assert_str(history.undo_label()).is_equal("P1")
	history.clear()
	assert_int(history.undo_count()).is_equal(0)
	assert_int(history.total_bytes()).is_equal(0)


func test_default_limits_meet_gdd() -> void:
	var history: History = History.new()
	assert_int(history.max_count).is_greater_equal(200)
	assert_int(history.max_bytes).is_equal(256 * 1024 * 1024)
