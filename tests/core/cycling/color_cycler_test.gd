extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func _colors(count: int) -> PackedColorArray:
	var colors: PackedColorArray = PackedColorArray()
	for i: int in count:
		colors.append(Color8(i, 0, 0))
	return colors


func _reds(colors: PackedColorArray) -> PackedInt32Array:
	var reds: PackedInt32Array = PackedInt32Array()
	for c: Color in colors:
		reds.append(c.r8)
	return reds


func test_offset_steps_with_time_and_wraps() -> void:
	var cycle: CycleRange = CycleRange.new(2, 5, 10.0)
	assert_int(ColorCycler.offset_at(cycle, 0.0)).is_equal(0)
	assert_int(ColorCycler.offset_at(cycle, 0.099)).is_equal(0)
	assert_int(ColorCycler.offset_at(cycle, 0.1)).is_equal(1)
	assert_int(ColorCycler.offset_at(cycle, 0.35)).is_equal(3)
	assert_int(ColorCycler.offset_at(cycle, 0.4)).is_equal(0)
	cycle.step = -1
	assert_int(ColorCycler.offset_at(cycle, 0.1)).is_equal(3)
	cycle.active = false
	assert_int(ColorCycler.offset_at(cycle, 0.1)).is_equal(0)


func test_forward_moves_colors_up_and_reverse_down() -> void:
	var cycles: Array[CycleRange] = [CycleRange.new(1, 4, 1.0)]
	assert_array(_reds(ColorCycler.cycled_colors(_colors(6), cycles, 1.0))).is_equal([0, 4, 1, 2, 3, 5])
	cycles[0].step = -1
	assert_array(_reds(ColorCycler.cycled_colors(_colors(6), cycles, 1.0))).is_equal([0, 2, 3, 4, 1, 5])


func test_several_cycles_and_source_untouched() -> void:
	var colors: PackedColorArray = _colors(8)
	var cycles: Array[CycleRange] = [CycleRange.new(0, 1, 2.0), CycleRange.new(4, 6, 1.0)]
	var result: PackedColorArray = ColorCycler.cycled_colors(colors, cycles, 1.0)
	assert_array(_reds(result)).is_equal([0, 1, 2, 3, 6, 4, 5, 7])
	assert_array(_reds(colors)).is_equal([0, 1, 2, 3, 4, 5, 6, 7])
	assert_array(ColorCycler.offsets_at(cycles, 1.0)).is_equal(PackedInt32Array([0, 1]))


func test_cycle_past_palette_end_is_ignored() -> void:
	var cycles: Array[CycleRange] = [CycleRange.new(2, 9, 1.0)]
	assert_array(_reds(ColorCycler.cycled_colors(_colors(4), cycles, 1.0))).is_equal([0, 1, 2, 3])


func test_loop_seconds_is_lcm_of_periods() -> void:
	var cycles: Array[CycleRange] = [CycleRange.new(0, 5, 12.0), CycleRange.new(8, 11, 8.0)]
	assert_float(ColorCycler.loop_seconds(cycles)).is_equal_approx(0.5, 0.001)
	cycles.append(CycleRange.new(14, 16, 1.0))
	assert_float(ColorCycler.loop_seconds(cycles)).is_equal_approx(3.0, 0.001)
	var empty: Array[CycleRange] = []
	assert_float(ColorCycler.loop_seconds(empty)).is_equal(0.0)


func test_cycle_range_helpers() -> void:
	var cycle: CycleRange = CycleRange.new(3, 6, 5.0, -1)
	cycle.active = false
	var copy: CycleRange = cycle.duplicate_cycle()
	assert_bool(copy.active).is_false()
	assert_int(copy.step).is_equal(-1)
	assert_bool(copy.contains(6)).is_true()
	assert_bool(copy.contains(7)).is_false()
