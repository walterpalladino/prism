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
var raster_backend: RasterBackend
var textures: CelTextureCache
var palette_texture: PaletteTexture


func _init() -> void:
	raster_backend = GDScriptRasterBackend.new()
	bus = CommandBus.new(PrismDocument.create(DEFAULT_SIZE.x, DEFAULT_SIZE.y), History.new())
	state = EditorState.new(bus)
	selection = SelectionActions.new(bus, state)
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
	textures = CelTextureCache.new()
	palette_texture = PaletteTexture.new(bus.document.palette)


## Replaces the open document with a new blank one.
func new_document(size: Vector2i) -> void:
	tools.cancel()
	state.layer_index = 0
	state.frame_index = 0
	state.set_selection(Rect2i())
	bus.replace_document(PrismDocument.create(size.x, size.y))
