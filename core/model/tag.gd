class_name Tag
extends RefCounted

var tag_name: String
var from_frame: int
var to_frame: int
var direction: PrismEnums.TagDirection = PrismEnums.TagDirection.FORWARD
var color: Color = Color("#3d7bff")


func _init(p_name: String, p_from: int, p_to: int, p_direction: PrismEnums.TagDirection = PrismEnums.TagDirection.FORWARD) -> void:
	tag_name = p_name
	from_frame = p_from
	to_frame = p_to
	direction = p_direction


func frame_count() -> int:
	return to_frame - from_frame + 1


func duplicate_tag() -> Tag:
	var copy: Tag = Tag.new(tag_name, from_frame, to_frame, direction)
	copy.color = color
	return copy


func contains_frame(index: int) -> bool:
	return index >= from_frame and index <= to_frame
