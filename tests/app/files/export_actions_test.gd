extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func _setup() -> Array:
	var fx: AppFixture = AppFixture.new(8, 4)
	var sink: MemoryFileSink = MemoryFileSink.new()
	return [fx, sink, ExportActions.new(fx.bus, fx.state, sink)]


func test_scopes_and_options() -> void:
	var parts: Array = _setup()
	var fx: AppFixture = parts[0]
	var exports: ExportActions = parts[2]
	fx.timeline.insert_frame(1)
	fx.timeline.add_tag(Vector2i(1, 1), "jump")
	assert_array(exports.scope_names()).is_equal(PackedStringArray(["All frames (2)", "Tag: jump (2–2)"]))
	assert_that(exports.options_for(1).frame_range).is_equal(Vector2i(1, 1))
	assert_that(exports.options_for(0).frame_range).is_equal(Vector2i(0, 1))
	assert_that(exports.options_for(9).frame_range).is_equal(Vector2i(0, 1))
	assert_int(exports.predicted_frames(exports.options_for(0))).is_equal(2)


func test_each_export_writes_files() -> void:
	var parts: Array = _setup()
	var sink: MemoryFileSink = parts[1]
	var exports: ExportActions = parts[2]
	sink.markers["/proj"] = "project.godot"
	var options: ExportOptions = exports.options_for(0)
	assert_str(exports.export_frame_png("/a", 2)).is_empty()
	assert_str(exports.export_png_sequence("/seq.png", options)).is_empty()
	assert_str(exports.export_sprite_sheet("/sheet.png", options)).is_empty()
	assert_str(exports.export_sprite_frames("/proj/s.tres", 1)).is_empty()
	assert_str(exports.export_gif("/g.gif", options)).is_empty()
	for path: String in ["/a.png", "/seq_0001.png", "/sheet.png", "/sheet.json", "/proj/s.tres", "/proj/s.png", "/g.gif"]:
		assert_bool(sink.files.has(path)).override_failure_message("missing " + path).is_true()
	assert_that(sink.image("/a.png").get_size()).is_equal(Vector2i(16, 8))


func test_import_png_into_cel_is_undoable() -> void:
	var parts: Array = _setup()
	var fx: AppFixture = parts[0]
	var sink: MemoryFileSink = parts[1]
	var exports: ExportActions = parts[2]
	var image: Image = Image.create_empty(3, 2, false, Image.FORMAT_RGBA8)
	image.fill(fx.bus.document.palette.get_color(9))
	sink.write_png("/in.png", image)
	assert_str(exports.import_png_into_cel("/in.png")).is_empty()
	assert_int(fx.image().get_index(2, 1)).is_equal(9)
	assert_int(fx.image().get_index(3, 1)).is_equal(0)
	assert_str(fx.bus.history.undo_label()).is_equal("Import PNG")
	assert_str(exports.import_png_into_cel("/missing.png")).contains("not a readable PNG")
	fx.bus.document.layers[0].locked = true
	assert_str(exports.import_png_into_cel("/in.png")).contains("locked")


func test_document_from_png() -> void:
	var parts: Array = _setup()
	var sink: MemoryFileSink = parts[1]
	var exports: ExportActions = parts[2]
	var image: Image = Image.create_empty(5, 3, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	sink.write_png("/red.png", image)
	var result: DocumentResult = exports.document_from_png("/red.png")
	assert_that(Vector2i(result.document.width, result.document.height)).is_equal(Vector2i(5, 3))
	assert_bool(exports.document_from_png("/none.png").is_ok()).is_false()


func test_disk_file_sink() -> void:
	var sink: DiskFileSink = DiskFileSink.new()
	var dir: String = OS.get_user_data_dir().path_join("sink_test")
	assert_str(sink.write_text(dir.path_join("a/b.txt"), "hi")).is_empty()
	assert_str(sink.read_bytes(dir.path_join("a/b.txt")).get_string_from_utf8()).is_equal("hi")
	assert_bool(sink.read_bytes(dir.path_join("nope")).is_empty()).is_true()
	sink.write_text(dir.path_join("project.godot"), "")
	assert_str(sink.find_upwards(dir.path_join("a"), "project.godot")).is_equal(dir)
	assert_str(sink.find_upwards("/definitely/not/here", "project.godot")).is_empty()
	DirAccess.remove_absolute(dir.path_join("a/b.txt"))
	DirAccess.remove_absolute(dir.path_join("a"))
	DirAccess.remove_absolute(dir.path_join("project.godot"))
	DirAccess.remove_absolute(dir)


func test_memory_sink_open_in_system_is_a_no_op() -> void:
	var sink: MemoryFileSink = MemoryFileSink.new()
	sink.open_in_system("/anything")
	assert_bool(sink.files.is_empty()).is_true()
