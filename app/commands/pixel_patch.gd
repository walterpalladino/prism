## Before/after bytes of one dirty rect of one image. A whole stroke is one PixelPatch.
class_name PixelPatch
extends Command

var image_id: StringName
var rect: Rect2i
var before: PackedByteArray
var after: PackedByteArray
var label: String


func _init(p_image_id: StringName, p_rect: Rect2i, p_before: PackedByteArray, p_after: PackedByteArray, p_label: String = "Paint") -> void:
	assert(p_before.size() == p_rect.size.x * p_rect.size.y and p_after.size() == p_before.size())
	image_id = p_image_id
	rect = p_rect
	before = p_before
	after = p_after
	label = p_label


## Builds a patch for `rect` from a pre-change snapshot and the current image.
static func capture(snapshot: IndexedImage, current: IndexedImage, p_rect: Rect2i, p_label: String) -> PixelPatch:
	return PixelPatch.new(current.id, p_rect, RasterOps.read_rect(snapshot, p_rect), RasterOps.read_rect(current, p_rect), p_label)


func get_label() -> String:
	return label


func apply(doc: PrismDocument) -> void:
	RasterOps.write_rect(doc.images[image_id], rect, after)


func revert(doc: PrismDocument) -> void:
	RasterOps.write_rect(doc.images[image_id], rect, before)


func get_byte_size() -> int:
	return before.size() + after.size()


func get_image_id() -> StringName:
	return image_id


func get_dirty_rect() -> Rect2i:
	return rect
