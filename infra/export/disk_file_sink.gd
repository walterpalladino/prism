## FileSink on the real file system.
class_name DiskFileSink
extends FileSink


func write_bytes(path: String, bytes: PackedByteArray) -> String:
	var dir_error: int = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if dir_error != OK:
		return "could not create folder %s (error %d)" % [path.get_base_dir(), dir_error]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "could not write %s (error %d)" % [path, FileAccess.get_open_error()]
	var stored: bool = file.store_buffer(bytes)
	file.close()
	return "" if stored else "could not write %s" % path


func read_bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()


func find_upwards(directory: String, file_name: String) -> String:
	var current: String = directory.simplify_path()
	while current != "":
		if FileAccess.file_exists(current.path_join(file_name)):
			return current
		var parent: String = current.get_base_dir()
		if parent == current:
			break
		current = parent
	return ""


func open_in_system(path: String) -> void:
	var _error: int = OS.shell_open(ProjectSettings.globalize_path(path))
