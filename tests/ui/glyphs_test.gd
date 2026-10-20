extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self

## UI text must use characters Godot's built-in font has: the web build has no system fonts to
## fall back on, so anything else draws as a box there (desktop builds hide the problem).
const SOURCE_DIRS: PackedStringArray = ["res://app", "res://boot", "res://infra", "res://ui"]


func test_ui_text_only_uses_glyphs_of_the_default_font() -> void:
	var font: Font = ThemeDB.fallback_font
	var missing: PackedStringArray = PackedStringArray()
	for dir: String in SOURCE_DIRS:
		for path: String in _scripts(dir):
			var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
			for i: int in lines.size():
				var line: String = lines[i]
				if line.strip_edges().begins_with("#"):
					continue
				for c: int in line.length():
					var code: int = line.unicode_at(c)
					if code > 127 and not font.has_char(code):
						missing.append("%s:%d %s" % [path, i + 1, line[c]])
	assert_array(missing).is_empty()


func _scripts(dir: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			result.append(dir.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir):
		result.append_array(_scripts(dir.path_join(sub)))
	return result
