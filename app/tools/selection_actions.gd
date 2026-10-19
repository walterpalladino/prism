## Copy / cut / paste / arrow-key nudge for the rect selection (`M`).
## Each pixel-changing action is one undoable PixelPatch.
class_name SelectionActions
extends RefCounted

var bus: CommandBus
var state: EditorState


func _init(p_bus: CommandBus, p_state: EditorState) -> void:
	bus = p_bus
	state = p_state


func has_selection() -> bool:
	return state.selection.has_area()


## Copies the selected pixels of the current cel. Returns false if there is nothing to copy.
func copy() -> bool:
	var image: IndexedImage = _image()
	var area: Rect2i = _selection_in_image(image)
	if not area.has_area():
		return false
	state.clipboard = RasterOps.copy_region(image, area, &"clipboard")
	return true


## Copies, then clears the selection to the transparent index (respecting the stencil).
func cut() -> bool:
	if not copy():
		return false
	var image: IndexedImage = _image()
	var area: Rect2i = _selection_in_image(image)
	var session: StrokeSession = StrokeSession.new(image)
	_clear(image, area)
	session.add_dirty(area)
	_record(session, "Cut")
	return true


## Pastes the clipboard at the selection's top-left (or the canvas origin) and selects it.
func paste() -> bool:
	var image: IndexedImage = state.editable_image()
	if image == null or state.clipboard == null:
		return false
	var cel: Cel = state.current_cel()
	var canvas_at: Vector2i = state.selection.position if has_selection() else Vector2i.ZERO
	var session: StrokeSession = StrokeSession.new(image)
	var dirty: Rect2i = RasterOps.blit(image, state.clipboard, canvas_at - cel.offset, bus.document.transparent_index, bus.document.stencil)
	session.add_dirty(dirty)
	_record(session, "Paste")
	state.set_selection(Rect2i(canvas_at, state.clipboard.get_size()))
	return true


## Moves the selected pixels by `delta`, leaving transparency behind.
func nudge(delta: Vector2i) -> bool:
	var image: IndexedImage = _image()
	var area: Rect2i = _selection_in_image(image)
	if not area.has_area():
		return false
	var session: StrokeSession = StrokeSession.new(image)
	var moved: IndexedImage = RasterOps.copy_region(image, area, &"nudge")
	_clear(image, area)
	var placed: Rect2i = RasterOps.blit(image, moved, area.position + delta, bus.document.transparent_index, bus.document.stencil)
	session.add_dirty(area)
	session.add_dirty(placed)
	_record(session, "Move Selection")
	state.set_selection(Rect2i(state.selection.position + delta, state.selection.size))
	return true


func _image() -> IndexedImage:
	return state.editable_image() if has_selection() else null


func _selection_in_image(image: IndexedImage) -> Rect2i:
	if image == null:
		return Rect2i()
	var cel: Cel = state.current_cel()
	var rect: Rect2i = Rect2i(state.selection.position - cel.offset, state.selection.size)
	return rect.intersection(image.get_rect())


func _clear(image: IndexedImage, area: Rect2i) -> void:
	var transparent: int = bus.document.transparent_index
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var _changed: bool = RasterOps.write_pixel(image, x, y, transparent, bus.document.stencil)


func _record(session: StrokeSession, label: String) -> void:
	var patch: PixelPatch = session.commit(label)
	if patch != null:
		bus.record(patch)
