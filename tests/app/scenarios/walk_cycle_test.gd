## M4 exit: an 8-frame, 3-layer walk cycle with two tags plays each tag at the correct
## per-frame durations, with at most ±2 ms drift over 10 s (GDD §10 M4).
extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self

const DURATIONS: Array[int] = [100, 100, 250, 100, 120, 80, 80, 160]
const TICK_MS: float = 1000.0 / 60.0
const MAX_DRIFT_MS: float = 2.0


func _build() -> AppFixture:
	var fx: AppFixture = AppFixture.new(32, 32)
	fx.timeline.rename_layer(0, "Body")
	fx.timeline.add_layer()
	fx.timeline.rename_layer(1, "Legs")
	fx.timeline.add_layer()
	fx.timeline.rename_layer(2, "Outline")
	for i: int in 7:
		fx.timeline.duplicate_frame(i, false)
	for i: int in DURATIONS.size():
		fx.timeline.set_duration(Vector2i(i, i), DURATIONS[i])
		fx.state.set_frame(i)
		for layer: int in 3:
			fx.state.set_layer(layer)
			fx.state.set_fg(1 + layer)
			fx.click(&"pencil", Vector2i(4 + i * 3, 8 + layer * 6))
	fx.timeline.add_tag(Vector2i(0, 3), "walk")
	fx.timeline.add_tag(Vector2i(4, 7), "idle")
	fx.timeline.update_tag(1, "idle", Vector2i(4, 7), PrismEnums.TagDirection.PING_PONG, Color.ORANGE)
	return fx


## Plays for 10 s with 60 fps ticks (with jitter) and compares every frame change against the
## ideal schedule computed from the durations.
func _check_tag(fx: AppFixture, start_frame: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	fx.playback.play_from(start_frame)
	var scope: Array = Playback.scope_for(fx.bus.document, start_frame)
	var play_range: Vector2i = scope[0]
	var ideal: Playback = Playback.new(fx.bus)
	var clock: float = 0.0
	var ideal_change_at: float = DURATIONS[fx.playback.frame]
	var expected_frame: int = fx.playback.frame
	var direction: PrismEnums.TagDirection = scope[1]
	ideal.play(play_range, direction, start_frame)
	var changes: int = 0
	while clock < 10000.0:
		var tick: float = TICK_MS + rng.randf_range(-4.0, 4.0)
		clock += tick
		var before: int = fx.playback.frame
		fx.playback.advance(tick)
		while clock >= ideal_change_at:
			expected_frame = ideal.next_frame(expected_frame)
			ideal_change_at += DURATIONS[expected_frame]
			changes += 1
		assert_int(fx.playback.frame).override_failure_message("t=%.1f" % clock).is_equal(expected_frame)
		if fx.playback.frame != before:
			assert_int(fx.playback.frame).is_between(play_range.x, play_range.y)
	# Position inside the current frame must match the ideal schedule.
	var ideal_elapsed: float = clock - (ideal_change_at - DURATIONS[expected_frame])
	assert_float(absf(fx.playback.elapsed_in_frame() - ideal_elapsed)).is_less_equal(MAX_DRIFT_MS)
	assert_int(changes).is_greater(40)
	fx.playback.stop()


func test_walk_cycle_document() -> void:
	var fx: AppFixture = _build()
	var doc: PrismDocument = fx.bus.document
	assert_int(doc.frames.size()).is_equal(8)
	assert_int(doc.layers.size()).is_equal(3)
	assert_int(doc.tags.size()).is_equal(2)
	assert_array(DocumentValidator.validate(doc)).is_empty()
	for i: int in 8:
		assert_int(doc.get_cel_image(2, i).get_index(4 + i * 3, 20)).is_equal(3)


func test_walk_tag_plays_on_schedule() -> void:
	_check_tag(_build(), 1)


func test_idle_ping_pong_tag_plays_on_schedule() -> void:
	_check_tag(_build(), 5)
