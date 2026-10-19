extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self
@warning_ignore_start("unsafe_cast", "unsafe_call_argument")  # this suite inspects untyped JSON on purpose


func _doc() -> PrismDocument:
	return SampleDocuments.rich()


# --- compositor ----------------------------------------------------------------

func test_composite_rgba_layers_offsets_and_opacity() -> void:
	var doc: PrismDocument = _doc()
	var image: Image = FrameCompositor.composite_rgba(doc, 0, doc.palette.colors)
	assert_that(image.get_size()).is_equal(Vector2i(12, 8))
	# Layer 0, frame 0 is offset by (1, -1): its pixel (1, 2) lands on (2, 1).
	assert_bool(image.get_pixel(2, 1).is_equal_approx(doc.palette.get_color(9))).is_true()
	assert_float(image.get_pixel(0, 0).a).is_equal(0.0)
	var ink: Color = image.get_pixel(1, 5)
	assert_float(ink.a).is_equal_approx(200.0 / 255.0, 0.01)
	doc.layers[1].visible = false
	assert_float(FrameCompositor.composite_rgba(doc, 0, doc.palette.colors).get_pixel(1, 5).a).is_equal(0.0)


func test_composite_indices_top_layer_wins() -> void:
	var doc: PrismDocument = PrismDocument.create(3, 1)
	doc.get_cel_image(0, 0).pixels = PackedByteArray([1, 1, 0])
	var fx_layer: Layer = Layer.new(doc.new_id("L"), "top")
	doc.layers.append(fx_layer)
	var top: IndexedImage = doc.create_image()
	top.pixels = PackedByteArray([0, 5, 6])
	doc.cels[Vector2i(1, 0)] = Cel.new(fx_layer.id, doc.frames[0].id, top.id)
	assert_that(FrameCompositor.composite_indices(doc, 0).pixels).is_equal(PackedByteArray([1, 5, 6]))
	doc.layers[1].visible = false
	assert_that(FrameCompositor.composite_indices(doc, 0).pixels).is_equal(PackedByteArray([1, 1, 0]))


func test_color_table_and_scale() -> void:
	var table: PackedByteArray = FrameCompositor.color_table(PackedColorArray([Color.RED, Color.WHITE]), 0, 0.5)
	assert_array([table[0], table[3], table[4], table[7]]).is_equal([0, 0, 255, 128])
	var image: Image = Image.create_empty(2, 1, false, Image.FORMAT_RGBA8)
	assert_that(FrameCompositor.scaled(image, 3).get_size()).is_equal(Vector2i(6, 3))
	assert_object(FrameCompositor.scaled(image, 1)).is_same(image)


# --- PNG -----------------------------------------------------------------------

func test_png_frame_and_sequence_names() -> void:
	var doc: PrismDocument = _doc()
	var image: Image = PngExport.frame_image(doc, 1, 2)
	assert_that(image.get_size()).is_equal(Vector2i(24, 16))
	var sink: MemoryFileSink = MemoryFileSink.new()
	var options: ExportOptions = ExportOptions.whole(doc)
	assert_str(PngExport.write_sequence(doc, options, sink, "/out/walk.png")).is_empty()
	assert_array(sink.files.keys()).is_equal(["/out/walk_0001.png", "/out/walk_0002.png", "/out/walk_0003.png"])
	assert_that(sink.image("/out/walk_0002.png").get_size()).is_equal(Vector2i(12, 8))


func test_png_sequence_bakes_cycling() -> void:
	var doc: PrismDocument = PrismDocument.create(2, 1)
	doc.get_cel_image(0, 0).pixels = PackedByteArray([16, 17])
	doc.frames[0].duration_ms = 200
	doc.cycles.append(CycleRange.new(16, 17, 10.0))
	var sink: MemoryFileSink = MemoryFileSink.new()
	var options: ExportOptions = ExportOptions.whole(doc)
	options.bake_cycles = true
	PngExport.write_sequence(doc, options, sink, "/c.png")
	assert_int(sink.files.size()).is_equal(2)
	var first: Image = sink.image("/c_0001.png")
	var second: Image = sink.image("/c_0002.png")
	assert_bool(first.get_pixel(0, 0).is_equal_approx(second.get_pixel(1, 0))).is_true()


# --- sprite sheet ------------------------------------------------------------------

func test_sheet_layouts() -> void:
	var doc: PrismDocument = _doc()
	var options: ExportOptions = ExportOptions.whole(doc)
	var expected: Dictionary = {
		ExportOptions.Layout.ROW: Vector2i(36, 8),
		ExportOptions.Layout.COLUMN: Vector2i(12, 24),
		ExportOptions.Layout.GRID: Vector2i(24, 16),
	}
	for layout: ExportOptions.Layout in expected:
		options.layout = layout
		var sheet: SpriteSheet = SpriteSheet.pack(doc, options)
		assert_that(sheet.image.get_size()).override_failure_message("layout %d" % layout).is_equal(expected[layout])
		assert_int(sheet.rects.size()).is_equal(3)
	options.layout = ExportOptions.Layout.TIGHT
	var tight: SpriteSheet = SpriteSheet.pack(doc, options)
	assert_bool(tight.trims[0].size.x < 12).is_true()
	assert_that(tight.rects[0].size).is_equal(tight.trims[0].size)


func test_sheet_json_lists_frames_durations_and_tags() -> void:
	var doc: PrismDocument = _doc()
	var sink: MemoryFileSink = MemoryFileSink.new()
	var options: ExportOptions = ExportOptions.whole(doc)
	assert_str(SpriteSheet.write(doc, options, sink, "/out/hero.png")).is_empty()
	var data: Dictionary = JSON.parse_string(sink.text("/out/hero.json"))
	var frames: Array = data["frames"]
	assert_int(frames.size()).is_equal(3)
	assert_int(int((frames[1] as Dictionary)["duration"])).is_equal(250)
	var meta: Dictionary = data["meta"]
	assert_str(meta["image"]).is_equal("hero.png")
	var tags: Array = meta["frameTags"]
	assert_int(tags.size()).is_equal(2)
	assert_str((tags[1] as Dictionary)["direction"]).is_equal("pingpong")
	assert_object(sink.image("/out/hero.png")).is_not_null()


func test_sheet_for_a_tag_only() -> void:
	var doc: PrismDocument = _doc()
	var options: ExportOptions = ExportOptions.for_tag(doc, 1)
	assert_that(options.frame_range).is_equal(Vector2i(1, 2))
	assert_int(options.direction).is_equal(PrismEnums.TagDirection.PING_PONG)
	assert_int(SpriteSheet.pack(doc, options).rects.size()).is_equal(2)


# --- SpriteFrames ------------------------------------------------------------------

func test_sprite_frames_tres_text() -> void:
	var doc: PrismDocument = _doc()
	var sink: MemoryFileSink = MemoryFileSink.new()
	sink.markers["/game"] = "project.godot"
	assert_str(SpriteFramesWriter.write(doc, 1, sink, "/game/art/hero.tres")).is_empty()
	var tres: String = sink.text("/game/art/hero.tres")
	assert_str(tres).contains("[gd_resource type=\"SpriteFrames\"")
	assert_str(tres).contains("path=\"res://art/hero.png\"")
	assert_str(tres).contains("\"name\": &\"walk\"")
	assert_str(tres).contains("\"name\": &\"hop\"")
	assert_str(tres).contains("\"speed\": 10.0")
	assert_str(tres).contains("\"duration\": 2.5")
	assert_object(sink.image("/game/art/hero.png")).is_not_null()


func test_sprite_frames_needs_a_godot_project() -> void:
	var sink: MemoryFileSink = MemoryFileSink.new()
	assert_str(SpriteFramesWriter.write(_doc(), 1, sink, "/nowhere/hero.tres")).contains("inside a Godot project")
	assert_bool(sink.files.is_empty()).is_true()


func test_untagged_document_gets_a_default_animation() -> void:
	var doc: PrismDocument = PrismDocument.create(4, 4)
	var options: ExportOptions = ExportOptions.whole(doc)
	var tres: String = SpriteFramesWriter.build_tres(doc, SpriteSheet.pack(doc, options), "res://a.png")
	assert_str(tres).contains("&\"default\"")


# --- GIF ---------------------------------------------------------------------

func test_gif_frames_match_composited_indices() -> void:
	var doc: PrismDocument = _doc()
	var options: ExportOptions = ExportOptions.whole(doc)
	var gif: GifReader = GifReader.parse(GifWriter.encode(doc, options))
	assert_str(gif.error).is_empty()
	assert_array([gif.width, gif.height]).is_equal([12, 8])
	assert_bool(gif.loops_forever).is_true()
	assert_int(gif.frames.size()).is_equal(3)
	for f: int in 3:
		var frame: Dictionary = gif.frames[f]
		assert_bool(frame["indices"] == FrameCompositor.composite_indices(doc, f).pixels).override_failure_message("frame %d" % f).is_true()
		assert_int(frame["transparent"]).is_equal(doc.transparent_index)
	assert_array([gif.frames[0]["delay_cs"], gif.frames[1]["delay_cs"], gif.frames[2]["delay_cs"]]).is_equal([10, 25, 10])
	assert_bool(gif.global_colors[9].is_equal_approx(doc.palette.get_color(9))).is_true()


func test_gif_delays_do_not_drift() -> void:
	var doc: PrismDocument = PrismDocument.create(2, 2)
	for i: int in 9:
		doc.frames.append(Frame.new(doc.new_id("F"), 33))
		doc.cels[Vector2i(0, i + 1)] = Cel.new(doc.layers[0].id, doc.frames[i + 1].id, doc.get_cel(0, 0).image_id)
	doc.frames[0].duration_ms = 33
	var gif: GifReader = GifReader.parse(GifWriter.encode(doc, ExportOptions.whole(doc)))
	var total: int = 0
	for frame: Dictionary in gif.frames:
		total += int(frame["delay_cs"])
	assert_int(total).is_equal(33)


func test_gif_bake_uses_local_tables_and_scale() -> void:
	var doc: PrismDocument = PrismDocument.create(2, 1)
	doc.get_cel_image(0, 0).pixels = PackedByteArray([16, 17])
	doc.frames[0].duration_ms = 200
	doc.cycles.append(CycleRange.new(16, 17, 10.0))
	var options: ExportOptions = ExportOptions.whole(doc)
	options.bake_cycles = true
	options.scale = 2
	var sink: MemoryFileSink = MemoryFileSink.new()
	assert_str(GifWriter.write(doc, options, sink, "/anim")).is_empty()
	var gif: GifReader = GifReader.parse(sink.files["/anim.gif"])
	assert_str(gif.error).is_empty()
	assert_array([gif.width, gif.height]).is_equal([4, 2])
	assert_int(gif.frames.size()).is_equal(2)
	var second: PackedColorArray = gif.frames[1]["local_colors"]
	assert_bool(second[17].is_equal_approx(doc.palette.get_color(16))).is_true()
	assert_int((gif.frames[0]["indices"] as PackedByteArray).size()).is_equal(8)


# --- PNG import ----------------------------------------------------------------

func test_png_import_maps_to_nearest_palette_color() -> void:
	var palette: Palette = PalettePresets.ega_16()
	var image: Image = Image.create_empty(3, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color.html("#aa0000"))
	image.set_pixel(1, 0, Color.html("#fe5050"))
	image.set_pixel(2, 0, Color(1, 1, 1, 0))
	var indexed: IndexedImage = PngImport.to_indexed(image, palette, 0)
	assert_that(indexed.pixels).is_equal(PackedByteArray([4, 12, 0]))
	assert_int(PngImport.nearest_index(palette, 0, 0, 0, 0)).is_equal(8)


func test_png_to_document_uses_its_own_colors() -> void:
	var image: Image = Image.create_empty(4, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	image.set_pixel(1, 1, Color.html("#123456"))
	image.set_pixel(2, 1, Color.html("#abcdef"))
	var result: DocumentResult = PngImport.to_document(image, PalettePresets.default_32())
	assert_bool(result.is_ok()).is_true()
	var doc: PrismDocument = result.document
	assert_int(doc.palette.size()).is_equal(3)
	assert_int(doc.get_cel_image(0, 0).get_index(2, 1)).is_equal(2)
	assert_int(doc.get_cel_image(0, 0).get_index(0, 0)).is_equal(0)
	var huge: Image = Image.create_empty(600, 2, false, Image.FORMAT_RGBA8)
	assert_str(PngImport.to_document(huge, PalettePresets.default_32()).error).contains("maximum canvas")
	assert_object(PngImport.load_image(PackedByteArray([1, 2]))).is_null()
