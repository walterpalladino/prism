## Floating preview of the current frame at 1x or 2x (GDD §7.1, concept C1). Shares the
## canvas textures, so it costs no extra uploads. Independent playback arrives with M4.
class_name PreviewWindow
extends Window

const MARGIN: int = 8

var preview_scale: int = 2

var _bus: CommandBus
var _state: EditorState
var _stack: CelStack
var _background: ColorRect


func setup(bus: CommandBus, state: EditorState, cache: CelTextureCache, palette_texture: PaletteTexture) -> void:
	_bus = bus
	_state = state
	title = "Preview"
	unresizable = true
	transient = true
	Signals.on(close_requested, hide)
	_background = ColorRect.new()
	_background.color = PrismTheme.BG
	add_child(_background)
	_stack = CelStack.new()
	_stack.setup(cache, palette_texture)
	add_child(_stack)
	Signals.on(bus.document_changed, func(_dirty: Rect2i) -> void: _rebuild())
	Signals.on(bus.document_replaced, _rebuild)
	_rebuild()


func set_preview_scale(value: int) -> void:
	preview_scale = value
	_rebuild()


func _rebuild() -> void:
	var doc: PrismDocument = _bus.document
	_stack.scale = Vector2(preview_scale, preview_scale)
	_stack.position = Vector2(MARGIN, MARGIN)
	_stack.rebuild(doc, _state.frame_index)
	var inner: Vector2i = Vector2i(doc.width, doc.height) * preview_scale
	size = inner + Vector2i(MARGIN, MARGIN) * 2
	_background.size = Vector2(size)
