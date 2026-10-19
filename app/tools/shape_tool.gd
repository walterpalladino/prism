## Line (`L`), Rectangle (`R`) and Ellipse (`O`): drag from an anchor; the shape is
## redrawn from the pre-stroke snapshot on every move and committed on release.
## Shift constrains lines to 0/45/90° and 1:2 / 2:1, and rects/ellipses to squares/circles.
class_name ShapeTool
extends Tool

enum Kind { LINE, RECT, ELLIPSE }

const LABELS: PackedStringArray = ["Line", "Rectangle", "Ellipse"]

var kind: Kind

var _session: StrokeSession
var _anchor: Vector2i
var _button: PrismEnums.PaintButton
var _previous: Rect2i = Rect2i()
var _last_painter: Painter


func _init(p_bus: CommandBus, p_state: EditorState, p_kind: Kind) -> void:
	super(p_bus, p_state)
	kind = p_kind


func get_id() -> StringName:
	match kind:
		Kind.LINE:
			return &"line"
		Kind.RECT:
			return &"rect"
	return &"ellipse"


func shows_brush_preview() -> bool:
	return true


func begin(pos: Vector2i, button: PrismEnums.PaintButton, mods: int) -> void:
	var image: IndexedImage = state.editable_image()
	if image == null:
		return
	_session = StrokeSession.new(image)
	_anchor = state.to_image_space(pos)
	_button = button
	_previous = Rect2i()
	_render(_anchor, mods)


func drag(pos: Vector2i, mods: int) -> void:
	if _session != null:
		_render(state.to_image_space(pos), mods)


func end(pos: Vector2i, mods: int) -> void:
	if _session == null:
		return
	_render(state.to_image_space(pos), mods)
	bus.notify_stencil_blocked(_session.image.id, _last_painter.blocked)
	var patch: PixelPatch = _session.commit(LABELS[kind])
	if patch != null:
		bus.record(patch)
	_session = null


func cancel() -> void:
	if _session == null:
		return
	_session.cancel()
	bus.notify_image_changed(_session.image.id, _session.image.get_rect())
	_session = null


## Shape pixels for an anchor and current point (image space), honoring Shift.
func shape_points(anchor: Vector2i, current: Vector2i, mods: int) -> Array[Vector2i]:
	var constrain: bool = (mods & MOD_SHIFT) != 0
	match kind:
		Kind.LINE:
			var end_point: Vector2i = RasterOps.constrain_line_end(anchor, current) if constrain else current
			return RasterOps.line_points(anchor, end_point)
		Kind.RECT:
			var corner: Vector2i = Tool.square_corner(anchor, current) if constrain else current
			return RasterOps.rect_points(Tool.rect_from_corners(anchor, corner), state.filled_shapes)
	var ellipse_corner: Vector2i = Tool.square_corner(anchor, current) if constrain else current
	return RasterOps.ellipse_points(Tool.rect_from_corners(anchor, ellipse_corner), state.filled_shapes)


func _render(current: Vector2i, mods: int) -> void:
	var image: IndexedImage = _session.image
	_session.restore(_previous)
	var painter: Painter = Painter.new(image, state.brush, Ink.for_mode(state.draw_mode), state.make_ink_context(_button), bus.document.stencil)
	var _changed: bool = painter.stamp_points(shape_points(_anchor, current, mods))
	_last_painter = painter
	var refresh: Rect2i = _previous
	if painter.dirty.has_area():
		refresh = painter.dirty if not refresh.has_area() else refresh.merge(painter.dirty)
	_previous = painter.dirty
	_session.add_dirty(painter.dirty)
	if refresh.has_area():
		bus.notify_image_changed(image.id, refresh)
