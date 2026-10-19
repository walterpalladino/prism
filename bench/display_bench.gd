## Spike A (display) + GPU half of Spike B. Needs a real renderer (not --headless):
##   godot --path . -s res://bench/display_bench.gd                       (Compatibility, project default)
##   godot --path . --rendering-method forward_plus -s res://bench/display_bench.gd
extends SceneTree

const UPLOAD_RUNS: int = 30
const WARMUP_FRAMES: int = 30
const MEASURE_FRAMES: int = 240
const TILE: int = 64

var _palette_texture: ImageTexture
var _shader: Shader
var _phase: int = 0
var _frame: int = 0
var _phase_start_usec: int = 0
var _layers: Array[Sprite2D] = []
var _paint_image: Image
var _paint_texture: ImageTexture
var _paint_pixels: PackedByteArray
var _paint_tiles: Array[ImageTexture] = []
var _tile_image: Image


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	print("PRISM display benchmark — renderer: %s, adapter: %s" % [
		RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()])
	_shader = load("res://infra/render/palette_lut.gdshader")
	_palette_texture = _make_palette_texture()
	_bench_uploads()


func _process(_delta: float) -> bool:
	_frame += 1
	match _phase:
		0:
			_setup_scene(512, 4)
			_start_phase()
		1, 2, 3:
			if _phase == 2:
				_paint_full_upload()
			elif _phase == 3:
				_paint_tile_upload()
			if _frame == WARMUP_FRAMES:
				_phase_start_usec = Time.get_ticks_usec()
			elif _frame == WARMUP_FRAMES + MEASURE_FRAMES:
				var ms: float = (Time.get_ticks_usec() - _phase_start_usec) / 1000.0 / MEASURE_FRAMES
				var label: String = ["", "idle: 4 layers 512x512 @ 4x zoom", "painting: + full 512x512 texture update / frame", "painting: + one 64x64 tile update / frame"][_phase]
				BenchUtil.report("frame time, " + label + " (%.0f fps)" % (1000.0 / ms), ms, 16.7)
				_start_phase()
		4:
			return true
	return false


func _start_phase() -> void:
	_phase += 1
	_frame = 0


func _bench_uploads() -> void:
	print("\n-- Texture upload cost (CPU side of ImageTexture.update)")
	for size: int in [256, 512, 1024]:
		var pixels: PackedByteArray = BenchUtil.noise_image(size, 32, 1.0, size).pixels
		var image: Image = Image.create_from_data(size, size, false, Image.FORMAT_R8, pixels)
		var texture: ImageTexture = ImageTexture.create_from_image(image)
		var ms: float = BenchUtil.median_ms(func() -> void:
			pixels[0] = (pixels[0] + 1) % 32
			image.set_data(size, size, false, Image.FORMAT_R8, pixels)
			texture.update(image), UPLOAD_RUNS)
		BenchUtil.report("set_data + update %dx%d R8" % [size, size], ms, 8.0)
	var tile_pixels: PackedByteArray = BenchUtil.noise_image(TILE, 32, 1.0, 1).pixels
	var tile_image: Image = Image.create_from_data(TILE, TILE, false, Image.FORMAT_R8, tile_pixels)
	var tile_texture: ImageTexture = ImageTexture.create_from_image(tile_image)
	BenchUtil.report("set_data + update %dx%d tile" % [TILE, TILE], BenchUtil.median_ms(func() -> void:
		tile_image.set_data(TILE, TILE, false, Image.FORMAT_R8, tile_pixels)
		tile_texture.update(tile_image), UPLOAD_RUNS))
	var src: IndexedImage = BenchUtil.noise_image(512, 32, 1.0, 9)
	BenchUtil.report("extract a 64x64 tile from a 512x512 cel (read_rect)", BenchUtil.median_ms(func() -> void:
		var _bytes: PackedByteArray = RasterOps.read_rect(src, Rect2i(128, 128, TILE, TILE)), UPLOAD_RUNS))
	print("\n-- Rendering (vsync off; 16.7 ms = 60 fps)")


func _setup_scene(size: int, layer_count: int) -> void:
	var camera: Camera2D = Camera2D.new()
	camera.zoom = Vector2(4, 4)
	camera.position = Vector2(size / 2.0, size / 2.0)
	root.add_child(camera)
	for i: int in layer_count:
		var pixels: PackedByteArray = BenchUtil.noise_image(size, 32, 0.5, 100 + i).pixels
		var image: Image = Image.create_from_data(size, size, false, Image.FORMAT_R8, pixels)
		var sprite: Sprite2D = _make_layer_sprite(ImageTexture.create_from_image(image))
		sprite.position = Vector2(size / 2.0, size / 2.0)
		root.add_child(sprite)
		_layers.append(sprite)
		if i == layer_count - 1:
			_paint_pixels = pixels
			_paint_image = image
			_paint_texture = sprite.texture as ImageTexture
	_tile_image = Image.create_from_data(TILE, TILE, false, Image.FORMAT_R8, RasterOps.read_rect(BenchUtil.noise_image(size, 32, 1.0, 5), Rect2i(0, 0, TILE, TILE)))
	for i: int in 64:
		_paint_tiles.append(ImageTexture.create_from_image(_tile_image))


func _paint_full_upload() -> void:
	_paint_pixels[_frame % _paint_pixels.size()] = _frame % 32
	_paint_image.set_data(512, 512, false, Image.FORMAT_R8, _paint_pixels)
	_paint_texture.update(_paint_image)


func _paint_tile_upload() -> void:
	_paint_tiles[_frame % _paint_tiles.size()].update(_tile_image)


func _make_layer_sprite(texture: Texture2D) -> Sprite2D:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter("palette_tex", _palette_texture)
	material.set_shader_parameter("index_tex", texture)
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = texture
	sprite.material = material
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return sprite


func _make_palette_texture() -> ImageTexture:
	var image: Image = Image.create_empty(256, 1, false, Image.FORMAT_RGBA8)
	var palette: Palette = PalettePresets.default_32()
	for i: int in palette.size():
		image.set_pixel(i, 0, palette.get_color(i))
	return ImageTexture.create_from_image(image)
