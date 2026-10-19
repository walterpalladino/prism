extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func _fx(frames: int) -> AppFixture:
	var fx: AppFixture = AppFixture.new(4, 4)
	for i: int in frames - 1:
		fx.timeline.insert_frame(i + 1)
	return fx


func test_off_by_default_and_clamped() -> void:
	var fx: AppFixture = _fx(8)
	assert_array(fx.state.onion_frames()).is_empty()
	fx.state.set_onion(true, 9, -2, false)
	assert_int(fx.state.onion_past).is_equal(EditorState.ONION_MAX)
	assert_int(fx.state.onion_future).is_equal(0)


func test_past_and_future_frames_with_distances() -> void:
	var fx: AppFixture = _fx(8)
	fx.state.set_frame(4)
	fx.state.set_onion(true, 3, 2, false)
	assert_array(fx.state.onion_frames()).is_equal([Vector2i(1, -3), Vector2i(2, -2), Vector2i(3, -1), Vector2i(5, 1), Vector2i(6, 2)])
	fx.state.set_frame(0)
	assert_array(fx.state.onion_frames()).is_equal([Vector2i(1, 1), Vector2i(2, 2)])


func test_tag_bounded_mode() -> void:
	var fx: AppFixture = _fx(8)
	fx.timeline.add_tag(Vector2i(3, 5), "walk")
	fx.state.set_frame(4)
	fx.state.set_onion(true, 3, 3, true)
	assert_array(fx.state.onion_frames()).is_equal([Vector2i(3, -1), Vector2i(5, 1)])
	fx.state.set_frame(1)
	assert_int(fx.state.onion_frames().size()).is_equal(4)
