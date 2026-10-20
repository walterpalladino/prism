extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func _fx() -> AppFixture:
	return AppFixture.new(4, 2)


func test_preview_then_commit_is_one_undo_step() -> void:
	var fx: AppFixture = _fx()
	var original: Color = fx.bus.document.palette.get_color(5)
	fx.palette.preview_color(5, Color.RED)
	fx.palette.preview_color(5, Color.GREEN)
	assert_that(fx.bus.document.palette.get_color(5)).is_equal(Color.GREEN)
	assert_bool(fx.palette.has_pending_edit()).is_true()
	assert_bool(fx.bus.history.can_undo()).is_false()
	fx.palette.commit_color()
	assert_bool(fx.palette.has_pending_edit()).is_false()
	assert_int(fx.bus.history.undo_count()).is_equal(1)
	fx.bus.undo()
	assert_that(fx.bus.document.palette.get_color(5)).is_equal(original)


func test_previewing_another_index_commits_the_first() -> void:
	var fx: AppFixture = _fx()
	fx.palette.preview_color(5, Color.RED)
	fx.palette.preview_color(6, Color.BLUE)
	assert_int(fx.bus.history.undo_count()).is_equal(1)
	fx.palette.commit_color()
	assert_int(fx.bus.history.undo_count()).is_equal(2)


func test_preview_back_to_original_records_nothing() -> void:
	var fx: AppFixture = _fx()
	var original: Color = fx.bus.document.palette.get_color(5)
	fx.palette.preview_color(5, Color.RED)
	fx.palette.preview_color(5, original)
	fx.palette.commit_color()
	assert_bool(fx.bus.history.can_undo()).is_false()


func test_set_color() -> void:
	var fx: AppFixture = _fx()
	fx.palette.set_color(3, Color.RED)
	fx.palette.set_color(3, Color.RED)
	assert_int(fx.bus.history.undo_count()).is_equal(1)
	assert_that(fx.palette.palette().get_color(3)).is_equal(Color.RED)


func test_reorder_with_remap_moves_fg_and_bg() -> void:
	var fx: AppFixture = _fx()
	fx.state.set_fg(2)
	fx.state.set_bg(4)
	fx.image().set_index(0, 0, 2)
	fx.palette.reorder(2, 5, true)
	assert_int(fx.state.fg).is_equal(5)
	assert_int(fx.state.bg).is_equal(3)
	assert_int(fx.image().get_index(0, 0)).is_equal(5)
	fx.palette.reorder(1, 1, true)
	fx.palette.reorder(1, 99, true)
	assert_int(fx.bus.history.undo_count()).is_equal(1)


func test_reorder_without_remap_keeps_fg() -> void:
	var fx: AppFixture = _fx()
	fx.state.set_fg(2)
	fx.palette.reorder(2, 5, false)
	assert_int(fx.state.fg).is_equal(2)


func test_load_palette_pads_when_pixels_use_more_entries() -> void:
	var fx: AppFixture = _fx()
	fx.image().set_index(1, 1, 20)
	assert_int(fx.palette.highest_used_index()).is_equal(20)
	var old_20: Color = fx.palette.palette().get_color(20)
	var padded: int = fx.palette.load_palette(PalettePresets.ega_16())
	assert_int(padded).is_equal(5)
	assert_int(fx.palette.palette().size()).is_equal(21)
	assert_that(fx.palette.palette().get_color(20)).is_equal(old_20)
	assert_that(fx.palette.palette().get_color(15)).is_equal(Color.WHITE)
	fx.bus.undo()
	assert_int(fx.palette.palette().size()).is_equal(32)


func test_load_palette_clamps_fg_bg() -> void:
	var fx: AppFixture = _fx()
	fx.state.set_fg(30)
	assert_int(fx.palette.load_palette(PalettePresets.ega_16())).is_equal(0)
	assert_int(fx.state.fg).is_equal(15)


func test_ramps() -> void:
	var fx: AppFixture = _fx()
	fx.palette.load_palette(PalettePresets.ega_16())
	fx.state.set_fg(9)
	fx.state.set_bg(4)
	assert_bool(fx.palette.add_ramp_between_fg_and_bg()).is_true()
	assert_that(fx.palette.palette().find_ramp(6)).is_equal(Vector2i(4, 9))
	assert_bool(fx.palette.add_ramp(8, 12)).is_false()
	assert_bool(fx.palette.remove_ramp_at(5)).is_true()
	assert_bool(fx.palette.remove_ramp_at(5)).is_false()
	assert_str(fx.bus.history.undo_label()).is_equal("Remove Ramp")
	fx.bus.undo()
	assert_that(fx.palette.palette().find_ramp(6)).is_equal(Vector2i(4, 9))


func test_stencil_actions_are_undoable() -> void:
	var fx: AppFixture = _fx()
	fx.palette.toggle_lock(3)
	assert_bool(fx.bus.document.stencil.is_locked(3)).is_true()
	fx.state.set_fg(7)
	fx.palette.lock_all_except_fg()
	assert_int(fx.bus.document.stencil.locked_indices().size()).is_equal(255)
	fx.palette.invert_stencil()
	assert_that(fx.bus.document.stencil.locked_indices()).is_equal(PackedInt32Array([7]))
	fx.palette.clear_stencil()
	fx.palette.clear_stencil()
	assert_bool(fx.bus.document.stencil.has_any()).is_false()
	assert_int(fx.bus.history.undo_count()).is_equal(4)
	fx.bus.undo()
	assert_bool(fx.bus.document.stencil.is_locked(7)).is_true()


func test_cancel_preview_restores_and_records_nothing() -> void:
	var fx: AppFixture = _fx()
	var original: Color = fx.bus.document.palette.get_color(5)
	var changes: Array[int] = [0]
	Signals.on(fx.bus.palette_changed, func() -> void: changes[0] += 1)
	fx.palette.preview_color(5, Color.RED)
	fx.palette.cancel_preview()
	fx.palette.cancel_preview()
	assert_that(fx.bus.document.palette.get_color(5)).is_equal(original)
	assert_bool(fx.palette.has_pending_edit()).is_false()
	assert_bool(fx.bus.history.can_undo()).is_false()
	assert_int(changes[0]).is_equal(2)


func test_add_color_after_fg_copies_fg_and_selects_it() -> void:
	var fx: AppFixture = _fx()
	fx.state.set_fg(4)
	fx.state.set_bg(9)
	fx.image().set_index(0, 0, 9)
	assert_str(fx.palette.add_color_after_fg()).is_empty()
	assert_int(fx.palette.palette().size()).is_equal(33)
	assert_int(fx.state.fg).is_equal(5)
	assert_that(fx.palette.palette().get_color(5)).is_equal(fx.palette.palette().get_color(4))
	assert_int(fx.state.bg).is_equal(10)
	assert_int(fx.image().get_index(0, 0)).is_equal(10)
	assert_str(fx.bus.history.undo_label()).is_equal("Add Color 5")
	fx.bus.undo()
	assert_int(fx.palette.palette().size()).is_equal(32)
	assert_int(fx.image().get_index(0, 0)).is_equal(9)


func test_insert_color_limits() -> void:
	var fx: AppFixture = _fx()
	assert_str(fx.palette.insert_color(-1, Color.RED)).is_not_empty()
	assert_str(fx.palette.insert_color(33, Color.RED)).is_not_empty()
	fx.palette.load_palette(PalettePresets.blank(Palette.MAX_COLORS))
	fx.state.set_fg(255)
	assert_str(fx.palette.add_color_after_fg()).contains("full")
	assert_int(fx.palette.palette().size()).is_equal(Palette.MAX_COLORS)


func test_remove_unused_color() -> void:
	var fx: AppFixture = _fx()
	fx.state.set_fg(5)
	fx.state.set_bg(7)
	assert_int(fx.palette.usage_count(5)).is_equal(0)
	assert_str(fx.palette.remove_color(5)).is_empty()
	assert_int(fx.palette.palette().size()).is_equal(31)
	assert_int(fx.state.fg).is_equal(5)
	assert_int(fx.state.bg).is_equal(6)


func test_remove_used_color_needs_a_target() -> void:
	var fx: AppFixture = _fx()
	var image: IndexedImage = fx.image()
	image.set_index(0, 0, 5)
	image.set_index(1, 0, 5)
	image.set_index(2, 0, 9)
	var color_9: Color = fx.palette.palette().get_color(9)
	fx.state.set_fg(5)
	assert_int(fx.palette.usage_count(5)).is_equal(2)
	assert_str(fx.palette.remove_color(5)).contains("2 pixels")
	assert_str(fx.palette.remove_color(5, 5)).is_not_empty()
	assert_int(fx.palette.palette().size()).is_equal(32)
	assert_str(fx.palette.remove_color(5, 9)).is_empty()
	assert_int(image.get_index(0, 0)).is_equal(8)
	assert_int(image.get_index(2, 0)).is_equal(8)
	assert_that(fx.palette.palette().get_color(8)).is_equal(color_9)
	assert_int(fx.state.fg).is_equal(8)
	fx.bus.undo()
	assert_int(image.get_index(0, 0)).is_equal(5)
	assert_int(image.get_index(2, 0)).is_equal(9)


func test_removal_blockers() -> void:
	var fx: AppFixture = _fx()
	assert_str(fx.palette.removal_blocker(0)).contains("transparent")
	assert_str(fx.palette.removal_blocker(40)).is_not_empty()
	assert_str(fx.palette.removal_blocker(3)).is_empty()
	assert_str(fx.palette.remove_color(0)).contains("transparent")
	fx.palette.load_palette(PalettePresets.blank(1))
	assert_str(fx.palette.removal_blocker(0)).contains("at least one")


func test_undo_of_add_keeps_fg_inside_the_palette() -> void:
	var fx: AppFixture = _fx()
	fx.state.set_fg(31)
	fx.palette.add_color_after_fg()
	assert_int(fx.state.fg).is_equal(32)
	fx.bus.undo()
	fx.state.clamp_to_document()
	assert_int(fx.state.fg).is_equal(31)


func test_load_palette_pads_to_cover_color_cycles() -> void:
	var fx: AppFixture = _fx()
	assert_str(fx.palette.add_cycle(20, 24, 4.0, 1)).is_empty()
	assert_int(fx.palette.load_palette(PalettePresets.blank(4))).is_equal(21)
	assert_array(DocumentValidator.validate(fx.bus.document)).is_empty()
