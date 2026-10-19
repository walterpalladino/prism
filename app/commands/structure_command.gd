## A layer / frame / cel / tag change, stored as before and after structure snapshots.
class_name StructureCommand
extends Command

var label: String
var before: DocumentStructure
var after: DocumentStructure
var _bytes: int


func _init(p_label: String, p_before: DocumentStructure, p_after: DocumentStructure) -> void:
	label = p_label
	before = p_before
	after = p_after
	_bytes = 64 * (before.cels.size() + after.cels.size() + before.layers.size() + after.layers.size() + before.frames.size() + after.frames.size())
	for image_id: StringName in after.images:
		if not before.images.has(image_id):
			_bytes += after.images[image_id].pixels.size()


func get_label() -> String:
	return label


func apply(doc: PrismDocument) -> void:
	after.restore(doc)


func revert(doc: PrismDocument) -> void:
	before.restore(doc)


func get_byte_size() -> int:
	return _bytes
