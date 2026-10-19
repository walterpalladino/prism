extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func _two_frame_doc() -> PrismDocument:
	var doc: PrismDocument = PrismDocument.create(4, 4)
	var frame: Frame = Frame.new(doc.new_id("F"))
	doc.frames.append(frame)
	doc.cels[Vector2i(0, 1)] = Cel.new(doc.layers[0].id, frame.id, doc.create_image().id)
	return doc


func test_reindex_follows_ids_after_reordering() -> void:
	var doc: PrismDocument = _two_frame_doc()
	var first_image: StringName = doc.get_cel(0, 0).image_id
	doc.frames.reverse()
	doc.reindex_cels()
	assert_str(String(doc.get_cel(0, 1).image_id)).is_equal(String(first_image))
	doc.frames.remove_at(0)
	doc.reindex_cels()
	assert_int(doc.cels.size()).is_equal(1)
	assert_str(String(doc.get_cel(0, 0).image_id)).is_equal(String(first_image))


func test_prune_images() -> void:
	var doc: PrismDocument = _two_frame_doc()
	var orphan: IndexedImage = doc.create_image()
	doc.prune_images()
	assert_bool(doc.images.has(orphan.id)).is_false()
	assert_int(doc.images.size()).is_equal(2)


func test_tag_lookup_and_empty_images() -> void:
	var doc: PrismDocument = _two_frame_doc()
	doc.tags.append(Tag.new("a", 1, 1))
	assert_int(doc.tag_index_at(1)).is_equal(0)
	assert_int(doc.tag_index_at(0)).is_equal(-1)
	var image: IndexedImage = doc.get_cel_image(0, 0)
	assert_bool(doc.is_image_empty(image.id)).is_true()
	image.set_index(1, 1, 4)
	assert_bool(doc.is_image_empty(image.id)).is_false()


func test_capture_restore_round_trip_and_independence() -> void:
	var doc: PrismDocument = _two_frame_doc()
	doc.tags.append(Tag.new("walk", 0, 1))
	var before: String = DocFingerprint.of(doc)
	var snapshot: DocumentStructure = DocumentStructure.capture(doc)
	doc.layers[0].layer_name = "changed"
	doc.frames[0].duration_ms = 999
	doc.tags[0].tag_name = "changed"
	doc.frames.remove_at(1)
	doc.reindex_cels()
	snapshot.restore(doc)
	assert_str(DocFingerprint.of(doc)).is_equal(before)
	doc.layers[0].layer_name = "again"
	snapshot.restore(doc)
	assert_str(DocFingerprint.of(doc)).is_equal(before)
	assert_array(DocumentValidator.validate(doc)).is_empty()


func test_restore_never_reuses_ids() -> void:
	var doc: PrismDocument = _two_frame_doc()
	var snapshot: DocumentStructure = DocumentStructure.capture(doc)
	var used: StringName = doc.new_id("L")
	snapshot.restore(doc)
	assert_str(String(doc.new_id("L"))).is_not_equal(String(used))


func test_entity_duplicates() -> void:
	var tag: Tag = Tag.new("t", 1, 3, PrismEnums.TagDirection.REVERSE)
	tag.color = Color.RED
	var tag_copy: Tag = tag.duplicate_tag()
	assert_that(tag_copy.color).is_equal(Color.RED)
	assert_bool(tag_copy.contains_frame(3)).is_true()
	assert_bool(tag_copy.contains_frame(4)).is_false()
	assert_int(Frame.new(&"F1", 250).duplicate_frame(&"F9").duration_ms).is_equal(250)
	assert_that(Cel.new(&"L", &"F", &"I", Vector2i(1, 2)).duplicate_cel().offset).is_equal(Vector2i(1, 2))
