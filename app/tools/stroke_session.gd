## Scratch state for one stroke: a snapshot of the image before the stroke and the
## growing dirty rect. On commit it becomes exactly one PixelPatch (GDD §9.5).
class_name StrokeSession
extends RefCounted

var image: IndexedImage
var snapshot: IndexedImage
var dirty: Rect2i = Rect2i()


func _init(p_image: IndexedImage) -> void:
	image = p_image
	snapshot = p_image.duplicate_image(p_image.id)


func add_dirty(rect: Rect2i) -> void:
	if not rect.has_area():
		return
	dirty = rect if not dirty.has_area() else dirty.merge(rect)


## Puts the pre-stroke pixels back inside `rect` (used to redraw shape previews).
func restore(rect: Rect2i) -> void:
	var clipped: Rect2i = rect.intersection(image.get_rect())
	if clipped.has_area():
		RasterOps.write_rect(image, clipped, RasterOps.read_rect(snapshot, clipped))


## Returns the stroke as one PixelPatch, or null if no pixel actually changed.
func commit(label: String) -> PixelPatch:
	var area: Rect2i = dirty.intersection(image.get_rect())
	if not area.has_area():
		return null
	var patch: PixelPatch = PixelPatch.capture(snapshot, image, area, label)
	if patch.before == patch.after:
		return null
	return patch


## Abandons the stroke, restoring every touched pixel.
func cancel() -> void:
	restore(dirty)
	dirty = Rect2i()
