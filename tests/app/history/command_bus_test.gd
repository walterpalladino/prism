extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self

var _image_events: Array[Rect2i] = []
var _document_events: int = 0
var _history_events: int = 0


func _bus() -> CommandBus:
	_image_events.clear()
	_document_events = 0
	_history_events = 0
	var bus: CommandBus = CommandBus.new(PrismDocument.create(4, 4), History.new())
	bus.image_changed.connect(func(_id: StringName, dirty: Rect2i) -> void: _image_events.append(dirty))
	bus.document_changed.connect(func(_dirty: Rect2i) -> void: _document_events += 1)
	bus.history_changed.connect(func() -> void: _history_events += 1)
	return bus


func _patch(bus: CommandBus) -> PixelPatch:
	var image: IndexedImage = bus.document.get_cel_image(0, 0)
	return PixelPatch.new(image.id, Rect2i(1, 1, 1, 1), PackedByteArray([0]), PackedByteArray([3]))


func test_execute_applies_records_and_notifies() -> void:
	var bus: CommandBus = _bus()
	bus.execute(_patch(bus))
	assert_int(bus.document.get_cel_image(0, 0).get_index(1, 1)).is_equal(3)
	assert_int(bus.history.undo_count()).is_equal(1)
	assert_array(_image_events).is_equal([Rect2i(1, 1, 1, 1)])
	assert_int(_document_events).is_equal(1)
	assert_int(_history_events).is_equal(1)


func test_record_does_not_reapply() -> void:
	var bus: CommandBus = _bus()
	bus.record(_patch(bus))
	assert_int(bus.document.get_cel_image(0, 0).get_index(1, 1)).is_equal(0)
	assert_int(bus.history.undo_count()).is_equal(1)


func test_undo_redo_notify() -> void:
	var bus: CommandBus = _bus()
	bus.execute(_patch(bus))
	assert_bool(bus.undo()).is_true()
	assert_int(bus.document.get_cel_image(0, 0).get_index(1, 1)).is_equal(0)
	assert_bool(bus.undo()).is_false()
	assert_bool(bus.redo()).is_true()
	assert_bool(bus.redo()).is_false()
	assert_int(_image_events.size()).is_equal(3)


func test_live_notifications_and_replace() -> void:
	var bus: CommandBus = _bus()
	var replaced: Array[bool] = [false]
	bus.document_replaced.connect(func() -> void: replaced[0] = true)
	bus.notify_image_changed(&"I3", Rect2i(0, 0, 2, 2))
	bus.notify_document_changed()
	assert_int(_image_events.size()).is_equal(1)
	assert_int(_document_events).is_equal(1)
	bus.execute(_patch(bus))
	bus.replace_document(PrismDocument.create(2, 2))
	assert_bool(replaced[0]).is_true()
	assert_int(bus.document.width).is_equal(2)
	assert_bool(bus.history.can_undo()).is_false()


func test_random_commands_revert_all_restores_original() -> void:
	for s: int in 20:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 500 + s
		var fx: AppFixture = AppFixture.new(12, 12)
		var original: PackedByteArray = fx.image().pixels.duplicate()
		var tool_ids: Array[StringName] = [&"pencil", &"eraser", &"line", &"rect", &"ellipse", &"fill", &"move"]
		for i: int in 30:
			fx.state.fg = rng.randi_range(0, 31)
			fx.state.filled_shapes = rng.randf() < 0.5
			fx.state.set_builtin_brush(Brush.Shape.ROUND, rng.randi_range(1, 4))
			fx.state.set_draw_mode(PrismEnums.DrawMode.COLOR if rng.randf() < 0.5 else PrismEnums.DrawMode.SHADE)
			var points: Array[Vector2i] = []
			for p: int in rng.randi_range(1, 5):
				points.append(Vector2i(rng.randi_range(-2, 13), rng.randi_range(-2, 13)))
			fx.stroke(tool_ids[rng.randi_range(0, tool_ids.size() - 1)], points)
		var after_all: PackedByteArray = fx.image().pixels.duplicate()
		var after_offset: Vector2i = fx.state.current_cel().offset
		while fx.bus.undo():
			pass
		assert_bool(fx.image().pixels == original).override_failure_message("seed %d: undo-all mismatch" % s).is_true()
		assert_that(fx.state.current_cel().offset).is_equal(Vector2i.ZERO)
		while fx.bus.redo():
			pass
		assert_bool(fx.image().pixels == after_all).override_failure_message("seed %d: redo-all mismatch" % s).is_true()
		assert_that(fx.state.current_cel().offset).is_equal(after_offset)
