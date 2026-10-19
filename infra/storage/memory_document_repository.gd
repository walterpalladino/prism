## In-memory DocumentRepository for tests: stores serialized packages, so saving and loading
## still go through the real `.prism` JSON codec.
class_name MemoryDocumentRepository
extends DocumentRepository

var packages: Dictionary[String, PrismPackage] = {}
var texts: Dictionary[String, String] = {}
## When set, save() fails with this message (to test error handling).
var fail_saves_with: String = ""


func save_document(doc: PrismDocument, path: String) -> String:
	if fail_saves_with != "":
		return fail_saves_with
	packages[path] = PrismJson.to_package(doc)
	return ""


func load_document(path: String) -> DocumentResult:
	if not packages.has(path):
		return DocumentResult.fail("file not found: %s" % path)
	return PrismJson.from_package(packages[path])


func exists(path: String) -> bool:
	return packages.has(path) or texts.has(path)


func remove(path: String) -> void:
	var _erased_package: bool = packages.erase(path)
	var _erased_text: bool = texts.erase(path)


func write_text(path: String, text: String) -> String:
	texts[path] = text
	return ""
