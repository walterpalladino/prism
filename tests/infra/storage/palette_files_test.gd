extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self

const DIR: String = "user://test_palettes/"


func before() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)


func after() -> void:
	for file: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + file)
	DirAccess.remove_absolute(DIR)


func test_save_and_load_each_format() -> void:
	var palette: Palette = PalettePresets.pico8_style_16()
	for extension: String in ["gpl", "hex", "png"]:
		var path: String = DIR + "p." + extension
		assert_str(PaletteFiles.save_file(path, palette)).is_empty()
		var result: PaletteResult = PaletteFiles.load_file(path)
		assert_bool(result.is_ok()).override_failure_message(extension + ": " + result.error).is_true()
		assert_int(result.palette.size()).is_equal(16)
		assert_str(result.palette.get_color(12).to_html(false)).is_equal("29adff")


func test_errors() -> void:
	assert_str(PaletteFiles.load_file(DIR + "missing.gpl").error).contains("not found")
	assert_str(PaletteFiles.save_file(DIR + "p.act", PalettePresets.ega_16())).contains("unsupported")
	var file: FileAccess = FileAccess.open(DIR + "p.act", FileAccess.WRITE)
	file.store_string("x")
	file.close()
	assert_str(PaletteFiles.load_file(DIR + "p.act").error).contains("unsupported")
	assert_int(PaletteFiles.FILTERS.size()).is_equal(3)
