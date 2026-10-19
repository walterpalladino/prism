## Reads and writes palette files by extension (.gpl, .hex, .png) — GDD §7.4.
class_name PaletteFiles
extends RefCounted

const FILTERS: PackedStringArray = ["*.gpl ; GIMP palette", "*.hex ; Hex color list", "*.png ; PNG palette strip"]


static func load_file(path: String) -> PaletteResult:
	if not FileAccess.file_exists(path):
		return PaletteResult.fail("file not found: %s" % path)
	match path.get_extension().to_lower():
		"gpl":
			return PaletteCodecs.decode_gpl(FileAccess.get_file_as_string(path))
		"hex":
			return PaletteCodecs.decode_hex(FileAccess.get_file_as_string(path))
		"png":
			return PaletteCodecs.decode_png(FileAccess.get_file_as_bytes(path))
	return PaletteResult.fail("unsupported palette format: .%s" % path.get_extension())


## Writes `palette` to `path`; returns "" on success or an error message.
static func save_file(path: String, palette: Palette) -> String:
	var extension: String = path.get_extension().to_lower()
	if extension == "png":
		var err: int = PaletteCodecs.encode_png_image(palette).save_png(path)
		return "" if err == OK else "could not write %s (error %d)" % [path, err]
	var text: String
	match extension:
		"gpl":
			text = PaletteCodecs.encode_gpl(palette, path.get_file().get_basename())
		"hex":
			text = PaletteCodecs.encode_hex(palette)
		_:
			return "unsupported palette format: .%s" % extension
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "could not write %s (error %d)" % [path, FileAccess.get_open_error()]
	var stored: bool = file.store_string(text)
	file.close()
	return "" if stored else "could not write %s" % path
