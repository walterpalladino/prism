## Outcome of loading a document: a document, or an error message (never both).
class_name DocumentResult
extends RefCounted

var document: PrismDocument
var error: String = ""


static func ok(p_document: PrismDocument) -> DocumentResult:
	var result: DocumentResult = DocumentResult.new()
	result.document = p_document
	return result


static func fail(message: String) -> DocumentResult:
	var result: DocumentResult = DocumentResult.new()
	result.error = message
	return result


func is_ok() -> bool:
	return error == ""
