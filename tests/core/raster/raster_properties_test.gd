## Seeded property tests: random operations must preserve the GDD §6.3 invariants.
extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self

const SEEDS: int = 25
const OPS_PER_SEED: int = 40


func _random_point(rng: RandomNumberGenerator, size: int) -> Vector2i:
	return Vector2i(rng.randi_range(-4, size + 3), rng.randi_range(-4, size + 3))


func _apply_random_op(rng: RandomNumberGenerator, doc: PrismDocument, image: IndexedImage) -> void:
	var size: int = doc.width
	var value: int = rng.randi_range(0, doc.palette.size() - 1)
	var mode: PrismEnums.DrawMode = [PrismEnums.DrawMode.COLOR, PrismEnums.DrawMode.REPLACE, PrismEnums.DrawMode.SHADE][rng.randi_range(0, 2)]
	var button: PrismEnums.PaintButton = PrismEnums.PaintButton.PRIMARY if rng.randf() < 0.5 else PrismEnums.PaintButton.SECONDARY
	var ctx: InkContext = InkContext.new(value, rng.randi_range(0, doc.palette.size() - 1), button, doc.palette)
	var brush: Brush = Brush.builtin(Brush.Shape.ROUND if rng.randf() < 0.5 else Brush.Shape.SQUARE, rng.randi_range(1, 8))
	var painter: Painter = Painter.new(image, brush, Ink.for_mode(mode), ctx, doc.stencil)
	match rng.randi_range(0, 4):
		0:
			painter.stamp_points(RasterOps.line_points(_random_point(rng, size), _random_point(rng, size)))
		1:
			var rect: Rect2i = Rect2i(_random_point(rng, size), Vector2i(rng.randi_range(1, size), rng.randi_range(1, size)))
			painter.stamp_points(RasterOps.ellipse_points(rect, rng.randf() < 0.5))
		2:
			var rect: Rect2i = Rect2i(_random_point(rng, size), Vector2i(rng.randi_range(1, size), rng.randi_range(1, size)))
			painter.stamp_points(RasterOps.rect_points(rect, rng.randf() < 0.5))
		3:
			RasterOps.flood_fill(image, _random_point(rng, size), value, doc.stencil)
		4:
			RasterOps.replace_index(image, rng.randi_range(0, doc.palette.size() - 1), value, doc.stencil)


func test_random_ops_keep_invariants_and_never_touch_locked_pixels() -> void:
	for s: int in SEEDS:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 1000 + s
		var doc: PrismDocument = PrismDocument.create(rng.randi_range(4, 40), 0 + 1, PalettePresets.default_32())
		doc = PrismDocument.create(doc.width, doc.width)
		var image: IndexedImage = doc.get_cel_image(0, 0)
		for i: int in image.pixels.size():
			image.pixels[i] = rng.randi_range(0, 31)
		var locked: int = rng.randi_range(0, 31)
		doc.stencil.set_locked(locked, true)
		var locked_before: PackedInt32Array = _positions_of(image, locked)
		for op: int in OPS_PER_SEED:
			_apply_random_op(rng, doc, image)
		assert_array(DocumentValidator.validate(doc)).override_failure_message("seed %d" % s).is_empty()
		var locked_after: PackedInt32Array = _positions_of(image, locked)
		for position: int in locked_before:
			assert_bool(locked_after.has(position)).override_failure_message("seed %d: locked pixel %d overwritten" % [s, position]).is_true()


func test_flood_fill_dirty_rect_covers_all_changes() -> void:
	for s: int in SEEDS:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 2000 + s
		var image: IndexedImage = IndexedImage.new(&"f", 24, 24)
		for i: int in image.pixels.size():
			image.pixels[i] = 1 if rng.randf() < 0.35 else 0
		var before: PackedByteArray = image.pixels.duplicate()
		var dirty: Rect2i = RasterOps.flood_fill(image, Vector2i(rng.randi_range(0, 23), rng.randi_range(0, 23)), 2, null)
		for i: int in before.size():
			if before[i] != image.pixels[i]:
				var p: Vector2i = Vector2i(i % 24, (i - i % 24) / 24)
				assert_bool(dirty.has_point(p)).is_true()


func _positions_of(image: IndexedImage, value: int) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	for i: int in image.pixels.size():
		if image.pixels[i] == value:
			result.append(i)
	return result
