## `.prism` files on disk: a zip with document.json and images/*.bin (GDD §9.6), written with
## ZIPPacker to a temporary file first and then moved over the target, so a crash mid-save
## never leaves a half-written document.
class_name ZipDocumentRepository
extends DocumentRepository

const TEMP_SUFFIX: String = ".saving"


func save_document(doc: PrismDocument, path: String) -> String:
	return write_package(PrismJson.to_package(doc), path)


## Writes an already-serialized package (autosave serializes off the main thread).
func write_package(package: PrismPackage, path: String) -> String:
	var dir_error: int = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if dir_error != OK:
		return "could not create folder %s (error %d)" % [path.get_base_dir(), dir_error]
	var temp: String = path + TEMP_SUFFIX
	var zip: ZIPPacker = ZIPPacker.new()
	if zip.open(temp) != OK:
		return "could not write %s" % path
	var entries: Dictionary[String, PackedByteArray] = {PrismPackage.DOCUMENT_FILE: package.document_json.to_utf8_buffer()}
	entries.merge(package.files)
	for name: String in entries:
		if zip.start_file(name) != OK or zip.write_file(entries[name]) != OK or zip.close_file() != OK:
			var _closed: int = zip.close()
			var _removed: int = DirAccess.remove_absolute(temp)
			return "could not write %s inside %s" % [name, path]
	if zip.close() != OK:
		return "could not finish writing %s" % path
	if FileAccess.file_exists(path):
		var remove_error: int = DirAccess.remove_absolute(path)
		if remove_error != OK:
			return "could not replace %s (error %d)" % [path, remove_error]
	var rename_error: int = DirAccess.rename_absolute(temp, path)
	return "" if rename_error == OK else "could not move the saved file into place (error %d)" % rename_error


func load_document(path: String) -> DocumentResult:
	if not FileAccess.file_exists(path):
		return DocumentResult.fail("file not found: %s" % path)
	var zip: ZIPReader = ZIPReader.new()
	if zip.open(path) != OK:
		return DocumentResult.fail("%s is not a PRISM file (not a zip archive)" % path.get_file())
	var package: PrismPackage = PrismPackage.new()
	var names: PackedStringArray = zip.get_files()
	if not names.has(PrismPackage.DOCUMENT_FILE):
		var _c: int = zip.close()
		return DocumentResult.fail("%s has no document.json" % path.get_file())
	package.document_json = zip.read_file(PrismPackage.DOCUMENT_FILE).get_string_from_utf8()
	for name: String in names:
		if name.begins_with("images/") and name.ends_with(".bin"):
			package.files[name] = zip.read_file(name)
	var _closed: int = zip.close()
	return PrismJson.from_package(package)


func exists(path: String) -> bool:
	return FileAccess.file_exists(path)


func remove(path: String) -> void:
	if FileAccess.file_exists(path):
		var _removed: int = DirAccess.remove_absolute(path)


func write_text(path: String, text: String) -> String:
	var dir_error: int = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if dir_error != OK:
		return "could not create folder %s" % path.get_base_dir()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "could not write %s" % path
	var stored: bool = file.store_string(text)
	file.close()
	return "" if stored else "could not write %s" % path
