## Changes a cel's offset (Move tool, `V`).
class_name MoveCelCommand
extends Command

var cel_key: Vector2i
var from_offset: Vector2i
var to_offset: Vector2i


func _init(p_cel_key: Vector2i, p_from: Vector2i, p_to: Vector2i) -> void:
	cel_key = p_cel_key
	from_offset = p_from
	to_offset = p_to


func get_label() -> String:
	return "Move Cel"


func apply(doc: PrismDocument) -> void:
	doc.cels[cel_key].offset = to_offset


func revert(doc: PrismDocument) -> void:
	doc.cels[cel_key].offset = from_offset


func get_byte_size() -> int:
	return 32
