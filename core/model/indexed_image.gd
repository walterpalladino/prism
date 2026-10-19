class_name IndexedImage
extends RefCounted

var id: StringName
var width: int
var height: int
## One palette index per pixel, row-major. In Godot 4.7 packed arrays are shared
## by reference on assignment and argument passing (see ADR 0005): call
## duplicate() whenever an independent copy is needed.
var pixels: PackedByteArray


func _init(p_id: StringName, p_width: int, p_height: int, p_fill: int = 0) -> void:
	assert(p_width > 0 and p_height > 0, "IndexedImage size must be positive")
	id = p_id
	width = p_width
	height = p_height
	pixels = PackedByteArray()
	var resize_error: int = pixels.resize(width * height)
	assert(resize_error == OK)
	if p_fill != 0:
		pixels.fill(p_fill)


func get_index(x: int, y: int) -> int:
	return pixels[y * width + x]


func set_index(x: int, y: int, value: int) -> void:
	pixels[y * width + x] = value


func has_point(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


func get_rect() -> Rect2i:
	return Rect2i(0, 0, width, height)


func get_size() -> Vector2i:
	return Vector2i(width, height)


func fill(value: int) -> void:
	pixels.fill(value)


## Deep copy with a new id; the pixel buffer is not shared.
func duplicate_image(p_id: StringName) -> IndexedImage:
	var copy: IndexedImage = IndexedImage.new(p_id, width, height)
	copy.pixels = pixels.duplicate()
	return copy


## Builds an image from row strings of hex digits (one digit per pixel, 0-f).
## Intended for tests and small built-in data.
static func from_rows(p_id: StringName, rows: PackedStringArray) -> IndexedImage:
	assert(rows.size() > 0)
	var image: IndexedImage = IndexedImage.new(p_id, rows[0].length(), rows.size())
	for y: int in rows.size():
		var row: String = rows[y]
		assert(row.length() == image.width, "from_rows: ragged row %d" % y)
		for x: int in row.length():
			image.set_index(x, y, row.substr(x, 1).hex_to_int())
	return image


## Inverse of from_rows. Indices above 15 are written as '+'.
func to_rows() -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	var resize_error: int = rows.resize(height)
	assert(resize_error == OK)
	for y: int in height:
		var row: String = ""
		for x: int in width:
			var value: int = get_index(x, y)
			row += "%x" % value if value < 16 else "+"
		rows[y] = row
	return rows
