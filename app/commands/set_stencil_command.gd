## Replaces the stencil's lock table (toggle, invert, lock-all-except, clear).
class_name SetStencilCommand
extends Command

var before: PackedByteArray
var after: PackedByteArray
var label: String


func _init(p_before: PackedByteArray, p_after: PackedByteArray, p_label: String) -> void:
	before = p_before.duplicate()
	after = p_after.duplicate()
	label = p_label


func get_label() -> String:
	return label


func apply(doc: PrismDocument) -> void:
	doc.stencil.locked = after.duplicate()


func revert(doc: PrismDocument) -> void:
	doc.stencil.locked = before.duplicate()


func get_byte_size() -> int:
	return before.size() + after.size()


func changes_palette() -> bool:
	return true
