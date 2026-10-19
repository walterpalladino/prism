## GDD §9.4 performance budgets, measured through the real app paths (tools, history, texture
## uploads, playback). Needs a real renderer:  godot --path . -s res://bench/budgets_bench.gd
extends SceneTree

const RUNS: int = 9
const PLAY_FRAMES: int = 240

var _view: CanvasView
var _bus: CommandBus
var _state: EditorState
var _playback: Playback
var _frames: int = 0
var _start: int = 0
var _results: Array[Array] = []


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	print("PRISM §9.4 budgets — %s, %s, %s" % [Engine.get_version_info()["string"], RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()])
	_bench_stroke_and_undo()
	_bench_flood_fill()
	_setup_playback()


func _bench_stroke_and_undo() -> void:
	var bus: CommandBus = CommandBus.new(PrismDocument.create(512, 512), History.new())
	var state: EditorState = EditorState.new(bus)
	var tools: ToolController = ToolController.new()
	tools.register(PencilTool.new(bus, state))
	tools.register(FillTool.new(bus, state, GDScriptRasterBackend.new()))
	var cache: CelTextureCache = CelTextureCache.new()
	var image: IndexedImage = bus.document.get_cel_image(0, 0)
	var _texture: ImageTexture = cache.get_texture(image)
	Signals.on(bus.image_changed, func(id: StringName, _d: Rect2i) -> void: cache.mark_dirty(id))
	state.set_builtin_brush(Brush.Shape.ROUND, 8)
	state.set_fg(9)
	tools.activate(&"pencil")
	tools.press(Vector2i(100, 100), PrismEnums.PaintButton.PRIMARY, 0)
	# Lambdas capture locals by value, so the moving position lives in an array.
	var cursor: PackedInt32Array = PackedInt32Array([100])
	var stroke_ms: float = BenchUtil.median_ms(func() -> void:
		cursor[0] += 16
		tools.motion(Vector2i(cursor[0] % 500, 100 + (cursor[0] / 500 * 9) % 300), 0)
		cache.flush(bus.document), RUNS * 4)
	tools.release(Vector2i(cursor[0] % 500, 100), 0)
	_record("stroke: 16 px drag, 8 px brush, 512² + texture upload (per event)", stroke_ms, 8.0)

	tools.activate(&"fill")
	tools.press(Vector2i(5, 5), PrismEnums.PaintButton.PRIMARY, 0)
	tools.release(Vector2i(5, 5), 0)
	var undo_ms: float = BenchUtil.median_ms(func() -> void:
		var _u: bool = bus.undo()
		cache.flush(bus.document)
		var _r: bool = bus.redo()
		cache.flush(bus.document), RUNS) / 2.0
	_record("full-canvas undo 512² (PixelPatch + texture upload)", undo_ms, 16.0)


func _bench_flood_fill() -> void:
	var noisy: IndexedImage = BenchUtil.noise_image(512, 2, 0.3, 7)
	var ms: float = BenchUtil.median_ms(func() -> void:
		var image: IndexedImage = noisy.duplicate_image(&"b")
		var _d: Rect2i = RasterOps.flood_fill(image, Vector2i(0, 0), 5, null), RUNS)
	_record("flood fill 512², 30% noise walls (worst case)", ms, 50.0)


func _setup_playback() -> void:
	_bus = CommandBus.new(PrismDocument.create(256, 256), History.new())
	_state = EditorState.new(_bus)
	var timeline: TimelineActions = TimelineActions.new(_bus, _state)
	for i: int in 3:
		timeline.add_layer()
	for i: int in 7:
		timeline.insert_frame(i + 1)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2
	for image: IndexedImage in _bus.document.images.values():
		for i: int in image.pixels.size():
			image.pixels[i] = rng.randi_range(0, 31) if rng.randf() < 0.4 else 0
	_view = CanvasView.new()
	_view.size = Vector2(1000, 700)
	root.add_child(_view)
	var tools: ToolController = ToolController.new()
	tools.register(PencilTool.new(_bus, _state))
	_view.setup(_bus, _state, tools, CelTextureCache.new(), PaletteTexture.new(_bus.document.palette))
	_state.set_onion(true, 3, 2, false)
	_playback = Playback.new(_bus)
	Signals.on(_playback.frame_changed, _state.show_frame)
	Signals.on(_playback.playing_changed, _view.set_playing)
	_playback.play_from(0)


func _process(delta: float) -> bool:
	_playback.advance(delta * 1000.0)
	_frames += 1
	if _frames == 30:
		_start = Time.get_ticks_usec()
	elif _frames == 30 + PLAY_FRAMES:
		var ms: float = (Time.get_ticks_usec() - _start) / 1000.0 / PLAY_FRAMES
		_record("playback 256² × 4 layers × 8 frames, onion 3/2 on (%.0f fps)" % (1000.0 / ms), ms, 16.7)
		print("")
		var all_ok: bool = true
		for result: Array in _results:
			var label: String = result[0]
			var value: float = result[1]
			var budget: float = result[2]
			BenchUtil.report(label, value, budget)
			all_ok = all_ok and value <= budget
		print("\nALL BUDGETS MET" if all_ok else "\nSOME BUDGETS MISSED")
		return true
	return false


func _record(label: String, ms: float, budget: float) -> void:
	_results.append([label, ms, budget])
