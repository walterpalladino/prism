## A canvas tool driven by ToolController. Positions are canvas pixels.
@abstract
class_name Tool
extends RefCounted

const MOD_SHIFT: int = 1
const MOD_CTRL: int = 2
const MOD_ALT: int = 4

var bus: CommandBus
var state: EditorState


func _init(p_bus: CommandBus, p_state: EditorState) -> void:
	bus = p_bus
	state = p_state


@abstract func get_id() -> StringName


func begin(_pos: Vector2i, _button: PrismEnums.PaintButton, _mods: int) -> void:
	pass


func drag(_pos: Vector2i, _mods: int) -> void:
	pass


func end(_pos: Vector2i, _mods: int) -> void:
	pass


## Esc: abandons the in-progress operation, leaving no undo entry.
func cancel() -> void:
	pass


## True if the view should draw the brush ghost under the cursor.
func shows_brush_preview() -> bool:
	return false


## True if the controller should return to the previous tool after a completed stroke.
func returns_to_previous_tool() -> bool:
	return false


## Inclusive rect spanned by two corner pixels.
static func rect_from_corners(a: Vector2i, b: Vector2i) -> Rect2i:
	var top_left: Vector2i = Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var bottom_right: Vector2i = Vector2i(maxi(a.x, b.x), maxi(a.y, b.y))
	return Rect2i(top_left, bottom_right - top_left + Vector2i.ONE)


## Shift-constrains the corner `b` so the rect from `a` is square.
static func square_corner(a: Vector2i, b: Vector2i) -> Vector2i:
	var d: Vector2i = b - a
	var side: int = maxi(absi(d.x), absi(d.y))
	return a + Vector2i(side if d.x >= 0 else -side, side if d.y >= 0 else -side)
