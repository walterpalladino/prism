extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func _doc() -> PrismDocument:
	return PrismDocument.create(8, 8)


func _expect_error(doc: PrismDocument, fragment: String) -> void:
	var errors: PackedStringArray = DocumentValidator.validate(doc)
	var found: bool = false
	for error: String in errors:
		if error.contains(fragment):
			found = true
	assert_bool(found).override_failure_message("expected '%s' in %s" % [fragment, errors]).is_true()


func test_valid_document_has_no_errors() -> void:
	assert_array(DocumentValidator.validate(_doc())).is_empty()


func test_canvas_too_large() -> void:
	var doc: PrismDocument = _doc()
	doc.width = PrismDocument.MAX_CANVAS_SIZE + 1
	_expect_error(doc, "canvas size")


func test_transparent_index_outside_palette() -> void:
	var doc: PrismDocument = _doc()
	doc.transparent_index = 40
	_expect_error(doc, "transparent index")


func test_pixel_index_outside_palette() -> void:
	var doc: PrismDocument = _doc()
	doc.get_cel_image(0, 0).set_index(0, 0, 200)
	_expect_error(doc, "outside palette")


func test_pixel_count_mismatch() -> void:
	var doc: PrismDocument = _doc()
	doc.get_cel_image(0, 0).pixels.resize(3)
	_expect_error(doc, "pixel count")


func test_duplicate_ids() -> void:
	var doc: PrismDocument = _doc()
	doc.layers.append(Layer.new(doc.layers[0].id, "copy"))
	_expect_error(doc, "duplicate id")


func test_layer_opacity_and_frame_duration() -> void:
	var doc: PrismDocument = _doc()
	doc.layers[0].opacity = 300
	doc.frames[0].duration_ms = 0
	_expect_error(doc, "opacity")
	_expect_error(doc, "duration")


func test_cel_outside_grid_and_bad_references() -> void:
	var doc: PrismDocument = _doc()
	doc.cels[Vector2i(3, 0)] = Cel.new(&"L1", &"F2", &"I3")
	_expect_error(doc, "outside the layer/frame grid")
	var doc2: PrismDocument = _doc()
	doc2.get_cel(0, 0).image_id = &"missing"
	_expect_error(doc2, "missing image")
	var doc3: PrismDocument = _doc()
	doc3.get_cel(0, 0).layer_id = &"other"
	_expect_error(doc3, "layer id")


func test_tag_range() -> void:
	var doc: PrismDocument = _doc()
	doc.tags.append(Tag.new("walk", 0, 4))
	_expect_error(doc, "tag 'walk'")


func test_cycles() -> void:
	var doc: PrismDocument = _doc()
	doc.cycles.append(CycleRange.new(16, 21, 12.0))
	assert_array(DocumentValidator.validate(doc)).is_empty()
	doc.cycles.append(CycleRange.new(20, 24, 12.0))
	_expect_error(doc, "overlap")
	doc.cycles.clear()
	doc.cycles.append(CycleRange.new(5, 40, 12.0))
	_expect_error(doc, "invalid range")
	doc.cycles.clear()
	doc.cycles.append(CycleRange.new(1, 2, 0.0, 2))
	_expect_error(doc, "rate must be positive")
	_expect_error(doc, "step")


func test_too_many_cycles() -> void:
	var cycles: Array[CycleRange] = []
	for i: int in 5:
		cycles.append(CycleRange.new(i * 3, i * 3 + 1, 1.0))
	var errors: PackedStringArray = DocumentValidator.validate_cycles(cycles, 32)
	assert_str(errors[0]).contains("too many")


func test_invalid_ramp() -> void:
	var doc: PrismDocument = _doc()
	doc.palette.ramps.append(Vector2i(30, 40))
	_expect_error(doc, "invalid ramp")
