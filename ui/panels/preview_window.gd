## Floating preview of the animation at 1x or 2x (GDD §7.1, concept C1). It has its own
## Playback, so it can loop the current tag while the canvas stays on the frame being edited.
## Shares the canvas textures, so it costs no extra uploads.
class_name PreviewWindow
extends Window

const MARGIN: int = 8
const BAR_HEIGHT: int = 30

var preview_scale: int = 2
var playback: Playback

var _bus: CommandBus
var _state: EditorState
var _stack: CelStack
var _background: ColorRect
var _bar: HBoxContainer
var _play: Button
var _scale_button: Button


func setup(bus: CommandBus, state: EditorState, cache: CelTextureCache, palette_texture: PaletteTexture, cycling: ColorCycling) -> void:
	_bus = bus
	_state = state
	playback = Playback.new(bus)
	title = "Preview"
	unresizable = true
	transient = true
	Signals.on(close_requested, _on_close)
	_background = ColorRect.new()
	_background.color = PrismTheme.BG
	add_child(_background)
	_bar = HBoxContainer.new()
	_bar.position = Vector2(MARGIN, 2)
	add_child(_bar)
	_play = Button.new()
	_play.icon = PrismIcons.get_icon("play")
	_play.tooltip_text = "Play / stop the preview (loops the tag at the current frame)"
	_play.focus_mode = Control.FOCUS_NONE
	Signals.on(_play.pressed, func() -> void: playback.toggle(_state.frame_index))
	_bar.add_child(_play)
	_scale_button = Button.new()
	_scale_button.focus_mode = Control.FOCUS_NONE
	_scale_button.tooltip_text = "Toggle 1× / 2×"
	Signals.on(_scale_button.pressed, func() -> void: set_preview_scale(1 if preview_scale == 2 else 2))
	_bar.add_child(_scale_button)
	_stack = CelStack.new()
	_stack.setup(cache, palette_texture)
	add_child(_stack)
	Signals.on(playback.frame_changed, func(_index: int) -> void: _rebuild())
	Signals.on(playback.playing_changed, func(playing: bool) -> void:
		# Color cycling runs while the preview plays (GDD §7.6).
		cycling.request(&"preview", playing)
		_play.icon = PrismIcons.get_icon("pause" if playing else "play")
		_rebuild())
	Signals.on(bus.document_changed, func(_dirty: Rect2i) -> void: _rebuild())
	Signals.on(bus.document_replaced, _on_document_replaced)
	Signals.on(state.frame_changed, func(_index: int) -> void:
		if not playback.playing:
			_rebuild())
	_rebuild()


func _process(delta: float) -> void:
	if visible:
		playback.advance(delta * 1000.0)


func set_preview_scale(value: int) -> void:
	preview_scale = value
	_rebuild()


## The frame the preview is showing.
func shown_frame() -> int:
	return playback.frame if playback.playing else _state.frame_index


func _on_close() -> void:
	playback.stop()
	hide()


func _on_document_replaced() -> void:
	playback.stop()
	_rebuild()


func _rebuild() -> void:
	var doc: PrismDocument = _bus.document
	_scale_button.text = "%d×" % preview_scale
	_stack.scale = Vector2(preview_scale, preview_scale)
	_stack.position = Vector2(MARGIN, BAR_HEIGHT + MARGIN)
	_stack.rebuild(doc, clampi(shown_frame(), 0, doc.frames.size() - 1))
	var inner: Vector2i = Vector2i(doc.width, doc.height) * preview_scale
	size = Vector2i(maxi(inner.x + MARGIN * 2, 120), inner.y + MARGIN * 2 + BAR_HEIGHT)
	_background.size = Vector2(size)
