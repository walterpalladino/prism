## Spike A correctness: renders known indices through palette_lut.gdshader and reads the
## framebuffer back. Needs a real renderer:  godot --path . -s res://bench/lut_check.gd
extends SceneTree

const INDICES: PackedByteArray = [0, 1, 9, 27, 31]
const SCALE: int = 32

var _frames: int = 0
var _palette: Palette = PalettePresets.default_32()


func _initialize() -> void:
	RenderingServer.set_default_clear_color(Color.MAGENTA)
	var image: Image = Image.create_from_data(INDICES.size(), 1, false, Image.FORMAT_R8, INDICES)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	var palette_image: Image = Image.create_empty(256, 1, false, Image.FORMAT_RGBA8)
	for i: int in _palette.size():
		palette_image.set_pixel(i, 0, _palette.get_color(i))
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://infra/render/palette_lut.gdshader")
	material.set_shader_parameter("index_tex", texture)
	material.set_shader_parameter("palette_tex", ImageTexture.create_from_image(palette_image))
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = texture
	sprite.material = material
	sprite.centered = false
	sprite.scale = Vector2(SCALE, SCALE)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(sprite)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 5:
		return false
	var shot: Image = root.get_texture().get_image()
	var failures: int = 0
	for i: int in INDICES.size():
		var got: Color = shot.get_pixel(i * SCALE + (SCALE >> 1), SCALE >> 1)
		var want: Color = Color.MAGENTA if INDICES[i] == 0 else _palette.get_color(INDICES[i])
		var ok: bool = _close(got, want)
		print("index %3d -> %s  expected %s  %s" % [INDICES[i], got.to_html(false), want.to_html(false), "OK" if ok else "MISMATCH"])
		if not ok:
			failures += 1
	print("LUT check: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	return true


func _close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01
