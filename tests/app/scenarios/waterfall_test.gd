## M5 exit: the C3 waterfall demo cycles at its stated rate (12 steps/s) — pixels never change.
extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func test_waterfall_cycles_at_the_stated_rate() -> void:
	var doc: PrismDocument = DemoDocuments.waterfall()
	assert_array(DocumentValidator.validate(doc)).is_empty()
	var bus: CommandBus = CommandBus.new(doc, History.new())
	var cycling: ColorCycling = ColorCycling.new(bus)
	var steps: Array[int] = [0]
	Signals.on(cycling.colors_changed, func(_c: PackedColorArray) -> void: steps[0] += 1)
	var pixels_before: PackedByteArray = doc.get_cel_image(0, 0).pixels.duplicate()
	var water_index: int = doc.get_cel_image(0, 0).get_index(30, 30)
	assert_bool(doc.cycles[0].contains(water_index)).is_true()
	cycling.request(&"tab", true)
	steps[0] = 0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	var clock: float = 0.0
	while clock < 10.0:
		var tick: float = (1000.0 / 60.0 + rng.randf_range(-3.0, 3.0)) / 1000.0
		clock += tick
		cycling.advance(tick)
	var expected_steps: int = floori(cycling.time_s * DemoDocuments.WATERFALL_RATE_HZ)
	assert_int(steps[0]).is_equal(expected_steps)
	assert_int(expected_steps).is_between(119, 121)
	var shown: PackedColorArray = cycling.current_colors()
	var offset: int = expected_steps % 6
	var source: int = DemoDocuments.WATERFALL_START + posmod(water_index - DemoDocuments.WATERFALL_START - offset, 6)
	assert_that(shown[water_index]).is_equal(doc.palette.get_color(source))
	assert_bool(doc.get_cel_image(0, 0).pixels == pixels_before).is_true()
