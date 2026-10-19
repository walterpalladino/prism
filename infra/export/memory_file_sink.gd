## FileSink that keeps written files in memory (tests).
class_name MemoryFileSink
extends FileSink

var files: Dictionary[String, PackedByteArray] = {}
## Folders that "contain" a given file name, for find_upwards (e.g. {"/proj": "project.godot"}).
var markers: Dictionary[String, String] = {}


func write_bytes(path: String, bytes: PackedByteArray) -> String:
	files[path] = bytes.duplicate()
	return ""


func read_bytes(path: String) -> PackedByteArray:
	return files[path].duplicate() if files.has(path) else PackedByteArray()


func find_upwards(directory: String, file_name: String) -> String:
	var current: String = directory.simplify_path()
	while current != "":
		if markers.get(current, "") == file_name:
			return current
		var parent: String = current.get_base_dir()
		if parent == current:
			break
		current = parent
	return ""


func text(path: String) -> String:
	return files[path].get_string_from_utf8() if files.has(path) else ""


func image(path: String) -> Image:
	var result: Image = Image.new()
	if not files.has(path) or result.load_png_from_buffer(files[path]) != OK:
		return null
	return result
