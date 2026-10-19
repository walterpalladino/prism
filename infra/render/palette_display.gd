## Keeps the shared palette LUT texture showing what the user should see: the cycled colors
## while color cycling runs, the document palette otherwise. The only writer of the texture.
class_name PaletteDisplay
extends RefCounted

var texture: PaletteTexture
var cycling: ColorCycling


func _init(p_texture: PaletteTexture, p_cycling: ColorCycling) -> void:
	texture = p_texture
	cycling = p_cycling
	Signals.on(cycling.colors_changed, texture.update_colors)
	texture.update_colors(cycling.current_colors())
