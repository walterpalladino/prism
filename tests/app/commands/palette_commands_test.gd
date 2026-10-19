extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func _doc() -> PrismDocument:
	var doc: PrismDocument = PrismDocument.create(4, 1, PalettePresets.ega_16())
	doc.get_cel_image(0, 0).pixels = PackedByteArray([0, 1, 2, 3])
	return doc


func test_set_palette_color() -> void:
	var doc: PrismDocument = _doc()
	var command: SetPaletteColorCommand = SetPaletteColorCommand.new(2, doc.palette.get_color(2), Color.RED)
	command.apply(doc)
	assert_that(doc.palette.get_color(2)).is_equal(Color.RED)
	command.revert(doc)
	assert_that(doc.palette.get_color(2)).is_equal(Color.html("#00aa00"))
	assert_bool(command.changes_palette()).is_true()
	assert_str(command.get_label()).contains("2")
	assert_int(command.get_byte_size()).is_greater(0)


func test_permutation() -> void:
	var map: PackedByteArray = ReorderPaletteCommand.permutation(5, 1, 3)
	assert_that(map.slice(0, 5)).is_equal(PackedByteArray([0, 3, 1, 2, 4]))
	assert_int(map[200]).is_equal(200)


func test_reorder_with_remap_keeps_the_picture() -> void:
	var doc: PrismDocument = _doc()
	doc.stencil.set_locked(1, true)
	var before: PackedColorArray = PackedColorArray()
	for v: int in doc.get_cel_image(0, 0).pixels:
		before.append(doc.palette.get_color(v))
	var command: ReorderPaletteCommand = ReorderPaletteCommand.new(1, 3, true)
	command.apply(doc)
	var image: IndexedImage = doc.get_cel_image(0, 0)
	assert_that(image.pixels).is_equal(PackedByteArray([0, 3, 1, 2]))
	for i: int in 4:
		assert_that(doc.palette.get_color(image.pixels[i])).is_equal(before[i])
	assert_bool(doc.stencil.is_locked(3)).is_true()
	assert_bool(doc.stencil.is_locked(1)).is_false()
	command.revert(doc)
	assert_that(image.pixels).is_equal(PackedByteArray([0, 1, 2, 3]))
	assert_bool(doc.stencil.is_locked(1)).is_true()
	assert_that(doc.palette.colors).is_equal(PalettePresets.ega_16().colors)


func test_reorder_moves_transparent_index_with_remap() -> void:
	var doc: PrismDocument = _doc()
	ReorderPaletteCommand.new(0, 2, true).apply(doc)
	assert_int(doc.transparent_index).is_equal(2)


func test_reorder_without_remap_keeps_indices() -> void:
	var doc: PrismDocument = _doc()
	var command: ReorderPaletteCommand = ReorderPaletteCommand.new(1, 3, false)
	command.apply(doc)
	assert_that(doc.get_cel_image(0, 0).pixels).is_equal(PackedByteArray([0, 1, 2, 3]))
	assert_that(doc.palette.get_color(3)).is_equal(Color.html("#0000aa"))
	assert_int(doc.transparent_index).is_equal(0)
	assert_str(command.get_label()).contains("no remap")
	command.revert(doc)
	assert_that(doc.palette.colors).is_equal(PalettePresets.ega_16().colors)


func test_replace_palette() -> void:
	var doc: PrismDocument = _doc()
	var replacement: Palette = PalettePresets.grayscale(4)
	var command: ReplacePaletteCommand = ReplacePaletteCommand.new(doc.palette, replacement, "Gray")
	replacement.set_color(0, Color.RED)
	command.apply(doc)
	assert_int(doc.palette.size()).is_equal(4)
	assert_that(doc.palette.get_color(0)).is_equal(Color.BLACK)
	assert_int(doc.palette.ramps.size()).is_equal(1)
	command.revert(doc)
	assert_int(doc.palette.size()).is_equal(16)
	assert_bool(doc.palette.ramps.is_empty()).is_true()
	assert_str(command.get_label()).is_equal("Gray")
	assert_int(command.get_byte_size()).is_greater(0)


func test_set_stencil() -> void:
	var doc: PrismDocument = _doc()
	var after: Stencil = Stencil.new()
	after.set_locked(5, true)
	var command: SetStencilCommand = SetStencilCommand.new(doc.stencil.locked, after.locked, "Lock")
	command.apply(doc)
	assert_bool(doc.stencil.is_locked(5)).is_true()
	command.revert(doc)
	assert_bool(doc.stencil.is_locked(5)).is_false()
	assert_int(command.get_byte_size()).is_equal(512)
	assert_str(command.get_label()).is_equal("Lock")


func test_bus_emits_palette_changed_only_for_palette_commands() -> void:
	var bus: CommandBus = CommandBus.new(_doc(), History.new())
	var count: Array[int] = [0]
	Signals.on(bus.palette_changed, func() -> void: count[0] += 1)
	bus.execute(SetPaletteColorCommand.new(1, Color.BLACK, Color.WHITE))
	bus.execute(MoveCelCommand.new(Vector2i.ZERO, Vector2i.ZERO, Vector2i.ONE))
	bus.undo()
	bus.undo()
	bus.notify_palette_changed()
	assert_int(count[0]).is_equal(3)
