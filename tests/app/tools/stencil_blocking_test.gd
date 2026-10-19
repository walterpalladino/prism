extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self

var _blocked: Array[PackedInt32Array] = []


func _fx() -> AppFixture:
	_blocked.clear()
	var fx: AppFixture = AppFixture.new(6, 2)
	fx.image().pixels = PackedByteArray([0, 3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	fx.bus.document.stencil.set_locked(3, true)
	fx.state.set_fg(5)
	Signals.on(fx.bus.stencil_blocked, func(_id: StringName, offsets: PackedInt32Array) -> void: _blocked.append(offsets))
	return fx


func test_painter_lists_each_blocked_pixel_once() -> void:
	var image: IndexedImage = IndexedImage.from_rows(&"c", ["0330"])
	var stencil: Stencil = Stencil.new()
	stencil.set_locked(3, true)
	var ctx: InkContext = InkContext.new(1, 0, PrismEnums.PaintButton.PRIMARY, PalettePresets.grayscale(8))
	var painter: Painter = Painter.new(image, Brush.builtin(Brush.Shape.SQUARE, 2), ColorInk.new(), ctx, stencil)
	painter.stamp(Vector2i(1, 0))
	painter.stamp(Vector2i(2, 0))
	assert_that(painter.blocked).is_equal(PackedInt32Array([1, 2]))
	assert_that(image.to_rows()[0]).is_equal("0331")


func test_pencil_reports_only_new_blocked_pixels() -> void:
	var fx: AppFixture = _fx()
	fx.stroke(&"pencil", [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 0)])
	assert_int(_blocked.size()).is_equal(2)
	assert_that(_blocked[0]).is_equal(PackedInt32Array([1]))
	assert_that(_blocked[1]).is_equal(PackedInt32Array([2]))


func test_shape_reports_on_release() -> void:
	var fx: AppFixture = _fx()
	fx.stroke(&"line", [Vector2i(0, 0), Vector2i(5, 0)])
	assert_int(_blocked.size()).is_equal(1)
	assert_that(_blocked[0]).is_equal(PackedInt32Array([1, 2]))


func test_fill_on_locked_index_reports_the_click() -> void:
	var fx: AppFixture = _fx()
	fx.click(&"fill", Vector2i(2, 0))
	assert_that(_blocked[0]).is_equal(PackedInt32Array([2]))
	assert_bool(fx.bus.history.can_undo()).is_false()


func test_no_signal_without_blocks() -> void:
	var fx: AppFixture = _fx()
	fx.stroke(&"pencil", [Vector2i(0, 1), Vector2i(5, 1)])
	fx.bus.notify_stencil_blocked(&"x", PackedInt32Array())
	assert_int(_blocked.size()).is_equal(0)
