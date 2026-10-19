## Composition root and the project's only autoload.
##
## Builds the application services and infrastructure, and injects their
## dependencies through _init(). Services must never look this node up
## themselves; only UI scenes read from it.
extends Node

const DEFAULT_SIZE: Vector2i = Vector2i(64, 64)

var bus: CommandBus
var state: EditorState
var tools: ToolController
var selection: SelectionActions
var palette: PaletteActions
var timeline: TimelineActions
var playback: Playback
var cycling: ColorCycling
var palette_display: PaletteDisplay
var repository: DocumentRepository
var session: DocumentSession
var autosave: Autosave
var files: FileSink
var exports: ExportActions
## True when the previous run did not exit cleanly and left an autosave to recover.
var recovery_available: bool = false
var raster_backend: RasterBackend
var textures: CelTextureCache
var palette_texture: PaletteTexture


func _init() -> void:
	raster_backend = GDScriptRasterBackend.new()
	bus = CommandBus.new(PrismDocument.create(DEFAULT_SIZE.x, DEFAULT_SIZE.y), History.new())
	state = EditorState.new(bus)
	selection = SelectionActions.new(bus, state)
	palette = PaletteActions.new(bus, state)
	timeline = TimelineActions.new(bus, state)
	playback = Playback.new(bus)
	cycling = ColorCycling.new(bus)
	tools = ToolController.new()
	tools.register(PencilTool.new(bus, state))
	tools.register(PencilTool.new(bus, state, true))
	tools.register(ShapeTool.new(bus, state, ShapeTool.Kind.LINE))
	tools.register(ShapeTool.new(bus, state, ShapeTool.Kind.RECT))
	tools.register(ShapeTool.new(bus, state, ShapeTool.Kind.ELLIPSE))
	tools.register(FillTool.new(bus, state, raster_backend))
	tools.register(PickerTool.new(bus, state))
	tools.register(RectSelectTool.new(bus, state))
	tools.register(MoveCelTool.new(bus, state))
	tools.register(BrushPickupTool.new(bus, state))
	# Playback drives the playhead; starting a stroke stops it; stopping makes the shown frame
	# the edited one.
	Signals.on(playback.frame_changed, state.show_frame)
	Signals.on(playback.playing_changed, _on_playing_changed)
	Signals.on(tools.stroke_started, playback.stop)
	repository = ZipDocumentRepository.new()
	session = DocumentSession.new(bus, repository)
	autosave = Autosave.new(session, repository)
	recovery_available = autosave.begin_session()
	files = DiskFileSink.new()
	exports = ExportActions.new(bus, state, files)
	textures = CelTextureCache.new()
	palette_texture = PaletteTexture.new(bus.document.palette)
	palette_display = PaletteDisplay.new(palette_texture, cycling)


func _process(delta: float) -> void:
	playback.advance(delta * 1000.0)
	cycling.advance(delta)
	autosave.tick(delta)


func _on_playing_changed(playing: bool) -> void:
	# Color cycling runs during timeline playback (GDD §7.6).
	cycling.request(&"playback", playing)
	if not playing:
		state.set_frame(playback.frame)


## Replaces the open document with a new blank one.
func new_document(size: Vector2i) -> void:
	open_document(PrismDocument.create(size.x, size.y))


## Replaces the open document (new, demo, or loaded from disk in M6).
func open_document(document: PrismDocument) -> void:
	tools.cancel()
	playback.stop()
	palette.commit_color()
	state.layer_index = 0
	state.frame_index = 0
	state.frame_range = Vector2i.ZERO
	state.set_selection(Rect2i())
	session.start_new(document)


## Clean shutdown: waits for a running autosave and removes the crash-recovery files.
func shutdown() -> void:
	autosave.end_session()


## Opens a .prism file. Returns "" or an error (the current document is kept on error).
func open_file(path: String) -> String:
	tools.cancel()
	playback.stop()
	palette.commit_color()
	_reset_view_state()
	return session.open(path)


func _reset_view_state() -> void:
	state.layer_index = 0
	state.frame_index = 0
	state.frame_range = Vector2i.ZERO
	state.set_selection(Rect2i())
