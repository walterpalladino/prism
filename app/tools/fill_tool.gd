## Fill (`F`): contiguous 4-way flood fill, or global replace when EditorState.global_fill
## is set (`Shift+F`). Paints FG with the primary button, BG with the secondary.
class_name FillTool
extends Tool

var backend: RasterBackend


func _init(p_bus: CommandBus, p_state: EditorState, p_backend: RasterBackend) -> void:
	super(p_bus, p_state)
	backend = p_backend


func get_id() -> StringName:
	return &"fill"


func begin(pos: Vector2i, button: PrismEnums.PaintButton, _mods: int) -> void:
	var image: IndexedImage = state.editable_image()
	if image == null:
		return
	var p: Vector2i = state.to_image_space(pos)
	if not image.has_point(p.x, p.y):
		return
	var value: int = state.make_ink_context(button).paint_index()
	var session: StrokeSession = StrokeSession.new(image)
	var stencil: Stencil = bus.document.stencil
	var dirty: Rect2i
	if state.global_fill:
		dirty = backend.replace_index(image, image.get_index(p.x, p.y), value, stencil)
	else:
		dirty = backend.flood_fill(image, p, value, stencil)
	session.add_dirty(dirty)
	if not dirty.has_area() and stencil.is_locked(image.get_index(p.x, p.y)):
		bus.notify_stencil_blocked(image.id, PackedInt32Array([p.y * image.width + p.x]))
	var patch: PixelPatch = session.commit("Fill")
	if patch != null:
		bus.record(patch)
