class_name Palette
extends RefCounted

const MAX_COLORS: int = 256
const NO_RAMP: Vector2i = Vector2i(-1, -1)

var colors: PackedColorArray
## Shading ramps: inclusive [start, end] index spans, ordered dark to light, non-overlapping.
var ramps: Array[Vector2i] = []


## Palette entries are opaque 8-bit RGB: exactly what files store (#rrggbb), so a document in
## memory always equals its saved form. Transparency comes from the transparent index.
static func quantize(color: Color) -> Color:
	return Color8(color.r8, color.g8, color.b8)


func _init(p_colors: PackedColorArray = PackedColorArray()) -> void:
	assert(p_colors.size() <= MAX_COLORS)
	colors = p_colors.duplicate()
	for i: int in colors.size():
		colors[i] = quantize(colors[i])


func size() -> int:
	return colors.size()


func get_color(index: int) -> Color:
	return colors[index]


func set_color(index: int, color: Color) -> void:
	colors[index] = quantize(color)


func has_index(index: int) -> bool:
	return index >= 0 and index < colors.size()


## Adds a ramp; returns false (and changes nothing) if it is out of range or overlaps another ramp.
func add_ramp(start: int, end: int) -> bool:
	if start >= end or not has_index(start) or not has_index(end):
		return false
	for ramp: Vector2i in ramps:
		if start <= ramp.y and ramp.x <= end:
			return false
	ramps.append(Vector2i(start, end))
	ramps.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	return true


func remove_ramp(start: int) -> bool:
	for i: int in ramps.size():
		if ramps[i].x == start:
			ramps.remove_at(i)
			return true
	return false


## The ramp containing `index`, or NO_RAMP.
func find_ramp(index: int) -> Vector2i:
	for ramp: Vector2i in ramps:
		if index >= ramp.x and index <= ramp.y:
			return ramp
	return NO_RAMP


func duplicate_palette() -> Palette:
	var copy: Palette = Palette.new(colors)
	copy.ramps = ramps.duplicate()
	return copy


static func from_hex(hex_colors: PackedStringArray) -> Palette:
	var result: PackedColorArray = PackedColorArray()
	var resize_error: int = result.resize(hex_colors.size())
	assert(resize_error == OK)
	for i: int in hex_colors.size():
		result[i] = Color.html(hex_colors[i])
	return Palette.new(result)
