extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self
@warning_ignore_start("unsafe_cast", "unsafe_call_argument")  # this suite inspects untyped JSON on purpose


func _round_trip(doc: PrismDocument) -> DocumentResult:
	return PrismJson.from_package(PrismJson.to_package(doc))


func _data(doc: PrismDocument) -> Dictionary:
	return JSON.parse_string(PrismJson.to_package(doc).document_json)


func _with_data(doc: PrismDocument, data: Dictionary) -> PrismPackage:
	var package: PrismPackage = PrismJson.to_package(doc)
	package.document_json = JSON.stringify(data)
	return package


func _expect_error(package: PrismPackage, fragment: String) -> void:
	var result: DocumentResult = PrismJson.from_package(package)
	assert_bool(result.is_ok()).override_failure_message("expected error containing '%s'" % fragment).is_false()
	assert_object(result.document).is_null()
	assert_str(result.error).contains(fragment)


func test_round_trip_keeps_everything() -> void:
	var doc: PrismDocument = SampleDocuments.rich()
	var result: DocumentResult = _round_trip(doc)
	assert_str(result.error).is_empty()
	assert_str(DocFingerprint.of(result.document)).is_equal(DocFingerprint.of(doc))
	assert_int(result.document.next_id).is_equal(doc.next_id)
	assert_int(result.document.cycles.size()).is_equal(2)
	assert_int(result.document.cycles[1].step).is_equal(-1)
	assert_bool(result.document.stencil.is_locked(30)).is_true()
	assert_str(result.document.layers[0].layer_name).is_equal("Body \"main\"")


func test_linked_cels_stay_linked() -> void:
	var result: DocumentResult = _round_trip(SampleDocuments.rich())
	var doc: PrismDocument = result.document
	assert_str(String(doc.get_cel(0, 1).image_id)).is_equal(String(doc.get_cel(0, 2).image_id))
	doc.get_cel_image(0, 1).set_index(0, 0, 5)
	assert_int(doc.get_cel_image(0, 2).get_index(0, 0)).is_equal(5)


func test_json_shape_matches_the_gdd_schema() -> void:
	var data: Dictionary = _data(SampleDocuments.rich())
	assert_str(data["format"]).is_equal("prism")
	assert_int(int(data["version"])).is_equal(PrismMigrations.CURRENT_VERSION)
	for key: String in ["width", "height", "colorMode", "transparentIndex", "palette", "ramps", "layers", "frames", "cels", "images", "tags", "cycles", "stencil"]:
		assert_bool(data.has(key)).override_failure_message("missing " + key).is_true()
	var tag: Dictionary = (data["tags"] as Array)[1]
	assert_str(tag["direction"]).is_equal("pingpong")


func test_not_json_or_not_prism() -> void:
	var doc: PrismDocument = PrismDocument.create(2, 2)
	var package: PrismPackage = PrismJson.to_package(doc)
	package.document_json = "{not json"
	_expect_error(package, "not valid JSON")
	package.document_json = "[1, 2]"
	_expect_error(package, "not valid JSON")
	package.document_json = "{\"format\": \"aseprite\"}"
	_expect_error(package, "not a PRISM document")


func test_versions() -> void:
	var doc: PrismDocument = PrismDocument.create(2, 2)
	var data: Dictionary = _data(doc)
	data["version"] = 99
	_expect_error(_with_data(doc, data), "newer PRISM")
	data["version"] = 0
	_expect_error(_with_data(doc, data), "invalid document version")
	data.erase("version")
	_expect_error(_with_data(doc, data), "no version")


func test_missing_and_wrong_sized_image_files() -> void:
	var doc: PrismDocument = PrismDocument.create(4, 4)
	var package: PrismPackage = PrismJson.to_package(doc)
	var path: String = package.files.keys()[0]
	package.files[path] = PackedByteArray([1, 2, 3])
	_expect_error(package, "has 3 bytes, expected 16")
	package.files.erase(path)
	_expect_error(package, "missing file")


func test_bad_values_are_reported_not_crashing() -> void:
	var doc: PrismDocument = SampleDocuments.rich()
	var cases: Array[Array] = [
		["width", 9999, "width"],
		["width", "wide", "must be a number"],
		["palette", [], "palette must have"],
		["palette", ["#zzzzzz"], "not a #rrggbb color"],
		["layers", "x", "must be a list"],
		["ramps", [[5]], "not a valid [start, end] ramp"],
		["stencil", [300], "not a palette index"],
		["colorMode", "rgba", "not supported"],
		["transparentIndex", 1.5, "whole number"],
	]
	for case: Array in cases:
		var data: Dictionary = _data(doc)
		data[case[0]] = case[1]
		var fragment: String = case[2]
		_expect_error(_with_data(doc, data), fragment)


func test_bad_entries_inside_lists() -> void:
	var doc: PrismDocument = SampleDocuments.rich()
	var data: Dictionary = _data(doc)
	(data["layers"] as Array)[0] = "not an object"
	_expect_error(_with_data(doc, data), "layers[0] must be an object")
	data = _data(doc)
	((data["layers"] as Array)[0] as Dictionary)["opacity"] = 999
	_expect_error(_with_data(doc, data), "opacity")
	data = _data(doc)
	((data["tags"] as Array)[0] as Dictionary)["direction"] = "sideways"
	_expect_error(_with_data(doc, data), "unknown direction")
	data = _data(doc)
	((data["cels"] as Array)[0] as Dictionary)["image"] = "I999"
	_expect_error(_with_data(doc, data), "unknown image")
	data = _data(doc)
	((data["cels"] as Array)[0] as Dictionary)["layer"] = "L999"
	_expect_error(_with_data(doc, data), "unknown layers or frames")
	data = _data(doc)
	((data["cycles"] as Array)[0] as Dictionary)["end"] = 9
	_expect_error(_with_data(doc, data), "invalid document")


func test_missing_cel_slot_is_rejected() -> void:
	var doc: PrismDocument = SampleDocuments.rich()
	var data: Dictionary = _data(doc)
	(data["cels"] as Array).pop_back()
	_expect_error(_with_data(doc, data), "missing cel")


func test_json_reader_messages() -> void:
	var r: JsonReader = JsonReader.new()
	assert_int(r.get_int({"a": 3.0}, "a", "x", 0, 5)).is_equal(3)
	assert_bool(r.ok()).is_true()
	assert_int(r.get_int({}, "a", "x", 0, 5, 7)).is_equal(7)
	assert_float(r.get_float({"f": 2.5}, "f", "x", 0.0, 1.0, 9.0)).is_equal(9.0)
	assert_bool(r.get_bool({"b": 1}, "b", "x", true)).is_true()
	assert_str(r.get_string({"s": 1}, "s", "x", "d")).is_equal("d")
	assert_bool(r.get_dict({"d": []}, "d", "x").is_empty()).is_true()
	assert_bool(r.get_color({"c": "#ff0000"}, "c", "x").is_equal_approx(Color.RED)).is_true()
	assert_int(r.errors.size()).is_equal(5)
	assert_str(r.errors[0]).contains("must be a number")
