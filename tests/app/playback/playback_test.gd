extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func _fx(frames: int, durations: Array[int] = []) -> AppFixture:
	var fx: AppFixture = AppFixture.new(2, 2)
	for i: int in frames - 1:
		fx.timeline.insert_frame(i + 1)
	for i: int in durations.size():
		fx.timeline.set_duration(Vector2i(i, i), durations[i])
	fx.state.set_frame(0)
	return fx


func _sequence(fx: AppFixture, steps: int) -> Array[int]:
	var seen: Array[int] = [fx.playback.frame]
	for i: int in steps:
		fx.playback.advance(fx.bus.document.frames[fx.playback.frame].duration_ms)
		seen.append(fx.playback.frame)
	return seen


func test_forward_loops_whole_timeline_without_tags() -> void:
	var fx: AppFixture = _fx(3)
	fx.playback.play_from(0)
	assert_bool(fx.playback.playing).is_true()
	assert_array(_sequence(fx, 6)).is_equal([0, 1, 2, 0, 1, 2, 0])


func test_reverse_and_ping_pong_tags() -> void:
	var fx: AppFixture = _fx(6)
	fx.timeline.add_tag(Vector2i(1, 3), "back")
	fx.timeline.update_tag(0, "back", Vector2i(1, 3), PrismEnums.TagDirection.REVERSE, Color.RED)
	fx.playback.play_from(2)
	assert_array(_sequence(fx, 5)).is_equal([2, 1, 3, 2, 1, 3])
	fx.timeline.add_tag(Vector2i(4, 5), "pp")
	fx.timeline.add_tag(Vector2i(0, 0), "single")
	fx.timeline.update_tag(1, "pp", Vector2i(3, 5), PrismEnums.TagDirection.PING_PONG, Color.RED)
	fx.timeline.update_tag(1, "pp", Vector2i(4, 5), PrismEnums.TagDirection.PING_PONG, Color.RED)
	fx.timeline.update_tag(0, "back", Vector2i(1, 2), PrismEnums.TagDirection.REVERSE, Color.RED)
	fx.timeline.update_tag(1, "pp", Vector2i(3, 5), PrismEnums.TagDirection.PING_PONG, Color.RED)
	fx.playback.play_from(3)
	assert_array(_sequence(fx, 6)).is_equal([3, 4, 5, 4, 3, 4, 5])
	fx.playback.play_from(0)
	assert_array(_sequence(fx, 2)).is_equal([0, 0, 0])


func test_start_outside_range_and_reverse_start() -> void:
	var fx: AppFixture = _fx(4)
	fx.playback.play(Vector2i(1, 2), PrismEnums.TagDirection.REVERSE, 0)
	assert_int(fx.playback.frame).is_equal(2)
	fx.playback.play(Vector2i(1, 2), PrismEnums.TagDirection.FORWARD, 3)
	assert_int(fx.playback.frame).is_equal(1)


func test_partial_ticks_and_multi_frame_jumps() -> void:
	var fx: AppFixture = _fx(3, [100, 50, 50])
	fx.playback.play_from(0)
	fx.playback.advance(60.0)
	assert_int(fx.playback.frame).is_equal(0)
	fx.playback.advance(60.0)
	assert_int(fx.playback.frame).is_equal(1)
	assert_float(fx.playback.elapsed_in_frame()).is_equal_approx(20.0, 0.001)
	fx.playback.advance(130.0)
	assert_int(fx.playback.frame).is_equal(0)
	assert_float(fx.playback.elapsed_in_frame()).is_equal_approx(50.0, 0.001)


func test_signals_stop_and_toggle() -> void:
	var fx: AppFixture = _fx(2)
	var frames: Array[int] = []
	var states: Array[bool] = []
	Signals.on(fx.playback.frame_changed, func(i: int) -> void: frames.append(i))
	Signals.on(fx.playback.playing_changed, func(p: bool) -> void: states.append(p))
	fx.playback.toggle(0)
	fx.playback.advance(100.0)
	fx.playback.toggle(0)
	fx.playback.advance(500.0)
	fx.playback.stop()
	assert_array(frames).is_equal([1])
	assert_array(states).is_equal([true, false])
	assert_int(fx.playback.frame).is_equal(1)


func test_scope_for() -> void:
	var fx: AppFixture = _fx(5)
	var whole: Array = Playback.scope_for(fx.bus.document, 2)
	assert_that(whole[0]).is_equal(Vector2i(0, 4))
	fx.timeline.add_tag(Vector2i(1, 3), "t")
	var tagged: Array = Playback.scope_for(fx.bus.document, 2)
	assert_that(tagged[0]).is_equal(Vector2i(1, 3))
	assert_int(tagged[1]).is_equal(PrismEnums.TagDirection.FORWARD)
