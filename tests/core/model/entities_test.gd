## Layer, Frame, Cel, Tag, CycleRange.
extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func test_layer_defaults_and_duplicate() -> void:
	var layer: Layer = Layer.new(&"L1", "Outline")
	assert_bool(layer.visible).is_true()
	assert_bool(layer.locked).is_false()
	assert_int(layer.opacity).is_equal(255)
	layer.opacity = 128
	layer.locked = true
	var copy: Layer = layer.duplicate_layer(&"L2")
	assert_str(String(copy.id)).is_equal("L2")
	assert_str(copy.layer_name).is_equal("Outline")
	assert_int(copy.opacity).is_equal(128)
	assert_bool(copy.locked).is_true()


func test_frame_default_duration() -> void:
	assert_int(Frame.new(&"F1").duration_ms).is_equal(Frame.DEFAULT_DURATION_MS)
	assert_int(Frame.new(&"F1", 250).duration_ms).is_equal(250)


func test_cel_fields() -> void:
	var cel: Cel = Cel.new(&"L1", &"F1", &"I1", Vector2i(2, 3))
	assert_str(String(cel.image_id)).is_equal("I1")
	assert_that(cel.offset).is_equal(Vector2i(2, 3))


func test_tag_frame_count() -> void:
	var tag: Tag = Tag.new("idle", 2, 5, PrismEnums.TagDirection.PING_PONG)
	assert_int(tag.frame_count()).is_equal(4)
	assert_int(tag.direction).is_equal(PrismEnums.TagDirection.PING_PONG)


func test_cycle_range_length_and_overlap() -> void:
	var a: CycleRange = CycleRange.new(16, 21, 12.0)
	var b: CycleRange = CycleRange.new(21, 24, 8.0)
	var c: CycleRange = CycleRange.new(22, 24, 8.0, -1)
	assert_int(a.length()).is_equal(6)
	assert_bool(a.overlaps(b)).is_true()
	assert_bool(a.overlaps(c)).is_false()
	assert_int(c.step).is_equal(-1)
