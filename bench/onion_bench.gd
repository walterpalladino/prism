## M5 exit benchmark: onion skin at 3 past / 2 future on a 256x256, 4-layer, 8-frame document,
## with color cycling updating the LUT, must stay at or above 60 fps (frame time <= 16.7 ms).
## Needs a real renderer:  godot --path . -s res://bench/onion_bench.gd
extends SceneTree

const WARMUP: int = 30
const MEASURE: int = 240
const SIZE: int = 256

var _frames: int = 0
var _start: int = 0
var _view: CanvasView
var _fx_bus: CommandBus
var _cycling: ColorCycling
var _phase: int = 0


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var bus: CommandBus = CommandBus.new(PrismDocument.create(SIZE, SIZE), History.new())
	var state: EditorState = EditorState.new(bus)
	var timeline: TimelineActions = TimelineActions.new(bus, state)
	for i: int in 3:
		timeline.add_layer()
	for i: int in 7:
		timeline.insert_frame(i + 1)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1
	for image: IndexedImage in bus.document.images.values():
		for i: int in image.pixels.size():
			image.pixels[i] = rng.randi_range(0, 31) if rng.randf() < 0.4 else 0
	var palette: PaletteActions = PaletteActions.new(bus, state)
	var _error: String = palette.add_cycle(16, 21, 30.0, 1)
	_cycling = ColorCycling.new(bus)
	var texture: PaletteTexture = PaletteTexture.new(bus.document.palette)
	var _display: PaletteDisplay = PaletteDisplay.new(texture, _cycling)
	_view = CanvasView.new()
	_view.size = Vector2(1000, 700)
	root.add_child(_view)
	var tools: ToolController = ToolController.new()
	tools.register(PencilTool.new(bus, state))
	_view.setup(bus, state, tools, CelTextureCache.new(), texture)
	state.set_frame(4)
	state.set_onion(true, 3, 2, false)
	_cycling.request(&"bench", true)
	_fx_bus = bus
	print("PRISM onion benchmark — %s, %s; %dx%d, 4 layers, 8 frames; onion frames drawn: %d" % [
		RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name(), SIZE, SIZE, _view.onion_frame_count()])


func _process(delta: float) -> bool:
	_cycling.advance(delta)
	_frames += 1
	if _frames == WARMUP:
		_start = Time.get_ticks_usec()
	elif _frames == WARMUP + MEASURE:
		var ms: float = (Time.get_ticks_usec() - _start) / 1000.0 / MEASURE
		BenchUtil.report("frame time, onion 3 past / 2 future + cycling (%.0f fps)" % (1000.0 / ms), ms, 16.7)
		return true
	return false
