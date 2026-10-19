## Whole-cel effects for the Picture and Effect menus. Each is one undoable PixelPatch and
## respects the stencil and the layer lock.
class_name CelEffects
extends RefCounted

var bus: CommandBus
var state: EditorState


func _init(p_bus: CommandBus, p_state: EditorState) -> void:
	bus = p_bus
	state = p_state


func flip_horizontal() -> String:
	return _replace_with("Flip Cel Horizontally", func(image: IndexedImage) -> IndexedImage: return RasterOps.flipped_h(image))


func flip_vertical() -> String:
	return _replace_with("Flip Cel Vertically", func(image: IndexedImage) -> IndexedImage: return RasterOps.flipped_v(image))


## Rotates the cel a quarter turn around the canvas center. Exact on square canvases; on
## other sizes pixels that land outside the canvas are cut off. Returns "" or a notice saying
## how many drawn pixels were cut off (Undo restores them).
func rotate_90(clockwise: bool) -> String:
	var image: IndexedImage = state.editable_image()
	if image == null:
		return "the current layer is locked or hidden"
	var transparent: int = bus.document.transparent_index
	var rotated: IndexedImage = IndexedImage.new(&"rotated", image.width, image.height, transparent)
	var lost: int = 0
	var w: int = image.width
	var h: int = image.height
	for y: int in h:
		for x: int in w:
			var value: int = image.get_index(x, y)
			var target: Vector2i = rotated_position(Vector2i(x, y), Vector2i(w, h), clockwise)
			if rotated.has_point(target.x, target.y):
				rotated.set_index(target.x, target.y, value)
			elif value != transparent:
				lost += 1
	var error: String = _replace_with("Rotate Cel 90° CW" if clockwise else "Rotate Cel 90° CCW", func(_source: IndexedImage) -> IndexedImage: return rotated)
	if error != "" or lost == 0:
		return error
	return "%d pixel%s fell outside the %d×%d canvas and were cut off (Undo restores them)." % [lost, "" if lost == 1 else "s", w, h]


## Where pixel `p` of a `size` canvas goes after a quarter turn around the canvas center.
## Works on doubled coordinates so pixel centers stay exact; on canvases whose width and
## height differ in parity the result is rounded down by half a pixel.
static func rotated_position(p: Vector2i, size: Vector2i, clockwise: bool) -> Vector2i:
	var dx: int = 2 * p.x - (size.x - 1)
	var dy: int = 2 * p.y - (size.y - 1)
	var rx: int = -dy if clockwise else dy
	var ry: int = dx if clockwise else -dx
	return Vector2i(floori((rx + size.x - 1) / 2.0), floori((ry + size.y - 1) / 2.0))


## Paints FG on every transparent pixel that touches (4-way) a non-transparent one.
func outline_with_fg() -> String:
	var image: IndexedImage = state.editable_image()
	if image == null:
		return "the current layer is locked or hidden"
	var transparent: int = bus.document.transparent_index
	var session: StrokeSession = StrokeSession.new(image)
	var source: PackedByteArray = session.snapshot.pixels
	var w: int = image.width
	var h: int = image.height
	for y: int in h:
		for x: int in w:
			var i: int = y * w + x
			if source[i] != transparent:
				continue
			var touches: bool = (x > 0 and source[i - 1] != transparent) or (x < w - 1 and source[i + 1] != transparent) \
				or (y > 0 and source[i - w] != transparent) or (y < h - 1 and source[i + w] != transparent)
			if touches and RasterOps.write_pixel(image, x, y, state.fg, bus.document.stencil):
				session.add_dirty(Rect2i(x, y, 1, 1))
	return _record(session, "Outline")


## Replaces every FG pixel of the cel with BG (global fill).
func replace_fg_with_bg() -> String:
	var image: IndexedImage = state.editable_image()
	if image == null:
		return "the current layer is locked or hidden"
	var session: StrokeSession = StrokeSession.new(image)
	session.add_dirty(RasterOps.replace_index(image, state.fg, state.bg, bus.document.stencil))
	return _record(session, "Replace Color")


func select_all() -> void:
	state.set_selection(Rect2i(0, 0, bus.document.width, bus.document.height))


func _replace_with(label: String, transform: Callable) -> String:
	var image: IndexedImage = state.editable_image()
	if image == null:
		return "the current layer is locked or hidden"
	var session: StrokeSession = StrokeSession.new(image)
	var result: IndexedImage = transform.call(session.snapshot)
	var stencil: Stencil = bus.document.stencil
	for y: int in image.height:
		for x: int in image.width:
			var _changed: bool = RasterOps.write_pixel(image, x, y, result.get_index(x, y), stencil)
	session.add_dirty(image.get_rect())
	return _record(session, label)


func _record(session: StrokeSession, label: String) -> String:
	var patch: PixelPatch = session.commit(label)
	if patch != null:
		bus.record(patch)
	return ""
