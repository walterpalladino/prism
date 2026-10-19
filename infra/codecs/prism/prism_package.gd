## The contents of a `.prism` file before zipping: document.json text plus raw image files.
class_name PrismPackage
extends RefCounted

const DOCUMENT_FILE: String = "document.json"

var document_json: String = ""
## Archive path (e.g. "images/I3.bin") -> raw palette indices.
var files: Dictionary[String, PackedByteArray] = {}
