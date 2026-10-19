## Marching ants for the rect selection and the brush-pickup box, drawn in canvas space.
class_name SelectionOverlay
extends Node2D

const DASH_SCREEN_PX: float = 4.0
const ANT_SPEED: float = 12.0
const PICKUP_COLOR: Color = Color("#ff8a3d")

var selection: Rect2i = Rect2i()
var pickup: Rect2i = Rect2i()
var zoom: float = 1.0


func _process(_delta: float) -> void:
	if selection.has_area():
		queue_redraw()


func _draw() -> void:
	if pickup.has_area():
		draw_rect(Rect2(pickup), PICKUP_COLOR, false, -1.0)
	if selection.has_area():
		_draw_ants(Rect2(selection))


func _draw_ants(rect: Rect2) -> void:
	var dash: float = DASH_SCREEN_PX / zoom
	var phase: float = fmod(Time.get_ticks_msec() / 1000.0 * ANT_SPEED / zoom, dash * 2.0)
	var corners: PackedVector2Array = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	var travelled: float = 0.0
	for i: int in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var length: float = a.distance_to(b)
		var dir: Vector2 = (b - a) / length
		var t: float = 0.0
		while t < length:
			var segment_index: int = floori((travelled + t + phase) / dash)
			var next_t: float = minf(length, (segment_index + 1) * dash - travelled - phase)
			if next_t <= t:
				next_t = minf(length, t + dash)
			draw_line(a + dir * t, a + dir * next_t, Color.WHITE if segment_index % 2 == 0 else Color.BLACK, -1.0)
			t = next_t
		travelled += length
