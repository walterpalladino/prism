## The shared 256x1 RGBA8 palette lookup texture used by palette_lut.gdshader (GDD §9.4).
class_name PaletteTexture
extends RefCounted

var texture: ImageTexture

var _image: Image


func _init(palette: Palette) -> void:
	_image = Image.create_empty(Palette.MAX_COLORS, 1, false, Image.FORMAT_RGBA8)
	texture = ImageTexture.create_from_image(_image)
	update(palette)


## Re-uploads all entries; unused slots are transparent black.
func update(palette: Palette) -> void:
	for i: int in Palette.MAX_COLORS:
		_image.set_pixel(i, 0, palette.get_color(i) if i < palette.size() else Color(0, 0, 0, 0))
	texture.update(_image)


func get_color(index: int) -> Color:
	return _image.get_pixel(index, 0)
