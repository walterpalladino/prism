extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func _doc(durations: Array[int]) -> PrismDocument:
	var fx: AppFixture = AppFixture.new(2, 2)
	for i: int in durations.size() - 1:
		fx.timeline.insert_frame(i + 1)
	for i: int in durations.size():
		fx.timeline.set_duration(Vector2i(i, i), durations[i])
	return fx.bus.document


func test_play_orders() -> void:
	assert_array(FrameSchedule.play_order(Vector2i(1, 3), PrismEnums.TagDirection.FORWARD)).is_equal(PackedInt32Array([1, 2, 3]))
	assert_array(FrameSchedule.play_order(Vector2i(1, 3), PrismEnums.TagDirection.REVERSE)).is_equal(PackedInt32Array([3, 2, 1]))
	assert_array(FrameSchedule.play_order(Vector2i(1, 4), PrismEnums.TagDirection.PING_PONG)).is_equal(PackedInt32Array([1, 2, 3, 4, 3, 2]))
	assert_array(FrameSchedule.play_order(Vector2i(2, 2), PrismEnums.TagDirection.PING_PONG)).is_equal(PackedInt32Array([2]))


func test_plain_schedule() -> void:
	var doc: PrismDocument = _doc([100, 250, 50])
	var order: PackedInt32Array = PackedInt32Array([0, 1, 2])
	assert_int(FrameSchedule.loop_ms(doc, order)).is_equal(400)
	assert_array(FrameSchedule.build(doc, order, false)).is_equal([Vector3i(0, 0, 100), Vector3i(1, 100, 250), Vector3i(2, 350, 50)])
	assert_int(FrameSchedule.frame_at(doc, order, 349)).is_equal(1)
	assert_int(FrameSchedule.frame_at(doc, order, 350)).is_equal(2)
	assert_int(FrameSchedule.build(doc, order, false, 2).size()).is_equal(2)


func test_baking_splits_frames_at_cycle_steps_over_the_common_loop() -> void:
	var doc: PrismDocument = _doc([100, 100])
	doc.cycles.append(CycleRange.new(16, 18, 5.0))
	var order: PackedInt32Array = PackedInt32Array([0, 1])
	var schedule: Array[Vector3i] = FrameSchedule.build(doc, order, true)
	# Animation loop 200 ms, cycle loop 3 / 5 Hz = 600 ms -> 600 ms total.
	var total: int = 0
	for entry: Vector3i in schedule:
		total += entry.z
	assert_int(total).is_equal(600)
	var starts: Array[int] = []
	for entry: Vector3i in schedule:
		starts.append(entry.y)
	assert_array(starts).is_equal([0, 100, 200, 300, 400, 500])
	assert_array([schedule[2].x, schedule[3].x]).is_equal([0, 1])
	assert_int(FrameSchedule.predicted_count(doc, order, true)).is_equal(6)
	assert_int(FrameSchedule.build(doc, order, true, 4).size()).is_equal(4)
	assert_int(FrameSchedule.build(doc, order, false).size()).is_equal(2)


func test_bake_with_cycle_steps_inside_frames() -> void:
	var doc: PrismDocument = _doc([300])
	doc.cycles.append(CycleRange.new(16, 17, 10.0))
	var schedule: Array[Vector3i] = FrameSchedule.build(doc, PackedInt32Array([0]), true)
	assert_int(schedule.size()).is_equal(6)
	assert_array([schedule[0].y, schedule[1].y, schedule[5].z]).is_equal([0, 100, 100])
