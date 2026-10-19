## Timing helpers shared by the benchmark scripts in res://bench/.
class_name BenchUtil
extends RefCounted


## Runs `body` `runs` times and returns the median in milliseconds.
static func median_ms(body: Callable, runs: int) -> float:
	var samples: PackedFloat64Array = PackedFloat64Array()
	for i: int in runs:
		var start: int = Time.get_ticks_usec()
		body.call()
		@warning_ignore("return_value_discarded")
		samples.append((Time.get_ticks_usec() - start) / 1000.0)
	samples.sort()
	return samples[samples.size() >> 1]


static func report(label: String, ms: float, budget_ms: float = -1.0) -> void:
	var verdict: String = ""
	if budget_ms > 0.0:
		verdict = "  (budget %.1f ms: %s)" % [budget_ms, "OK" if ms <= budget_ms else "OVER"]
	print("%-58s %9.2f ms%s" % [label, ms, verdict])


static func noise_image(size: int, colors: int, density: float, seed_value: int) -> IndexedImage:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var image: IndexedImage = IndexedImage.new(&"bench", size, size)
	for i: int in image.pixels.size():
		image.pixels[i] = rng.randi_range(1, colors - 1) if rng.randf() < density else 0
	return image


## Sprite-like content: filled ellipses and rects in a few colors on a transparent background.
static func sprite_like_image(size: int, seed_value: int) -> IndexedImage:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var image: IndexedImage = IndexedImage.new(&"bench", size, size)
	var ctx: InkContext = InkContext.new(1, 0, PrismEnums.PaintButton.PRIMARY, PalettePresets.default_32())
	for i: int in 40:
		ctx.fg = rng.randi_range(1, 31)
		var painter: Painter = Painter.new(image, Brush.builtin(Brush.Shape.SQUARE, 1), ColorInk.new(), ctx, null)
		var rect: Rect2i = Rect2i(rng.randi_range(0, size - 8), rng.randi_range(0, size - 8), rng.randi_range(4, size >> 2), rng.randi_range(4, size >> 2))
		var points: Array[Vector2i] = RasterOps.ellipse_points(rect, true) if rng.randf() < 0.6 else RasterOps.rect_points(rect, true)
		var _changed: bool = painter.stamp_points(points)
	return image
