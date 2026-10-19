## Node-level checks for the render infrastructure that do not need a real GPU.
extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func test_palette_texture_entries() -> void:
	var palette: Palette = PalettePresets.ega_16()
	var texture: PaletteTexture = PaletteTexture.new(palette)
	assert_that(texture.texture.get_size()).is_equal(Vector2(256, 1))
	assert_bool(texture.get_color(9).is_equal_approx(palette.get_color(9))).is_true()
	assert_float(texture.get_color(200).a).is_equal(0.0)
	palette.set_color(9, Color.RED)
	texture.update(palette)
	assert_bool(texture.get_color(9).is_equal_approx(Color.RED)).is_true()


func test_texture_cache_marks_and_flushes() -> void:
	var doc: PrismDocument = PrismDocument.create(4, 4)
	var cache: CelTextureCache = CelTextureCache.new()
	var image: IndexedImage = doc.get_cel_image(0, 0)
	var texture: ImageTexture = cache.get_texture(image)
	assert_object(cache.get_texture(image)).is_same(texture)
	assert_int(cache.size()).is_equal(1)
	cache.mark_dirty(&"unknown")
	assert_bool(cache.has_dirty()).is_false()
	image.set_index(1, 1, 5)
	cache.mark_dirty(image.id)
	assert_bool(cache.has_dirty()).is_true()
	cache.flush(doc)
	assert_bool(cache.has_dirty()).is_false()
	assert_int(cache.get_source(image.id).get_pixel(1, 1).r8).is_equal(5)
	cache.clear()
	assert_int(cache.size()).is_equal(0)


func test_cel_stack_builds_visible_cels_with_offsets() -> void:
	var doc: PrismDocument = PrismDocument.create(4, 4)
	doc.layers.append(Layer.new(doc.new_id("L"), "Top"))
	doc.cels[Vector2i(1, 0)] = Cel.new(doc.layers[1].id, doc.frames[0].id, doc.create_image().id, Vector2i(2, 1))
	var stack: CelStack = auto_free(CelStack.new())
	stack.setup(CelTextureCache.new(), PaletteTexture.new(doc.palette))
	stack.rebuild(doc, 0)
	assert_int(stack.get_child_count()).is_equal(2)
	var top: Sprite2D = stack.get_child(1) as Sprite2D
	assert_that(top.position).is_equal(Vector2(2, 1))
	doc.layers[0].visible = false
	stack.rebuild(doc, 0)
	await get_tree().process_frame
	assert_int(stack.get_child_count()).is_equal(1)
	var material: ShaderMaterial = CelStack.make_material(null, null, 3, 0.5)
	assert_int(material.get_shader_parameter("transparent_index")).is_equal(3)


func test_canvas_view_coordinates_and_zoom() -> void:
	var fx: AppFixture = AppFixture.new(64, 32)
	var view: CanvasView = auto_free(CanvasView.new())
	add_child(view)
	view.size = Vector2(800, 600)
	view.setup(fx.bus, fx.state, fx.controller, CelTextureCache.new(), PaletteTexture.new(fx.bus.document.palette))
	view.fit()
	assert_int(view.zoom).is_equal(10)
	assert_that(view.get_canvas_size()).is_equal(Vector2i(64, 32))
	var p: Vector2i = Vector2i(7, 3)
	assert_that(view.local_to_pixel(view.pixel_to_local(p))).is_equal(p)
	var focus: Vector2 = view.pixel_to_local(p)
	view.zoom_step(1, focus)
	assert_int(view.zoom).is_equal(12)
	assert_that(view.local_to_pixel(focus)).is_equal(p)
	view.zoom_step(-20)
	assert_int(view.zoom).is_equal(1)
	view.reset_zoom()
	assert_int(view.zoom).is_equal(1)
	view.set_zoom(99, Vector2.ZERO)
	assert_int(view.zoom).is_equal(32)
	view.set_show_grid(false)
	assert_bool(view.show_grid).is_false()
	view.set_tile_grid(16)
	assert_int(view.tile_grid).is_equal(16)
	var event: InputEventKey = InputEventKey.new()
	event.shift_pressed = true
	event.alt_pressed = true
	assert_int(CanvasView.modifiers_of(event)).is_equal(Tool.MOD_SHIFT | Tool.MOD_ALT)
	remove_child(view)


func test_signals_helper_connects() -> void:
	var bus: CommandBus = CommandBus.new(PrismDocument.create(2, 2), History.new())
	var hits: Array[int] = [0]
	Signals.on(bus.history_changed, func() -> void: hits[0] += 1)
	bus.history_changed.emit()
	assert_int(hits[0]).is_equal(1)


func test_stencil_flash_fades_out() -> void:
	var flash: StencilFlash = auto_free(StencilFlash.new())
	add_child(flash)
	flash.flash(PackedVector2Array())
	assert_bool(flash.is_flashing()).is_false()
	flash.flash(PackedVector2Array([Vector2(1, 2)]))
	assert_bool(flash.is_flashing()).is_true()
	await get_tree().create_timer(StencilFlash.FLASH_SECONDS + 0.1).timeout
	assert_bool(flash.is_flashing()).is_false()
	remove_child(flash)
