class_name Cel
extends RefCounted

var layer_id: StringName
var frame_id: StringName
## Cels sharing an image_id are linked: editing one edits all.
var image_id: StringName
var offset: Vector2i = Vector2i.ZERO


func _init(p_layer_id: StringName, p_frame_id: StringName, p_image_id: StringName, p_offset: Vector2i = Vector2i.ZERO) -> void:
	layer_id = p_layer_id
	frame_id = p_frame_id
	image_id = p_image_id
	offset = p_offset


func duplicate_cel() -> Cel:
	return Cel.new(layer_id, frame_id, image_id, offset)
