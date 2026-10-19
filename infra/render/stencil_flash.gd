## Briefly highlights pixels the stencil protected, so it is clear why paint "didn't stick"
## (GDD §8.4). Drawn in canvas space; each batch fades out over FLASH_SECONDS.
class_name StencilFlash
extends Node2D

const FLASH_SECONDS: float = 0.35
const COLOR: Color = Color("#ff8a3d")

## Each entry: [start time (s), PackedVector2Array of canvas pixel positions].
var _batches: Array[Array] = []


func flash(canvas_pixels: PackedVector2Array) -> void:
	if canvas_pixels.is_empty():
		return
	_batches.append([Time.get_ticks_msec() / 1000.0, canvas_pixels])
	queue_redraw()


func is_flashing() -> bool:
	return not _batches.is_empty()


func _process(_delta: float) -> void:
	if not _batches.is_empty():
		queue_redraw()


func _draw() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	var alive: Array[Array] = []
	for batch: Array in _batches:
		var started: float = batch[0]
		var age: float = now - started
		if age >= FLASH_SECONDS:
			continue
		alive.append(batch)
		var color: Color = Color(COLOR, 0.85 * (1.0 - age / FLASH_SECONDS))
		var pixels: PackedVector2Array = batch[1]
		for p: Vector2 in pixels:
			draw_rect(Rect2(p, Vector2.ONE), color)
	_batches = alive
