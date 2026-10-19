## Stamps a brush onto an image through an ink, honoring the stencil.
##
## One Painter lives for one stroke: each destination pixel is changed at most
## once per stroke, so overlapping stamps (e.g. Shade along a path) do not
## compound. `dirty` accumulates the bounding box of changed pixels.
class_name Painter
extends RefCounted

var image: IndexedImage
var brush: Brush
var ink: Ink
var ctx: InkContext
var stencil: Stencil
var dirty: Rect2i = Rect2i()

var _touched: PackedByteArray


func _init(p_image: IndexedImage, p_brush: Brush, p_ink: Ink, p_ctx: InkContext, p_stencil: Stencil) -> void:
	image = p_image
	brush = p_brush
	ink = p_ink
	ctx = p_ctx
	stencil = p_stencil
	_touched = PackedByteArray()
	var resize_error: int = _touched.resize(image.width * image.height)
	assert(resize_error == OK)


## Stamps the brush with its anchor on `at`. Returns true if any pixel changed.
func stamp(at: Vector2i) -> bool:
	var origin: Vector2i = at - brush.anchor
	var area: Rect2i = Rect2i(origin, brush.get_size()).intersection(image.get_rect())
	if not area.has_area():
		return false
	var px: PackedByteArray = image.pixels
	var w: int = image.width
	var changed: bool = false
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var brush_value: int = brush.image.get_index(x - origin.x, y - origin.y)
			if brush_value == brush.transparent_index:
				continue
			var i: int = y * w + x
			if _touched[i] == 1:
				continue
			var dest: int = px[i]
			if stencil != null and stencil.is_locked(dest):
				continue
			var result: int = ink.apply(dest, brush_value, brush.is_mask, ctx)
			if result == Ink.SKIP or result == dest:
				continue
			px[i] = result
			_touched[i] = 1
			changed = true
			_grow_dirty(x, y)
	return changed


## Stamps at every point in order. Returns true if any pixel changed.
func stamp_points(points: Array[Vector2i]) -> bool:
	var changed: bool = false
	for p: Vector2i in points:
		if stamp(p):
			changed = true
	return changed


func _grow_dirty(x: int, y: int) -> void:
	var cell: Rect2i = Rect2i(x, y, 1, 1)
	dirty = cell if not dirty.has_area() else dirty.merge(cell)
