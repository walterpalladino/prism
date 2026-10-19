## Editor-wide selections that are not part of the document: colors, brush, mode,
## current layer/frame, tool options, selection and clipboard.
class_name EditorState
extends RefCounted

signal changed()
## The current frame changed (navigation or playback).
signal frame_changed(index: int)

const DEFAULT_BRUSH_SIZE: int = 1

var bus: CommandBus
var fg: int = 1
var bg: int = 0
var layer_index: int = 0
var frame_index: int = 0
var draw_mode: PrismEnums.DrawMode = PrismEnums.DrawMode.COLOR
var pixel_perfect: bool = true
var shade_wrap: bool = false
var builtin_shape: Brush.Shape = Brush.Shape.ROUND
var builtin_size: int = DEFAULT_BRUSH_SIZE
var brush: Brush
## True while `brush` is a picked-up (custom) brush.
var has_custom_brush: bool = false
var filled_shapes: bool = false
## Briefly highlight pixels the stencil protected (GDD §8.4).
var flash_stencil: bool = true
var global_fill: bool = false
## Canvas-space selection; an empty rect means no selection.
var selection: Rect2i = Rect2i()
## Canvas-space rect being dragged by Brush pickup, for the overlay.
var pickup_rect: Rect2i = Rect2i()
var clipboard: IndexedImage = null
## Inclusive frame range selected in the timeline (x = first, y = last).
var frame_range: Vector2i = Vector2i.ZERO
## Pixels of a copied cel (timeline copy/paste), or null.
var cel_clipboard: IndexedImage = null


func _init(p_bus: CommandBus) -> void:
	bus = p_bus
	brush = Brush.builtin(builtin_shape, builtin_size)


func palette_size() -> int:
	return bus.document.palette.size()


func set_fg(index: int) -> void:
	fg = clampi(index, 0, palette_size() - 1)
	changed.emit()


func set_bg(index: int) -> void:
	bg = clampi(index, 0, palette_size() - 1)
	changed.emit()


## `[` / `]`: steps FG through the palette, wrapping at the ends.
func step_fg(delta: int) -> void:
	set_fg(posmod(fg + delta, palette_size()))


## `{` / `}`: steps BG through the palette, wrapping at the ends.
func step_bg(delta: int) -> void:
	set_bg(posmod(bg + delta, palette_size()))


func set_draw_mode(mode: PrismEnums.DrawMode) -> void:
	draw_mode = mode
	changed.emit()


func set_builtin_brush(shape: Brush.Shape, size: int) -> void:
	builtin_shape = shape
	builtin_size = clampi(size, 1, Brush.MAX_BUILTIN_SIZE)
	restore_builtin_brush()


func restore_builtin_brush() -> void:
	brush = Brush.builtin(builtin_shape, builtin_size)
	has_custom_brush = false
	changed.emit()


func set_custom_brush(p_brush: Brush) -> void:
	brush = p_brush
	has_custom_brush = true
	changed.emit()


func flip_brush_h() -> void:
	brush = brush.flipped_h()
	changed.emit()


func flip_brush_v() -> void:
	brush = brush.flipped_v()
	changed.emit()


func rotate_brush() -> void:
	brush = brush.rotated_90()
	changed.emit()


func set_selection(rect: Rect2i) -> void:
	selection = rect
	changed.emit()


func set_pickup_rect(rect: Rect2i) -> void:
	pickup_rect = rect
	changed.emit()


## Moves to frame `index` (clamped) and selects just that frame.
func set_frame(index: int) -> void:
	var clamped: int = clampi(index, 0, bus.document.frames.size() - 1)
	frame_range = Vector2i(clamped, clamped)
	if clamped == frame_index:
		changed.emit()
		return
	frame_index = clamped
	frame_changed.emit(frame_index)
	changed.emit()


## Moves the playhead without touching the frame selection (used by playback).
func show_frame(index: int) -> void:
	var clamped: int = clampi(index, 0, bus.document.frames.size() - 1)
	if clamped != frame_index:
		frame_index = clamped
		frame_changed.emit(frame_index)


func set_layer(index: int) -> void:
	layer_index = clampi(index, 0, bus.document.layers.size() - 1)
	changed.emit()


func set_frame_range(first: int, last: int) -> void:
	var count: int = bus.document.frames.size()
	frame_range = Vector2i(clampi(mini(first, last), 0, count - 1), clampi(maxi(first, last), 0, count - 1))
	changed.emit()


## Keeps layer/frame indices and the frame selection inside the document (after undo, deletes).
func clamp_to_document() -> void:
	var doc: PrismDocument = bus.document
	layer_index = clampi(layer_index, 0, doc.layers.size() - 1)
	var previous: int = frame_index
	frame_index = clampi(frame_index, 0, doc.frames.size() - 1)
	frame_range = Vector2i(clampi(frame_range.x, 0, doc.frames.size() - 1), clampi(frame_range.y, 0, doc.frames.size() - 1))
	if frame_range.x > frame_range.y or not (frame_range.x <= frame_index and frame_index <= frame_range.y):
		frame_range = Vector2i(frame_index, frame_index)
	if previous != frame_index:
		frame_changed.emit(frame_index)
	changed.emit()


func make_ink_context(button: PrismEnums.PaintButton) -> InkContext:
	var ctx: InkContext = InkContext.new(fg, bg, button, bus.document.palette)
	ctx.shade_wrap = shade_wrap
	return ctx


func current_cel_key() -> Vector2i:
	return Vector2i(layer_index, frame_index)


## The cel being edited, or null when the cel is empty.
func current_cel() -> Cel:
	return bus.document.get_cel(layer_index, frame_index)


## The image being edited, or null if the cel is empty or its layer is locked or hidden.
func editable_image() -> IndexedImage:
	var doc: PrismDocument = bus.document
	if layer_index < 0 or layer_index >= doc.layers.size():
		return null
	var layer: Layer = doc.layers[layer_index]
	if layer.locked or not layer.visible:
		return null
	return doc.get_cel_image(layer_index, frame_index)


## Converts a canvas pixel to the current cel's image space (cels can be offset).
func to_image_space(canvas_pos: Vector2i) -> Vector2i:
	var cel: Cel = current_cel()
	return canvas_pos if cel == null else canvas_pos - cel.offset


## Topmost visible, non-transparent palette index at a canvas pixel (transparent index if none).
func index_at(canvas_pos: Vector2i) -> int:
	var doc: PrismDocument = bus.document
	for i: int in range(doc.layers.size() - 1, -1, -1):
		if not doc.layers[i].visible:
			continue
		var cel: Cel = doc.get_cel(i, frame_index)
		if cel == null:
			continue
		var image: IndexedImage = doc.images[cel.image_id]
		var p: Vector2i = canvas_pos - cel.offset
		if image.has_point(p.x, p.y):
			var value: int = image.get_index(p.x, p.y)
			if value != doc.transparent_index:
				return value
	return doc.transparent_index
