extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


## EGA 16, one 6×1 cel [0, 1, 2, 3, 4, 5], ramp 2–5, cycle 8–11, stencil on 3 and 9.
func _doc() -> PrismDocument:
	var doc: PrismDocument = PrismDocument.create(6, 1, PalettePresets.ega_16())
	doc.get_cel_image(0, 0).pixels = PackedByteArray([0, 1, 2, 3, 4, 5])
	doc.palette.add_ramp(2, 5)
	doc.cycles.append(CycleRange.new(8, 11, 4.0))
	doc.stencil.set_locked(3, true)
	doc.stencil.set_locked(9, true)
	return doc


func _colors_of(doc: PrismDocument) -> PackedColorArray:
	var result: PackedColorArray = PackedColorArray()
	for v: int in doc.get_cel_image(0, 0).pixels:
		result.append(doc.palette.get_color(v))
	return result


func test_shift_table() -> void:
	var up: PackedByteArray = PaletteResizeCommand.shift_table(3, 1)
	assert_that(up.slice(0, 6)).is_equal(PackedByteArray([0, 1, 2, 4, 5, 6]))
	assert_int(up[255]).is_equal(255)
	var down: PackedByteArray = PaletteResizeCommand.shift_table(3, -1)
	assert_that(down.slice(0, 6)).is_equal(PackedByteArray([0, 1, 2, 3, 3, 4]))


func test_shift_span() -> void:
	var span: Vector2i = Vector2i(2, 5)
	assert_that(PaletteResizeCommand.shift_span(span, 2, 1)).is_equal(Vector2i(3, 6))
	assert_that(PaletteResizeCommand.shift_span(span, 4, 1)).is_equal(Vector2i(2, 6))
	assert_that(PaletteResizeCommand.shift_span(span, 6, 1)).is_equal(span)
	assert_that(PaletteResizeCommand.shift_span(span, 1, -1)).is_equal(Vector2i(1, 4))
	assert_that(PaletteResizeCommand.shift_span(span, 5, -1)).is_equal(Vector2i(2, 4))
	assert_that(PaletteResizeCommand.shift_span(span, 6, -1)).is_equal(span)
	assert_that(PaletteResizeCommand.shift_span(Vector2i(2, 3), 2, -1)).is_equal(Palette.NO_RAMP)


func test_shift_locks() -> void:
	var locked: PackedByteArray = PackedByteArray()
	locked.resize(256)
	locked[1] = 1
	locked[4] = 1
	locked[255] = 1
	var inserted: PackedByteArray = PaletteResizeCommand.shift_locks(locked, 2, 1)
	assert_that(inserted.slice(0, 6)).is_equal(PackedByteArray([0, 1, 0, 0, 0, 1]))
	assert_int(inserted.size()).is_equal(256)
	var removed: PackedByteArray = PaletteResizeCommand.shift_locks(locked, 4, -1)
	assert_that(removed.slice(0, 5)).is_equal(PackedByteArray([0, 1, 0, 0, 0]))
	assert_int(removed[254]).is_equal(1)
	assert_int(removed[255]).is_equal(0)


func test_insert_keeps_the_picture_and_shifts_references() -> void:
	var doc: PrismDocument = _doc()
	doc.transparent_index = 4
	var before: PackedColorArray = _colors_of(doc)
	var command: InsertPaletteColorCommand = InsertPaletteColorCommand.new(3, Color.html("#123456"))
	command.apply(doc)
	assert_int(doc.palette.size()).is_equal(17)
	assert_str(doc.palette.get_color(3).to_html(false)).is_equal("123456")
	assert_that(doc.get_cel_image(0, 0).pixels).is_equal(PackedByteArray([0, 1, 2, 4, 5, 6]))
	assert_that(_colors_of(doc)).is_equal(before)
	assert_int(doc.transparent_index).is_equal(5)
	assert_that(doc.palette.ramps).is_equal([Vector2i(2, 6)])
	assert_int(doc.cycles[0].start_index).is_equal(9)
	assert_int(doc.cycles[0].end_index).is_equal(12)
	assert_that(doc.stencil.locked_indices()).is_equal(PackedInt32Array([4, 10]))
	assert_array(DocumentValidator.validate(doc)).is_empty()
	assert_bool(command.changes_palette()).is_true()
	assert_str(command.get_label()).contains("3")
	assert_int(command.get_byte_size()).is_greater(0)
	command.revert(doc)
	assert_that(doc.palette.colors).is_equal(PalettePresets.ega_16().colors)
	assert_that(doc.get_cel_image(0, 0).pixels).is_equal(PackedByteArray([0, 1, 2, 3, 4, 5]))
	assert_int(doc.transparent_index).is_equal(4)
	assert_that(doc.palette.ramps).is_equal([Vector2i(2, 5)])
	assert_int(doc.cycles[0].start_index).is_equal(8)
	assert_that(doc.stencil.locked_indices()).is_equal(PackedInt32Array([3, 9]))


func test_insert_at_the_end() -> void:
	var doc: PrismDocument = _doc()
	InsertPaletteColorCommand.new(16, Color.RED).apply(doc)
	assert_that(doc.palette.get_color(16)).is_equal(Color.RED)
	assert_that(doc.get_cel_image(0, 0).pixels).is_equal(PackedByteArray([0, 1, 2, 3, 4, 5]))


func test_remove_remaps_its_pixels_and_undo_restores_them() -> void:
	var doc: PrismDocument = _doc()
	doc.get_cel_image(0, 0).pixels = PackedByteArray([0, 3, 2, 3, 4, 5])
	var command: RemovePaletteColorCommand = RemovePaletteColorCommand.new(3, 5)
	command.apply(doc)
	assert_int(doc.palette.size()).is_equal(15)
	# 3 -> 5 (now 4); 4 -> 3; 5 -> 4.
	assert_that(doc.get_cel_image(0, 0).pixels).is_equal(PackedByteArray([0, 4, 2, 4, 3, 4]))
	assert_that(doc.palette.get_color(4)).is_equal(PalettePresets.ega_16().get_color(5))
	assert_that(doc.palette.ramps).is_equal([Vector2i(2, 4)])
	assert_int(doc.cycles[0].start_index).is_equal(7)
	assert_that(doc.stencil.locked_indices()).is_equal(PackedInt32Array([8]))
	assert_array(DocumentValidator.validate(doc)).is_empty()
	assert_int(command.get_byte_size()).is_greater(64 + 16 * 16)
	assert_str(command.get_label()).contains("3")
	command.revert(doc)
	assert_that(doc.get_cel_image(0, 0).pixels).is_equal(PackedByteArray([0, 3, 2, 3, 4, 5]))
	assert_that(doc.palette.colors).is_equal(PalettePresets.ega_16().colors)
	assert_that(doc.stencil.locked_indices()).is_equal(PackedInt32Array([3, 9]))
	command.apply(doc)
	assert_that(doc.get_cel_image(0, 0).pixels).is_equal(PackedByteArray([0, 4, 2, 4, 3, 4]))


func test_remove_to_a_lower_target_and_transparent_shift() -> void:
	var doc: PrismDocument = _doc()
	doc.transparent_index = 5
	RemovePaletteColorCommand.new(1, 0).apply(doc)
	assert_that(doc.get_cel_image(0, 0).pixels).is_equal(PackedByteArray([0, 0, 1, 2, 3, 4]))
	assert_int(doc.transparent_index).is_equal(4)


func test_remove_drops_ramps_and_cycles_left_with_one_entry() -> void:
	var doc: PrismDocument = PrismDocument.create(2, 1, PalettePresets.ega_16())
	doc.palette.add_ramp(4, 5)
	doc.cycles.append(CycleRange.new(8, 9, 4.0))
	var ramp_removal: RemovePaletteColorCommand = RemovePaletteColorCommand.new(5)
	ramp_removal.apply(doc)
	assert_bool(doc.palette.ramps.is_empty()).is_true()
	RemovePaletteColorCommand.new(7).apply(doc)
	assert_bool(doc.cycles.is_empty()).is_true()
	assert_array(DocumentValidator.validate(doc)).is_empty()
