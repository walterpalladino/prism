extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func test_create_builds_one_layer_frame_and_cel() -> void:
	var doc: PrismDocument = PrismDocument.create(16, 8)
	assert_int(doc.layers.size()).is_equal(1)
	assert_int(doc.frames.size()).is_equal(1)
	assert_int(doc.images.size()).is_equal(1)
	assert_bool(doc.has_cel(0, 0)).is_true()
	var image: IndexedImage = doc.get_cel_image(0, 0)
	assert_that(image.get_size()).is_equal(Vector2i(16, 8))
	assert_int(image.pixels.count(doc.transparent_index)).is_equal(128)
	assert_int(doc.palette.size()).is_equal(32)
	assert_array(DocumentValidator.validate(doc)).is_empty()


func test_create_uses_given_palette() -> void:
	var doc: PrismDocument = PrismDocument.create(4, 4, PalettePresets.ega_16())
	assert_int(doc.palette.size()).is_equal(16)


func test_ids_are_unique_and_deterministic() -> void:
	var doc: PrismDocument = PrismDocument.create(4, 4)
	assert_str(String(doc.layers[0].id)).is_equal("L1")
	assert_str(String(doc.frames[0].id)).is_equal("F2")
	assert_str(String(doc.get_cel(0, 0).image_id)).is_equal("I3")
	assert_str(String(doc.new_id("T"))).is_equal("T4")


func test_index_lookups() -> void:
	var doc: PrismDocument = PrismDocument.create(4, 4)
	assert_int(doc.layer_index_of(&"L1")).is_equal(0)
	assert_int(doc.layer_index_of(&"nope")).is_equal(-1)
	assert_int(doc.frame_index_of(&"F2")).is_equal(0)
	assert_int(doc.frame_index_of(&"nope")).is_equal(-1)


func test_empty_cel_returns_null() -> void:
	var doc: PrismDocument = PrismDocument.create(4, 4)
	assert_object(doc.get_cel(0, 1)).is_null()
	assert_object(doc.get_cel_image(1, 0)).is_null()


func test_linked_cels_share_image() -> void:
	var doc: PrismDocument = PrismDocument.create(4, 4)
	var frame: Frame = Frame.new(doc.new_id("F"))
	doc.frames.append(frame)
	var shared: StringName = doc.get_cel(0, 0).image_id
	doc.cels[Vector2i(0, 1)] = Cel.new(doc.layers[0].id, frame.id, shared)
	assert_int(doc.count_image_users(shared)).is_equal(2)
	doc.get_cel_image(0, 1).set_index(1, 1, 5)
	assert_int(doc.get_cel_image(0, 0).get_index(1, 1)).is_equal(5)
	assert_array(DocumentValidator.validate(doc)).is_empty()


func test_create_image_registers_canvas_sized_transparent_image() -> void:
	var doc: PrismDocument = PrismDocument.create(6, 3)
	doc.transparent_index = 4
	var image: IndexedImage = doc.create_image()
	assert_bool(doc.images.has(image.id)).is_true()
	assert_that(image.get_size()).is_equal(Vector2i(6, 3))
	assert_int(image.pixels.count(4)).is_equal(18)
