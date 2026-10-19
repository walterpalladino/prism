## Draws one frame of a document: one LUT-shaded Sprite2D per visible cel, bottom layer first.
## Compositing happens on the GPU (GDD §9.4). Used by the canvas and the preview window.
class_name CelStack
extends Node2D

const LUT_SHADER: Shader = preload("res://infra/render/palette_lut.gdshader")

var _cache: CelTextureCache
var _palette_texture: PaletteTexture


func setup(cache: CelTextureCache, palette_texture: PaletteTexture) -> void:
	_cache = cache
	_palette_texture = palette_texture


## Rebuilds the sprites for `frame_index`. `tint` (rgb + strength in a) and `opacity` are
## applied on top of each layer's own opacity; onion skin uses them.
func rebuild(doc: PrismDocument, frame_index: int, tint: Color = Color(1, 1, 1, 0), opacity: float = 1.0) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	for layer_index: int in doc.layers.size():
		var layer: Layer = doc.layers[layer_index]
		var cel: Cel = doc.get_cel(layer_index, frame_index)
		if not layer.visible or cel == null:
			continue
		var texture: ImageTexture = _cache.get_texture(doc.images[cel.image_id])
		var sprite: Sprite2D = make_sprite(texture, _palette_texture.texture, doc.transparent_index, layer.opacity / 255.0 * opacity)
		(sprite.material as ShaderMaterial).set_shader_parameter("tint", tint)
		sprite.position = Vector2(cel.offset)
		add_child(sprite)


## The palette LUT material for one R8 index texture.
static func make_material(index_texture: Texture2D, palette: Texture2D, transparent_index: int, opacity: float) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = LUT_SHADER
	material.set_shader_parameter("index_tex", index_texture)
	material.set_shader_parameter("palette_tex", palette)
	material.set_shader_parameter("transparent_index", transparent_index)
	material.set_shader_parameter("layer_opacity", opacity)
	return material


## A Sprite2D that renders an R8 index texture through the palette LUT.
static func make_sprite(index_texture: Texture2D, palette: Texture2D, transparent_index: int, opacity: float) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = index_texture
	sprite.material = make_material(index_texture, palette, transparent_index, opacity)
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return sprite
