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


func rotate_180() -> String:
	return _replace_with("Rotate Cel 180°", func(image: IndexedImage) -> IndexedImage: return RasterOps.flipped_v(RasterOps.flipped_h(image)))


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
