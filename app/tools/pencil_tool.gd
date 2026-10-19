## Pencil (`D`) and Eraser (`E`): freehand strokes with the current brush, interpolated
## with Bresenham between pointer events. Pixel-perfect applies to 1x1 brushes.
class_name PencilTool
extends Tool

var erase: bool

var _session: StrokeSession
var _painter: Painter
var _last: Vector2i
## The last two kept points, for pixel-perfect corner removal.
var _recent: Array[Vector2i] = []


func _init(p_bus: CommandBus, p_state: EditorState, p_erase: bool = false) -> void:
	super(p_bus, p_state)
	erase = p_erase


func get_id() -> StringName:
	return &"eraser" if erase else &"pencil"


func shows_brush_preview() -> bool:
	return true


func begin(pos: Vector2i, button: PrismEnums.PaintButton, _mods: int) -> void:
	var image: IndexedImage = state.editable_image()
	if image == null:
		return
	var doc: PrismDocument = bus.document
	_session = StrokeSession.new(image)
	var ctx: InkContext = state.make_ink_context(button)
	var ink: Ink = Ink.for_mode(state.draw_mode)
	if erase:
		ctx.fg = doc.transparent_index
		ctx.bg = doc.transparent_index
		ink = ColorInk.new()
	_painter = Painter.new(image, state.brush, ink, ctx, doc.stencil)
	_recent.clear()
	_last = state.to_image_space(pos)
	_plot(_last)
	_publish()


func drag(pos: Vector2i, _mods: int) -> void:
	if _session == null:
		return
	var target: Vector2i = state.to_image_space(pos)
	if target == _last:
		return
	var points: Array[Vector2i] = RasterOps.line_points(_last, target)
	for i: int in range(1, points.size()):
		_plot(points[i])
	_last = target
	_publish()


func end(_pos: Vector2i, _mods: int) -> void:
	if _session == null:
		return
	var patch: PixelPatch = _session.commit("Erase" if erase else "Pencil")
	if patch != null:
		bus.record(patch)
	_session = null
	_painter = null


func cancel() -> void:
	if _session == null:
		return
	_session.cancel()
	bus.notify_image_changed(_session.image.id, _session.image.get_rect())
	_session = null
	_painter = null


func _plot(p: Vector2i) -> void:
	if _uses_pixel_perfect() and _recent.size() == 2:
		var a: Vector2i = _recent[0]
		var c: Vector2i = _recent[1]
		var c_touches_a: bool = a.x == c.x or a.y == c.y
		var c_touches_p: bool = p.x == c.x or p.y == c.y
		if c_touches_a and c_touches_p and a.x != p.x and a.y != p.y:
			_painter.unstamp(c, _session.snapshot)
			_recent.pop_back()
	var _changed: bool = _painter.stamp(p)
	_recent.append(p)
	if _recent.size() > 2:
		_recent.pop_front()


func _uses_pixel_perfect() -> bool:
	return state.pixel_perfect and state.brush.get_size() == Vector2i.ONE


func _publish() -> void:
	_session.add_dirty(_painter.dirty)
	bus.notify_image_changed(_session.image.id, _painter.dirty)
