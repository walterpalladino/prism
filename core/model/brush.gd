## A paint brush: an indexed image stamped with its anchor on the target pixel.
class_name Brush
extends RefCounted

enum Shape { SQUARE, ROUND }

const MASK_VALUE: int = 1
const MAX_BUILTIN_SIZE: int = 8

var image: IndexedImage
var anchor: Vector2i
## Brush pixels with this index are see-through.
var transparent_index: int
## Built-in brushes are pure masks: inks paint them with the FG/BG color.
## Picked-up brushes carry their own pixel indices.
var is_mask: bool


func _init(p_image: IndexedImage, p_anchor: Vector2i, p_transparent_index: int, p_is_mask: bool) -> void:
	image = p_image
	anchor = p_anchor
	transparent_index = p_transparent_index
	is_mask = p_is_mask


func get_size() -> Vector2i:
	return image.get_size()


## Built-in brush of `size` x `size` pixels (1-8). Anchor is the center (rounded down).
static func builtin(shape: Shape, size: int) -> Brush:
	assert(size >= 1 and size <= MAX_BUILTIN_SIZE)
	var mask: IndexedImage = IndexedImage.new(&"brush", size, size)
	# Pixel centers within slightly less than size/2 of the center: 3 px is a plus, 6 px is round.
	var center_offset: float = (size - 1) / 2.0
	var radius: float = size / 2.0 - 0.1
	for y: int in size:
		for x: int in size:
			var inside: bool = true
			if shape == Shape.ROUND and size > 2:
				var dx: float = x - center_offset
				var dy: float = y - center_offset
				inside = dx * dx + dy * dy <= radius * radius
			if inside:
				mask.set_index(x, y, MASK_VALUE)
	var center: int = (size - 1) >> 1
	return Brush.new(mask, Vector2i(center, center), 0, true)


## A custom brush from picked-up pixels. Anchor defaults to the center.
static func from_image(p_image: IndexedImage, p_transparent_index: int) -> Brush:
	var center: Vector2i = Vector2i((p_image.width - 1) >> 1, (p_image.height - 1) >> 1)
	return Brush.new(p_image, center, p_transparent_index, false)


func flipped_h() -> Brush:
	var flipped: IndexedImage = RasterOps.flipped_h(image)
	return Brush.new(flipped, Vector2i(image.width - 1 - anchor.x, anchor.y), transparent_index, is_mask)


func flipped_v() -> Brush:
	var flipped: IndexedImage = RasterOps.flipped_v(image)
	return Brush.new(flipped, Vector2i(anchor.x, image.height - 1 - anchor.y), transparent_index, is_mask)


## Rotates 90 degrees clockwise.
func rotated_90() -> Brush:
	var rotated: IndexedImage = RasterOps.rotated_90_cw(image)
	return Brush.new(rotated, Vector2i(image.height - 1 - anchor.y, anchor.x), transparent_index, is_mask)
