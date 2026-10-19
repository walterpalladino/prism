## Brush pickup (`B`): box-select a region of the current cel; it becomes the brush
## (transparent index see-through), the mode switches to Replace, and the controller
## returns to the previous tool so the brush can be stamped right away (concept C4).
class_name BrushPickupTool
extends Tool

var _anchor: Vector2i
var _active: bool = false


func get_id() -> StringName:
	return &"brush_pickup"


func returns_to_previous_tool() -> bool:
	return true


func begin(pos: Vector2i, _button: PrismEnums.PaintButton, _mods: int) -> void:
	if state.editable_image() == null:
		return
	_anchor = pos
	_active = true
	state.set_pickup_rect(Tool.rect_from_corners(pos, pos))


func drag(pos: Vector2i, _mods: int) -> void:
	if _active:
		state.set_pickup_rect(Tool.rect_from_corners(_anchor, pos))


func end(pos: Vector2i, _mods: int) -> void:
	if not _active:
		return
	_active = false
	state.set_pickup_rect(Rect2i())
	var image: IndexedImage = state.editable_image()
	var cel: Cel = state.current_cel()
	var rect: Rect2i = Tool.rect_from_corners(_anchor, pos)
	rect.position -= cel.offset
	if not rect.intersection(image.get_rect()).has_area():
		return
	var region: IndexedImage = RasterOps.copy_region(image, rect, &"brush")
	state.set_custom_brush(Brush.from_image(region, bus.document.transparent_index))
	state.set_draw_mode(PrismEnums.DrawMode.REPLACE)


func cancel() -> void:
	_active = false
	state.set_pickup_rect(Rect2i())
