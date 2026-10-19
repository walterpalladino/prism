extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func test_add_update_delete_cycles_are_undoable() -> void:
	var fx: AppFixture = AppFixture.new()
	fx.state.set_fg(16)
	fx.state.set_bg(21)
	assert_str(fx.palette.add_cycle_between_fg_and_bg()).is_empty()
	var cycles: Array[CycleRange] = fx.bus.document.cycles
	assert_int(cycles.size()).is_equal(1)
	assert_float(cycles[0].rate_hz).is_equal(PaletteActions.DEFAULT_CYCLE_RATE_HZ)
	assert_str(fx.palette.add_cycle(20, 24, 4.0, 1)).contains("overlap")
	assert_str(fx.palette.add_cycle(30, 40, 4.0, 1)).contains("invalid range")
	assert_str(fx.palette.update_cycle(0, 21, 16, 12.0, -1, false)).is_empty()
	var edited: CycleRange = fx.bus.document.cycles[0]
	assert_array([edited.start_index, edited.end_index, edited.step, edited.active]).is_equal([16, 21, -1, false])
	assert_str(fx.palette.update_cycle(5, 0, 1, 1.0, 1, true)).is_not_empty()
	fx.palette.delete_cycle(0)
	fx.palette.delete_cycle(0)
	assert_bool(fx.bus.document.cycles.is_empty()).is_true()
	assert_str(fx.bus.history.undo_label()).is_equal("Delete Cycle")
	fx.bus.undo()
	assert_float(fx.bus.document.cycles[0].rate_hz).is_equal(12.0)
	fx.bus.undo()
	assert_float(fx.bus.document.cycles[0].rate_hz).is_equal(PaletteActions.DEFAULT_CYCLE_RATE_HZ)


func test_max_four_cycles() -> void:
	var fx: AppFixture = AppFixture.new()
	for i: int in 4:
		assert_str(fx.palette.add_cycle(i * 3, i * 3 + 1, 1.0, 1)).is_empty()
	assert_str(fx.palette.add_cycle(20, 22, 1.0, 1)).contains("too many")


func test_set_cycles_command() -> void:
	var doc: PrismDocument = PrismDocument.create(2, 2)
	var after: Array[CycleRange] = [CycleRange.new(1, 3, 2.0)]
	var command: SetCyclesCommand = SetCyclesCommand.new(doc.cycles, after, "Cycles")
	after[0].rate_hz = 99.0
	command.apply(doc)
	assert_float(doc.cycles[0].rate_hz).is_equal(2.0)
	command.revert(doc)
	assert_bool(doc.cycles.is_empty()).is_true()
	assert_bool(command.changes_palette()).is_true()
	assert_str(command.get_label()).is_equal("Cycles")
	assert_int(command.get_byte_size()).is_greater(0)


func test_clock_runs_only_while_requested() -> void:
	var fx: AppFixture = AppFixture.new()
	fx.palette.add_cycle(16, 21, 10.0, 1)
	var emitted: Array[PackedColorArray] = []
	var running: Array[bool] = []
	Signals.on(fx.cycling.colors_changed, func(c: PackedColorArray) -> void: emitted.append(c))
	Signals.on(fx.cycling.running_changed, func(r: bool) -> void: running.append(r))
	fx.cycling.advance(1.0)
	assert_int(emitted.size()).is_equal(0)
	fx.cycling.request(&"tab", true)
	fx.cycling.request(&"playback", true)
	assert_array(running).is_equal([true])
	emitted.clear()
	fx.cycling.advance(0.05)
	assert_int(emitted.size()).is_equal(0)
	fx.cycling.advance(0.06)
	assert_int(emitted.size()).is_equal(1)
	assert_that(emitted[0][17]).is_equal(fx.bus.document.palette.get_color(16))
	fx.cycling.request(&"tab", false)
	assert_bool(fx.cycling.is_running()).is_true()
	fx.cycling.toggle(&"playback")
	assert_array(running).is_equal([true, false])
	assert_that(emitted[emitted.size() - 1]).is_equal(fx.bus.document.palette.colors)


func test_palette_edits_while_cycling_show_up_immediately() -> void:
	var fx: AppFixture = AppFixture.new()
	fx.palette.add_cycle(16, 21, 10.0, 1)
	fx.cycling.request(&"tab", true)
	fx.cycling.advance(0.1)
	var latest: Array[PackedColorArray] = []
	Signals.on(fx.cycling.colors_changed, func(c: PackedColorArray) -> void: latest.append(c))
	fx.palette.set_color(16, Color.RED)
	assert_that(latest[latest.size() - 1][17]).is_equal(Color.RED)
	assert_that(fx.cycling.current_colors()[17]).is_equal(Color.RED)


func test_new_document_stops_cycling() -> void:
	var fx: AppFixture = AppFixture.new()
	fx.cycling.request(&"tab", true)
	fx.cycling.advance(0.5)
	fx.bus.replace_document(PrismDocument.create(4, 4))
	assert_bool(fx.cycling.is_running()).is_false()
	assert_float(fx.cycling.time_s).is_equal(0.0)
