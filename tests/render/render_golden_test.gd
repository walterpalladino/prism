## Real-renderer golden tests (GDD §11): the canvas is rendered and read back, then compared
## with reviewed PNGs in tests/golden/render/. Needs a window (skipped under --headless).
## Regenerate with PRISM_UPDATE_GOLDEN=1 and review the PNGs before committing.
extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self

const VIEW_SIZE: Vector2 = Vector2(160, 160)

var _fx: AppFixture
var _view: CanvasView
var _texture: PaletteTexture


func before() -> void:
	# gdUnit4's runner minimizes its window between suites; minimized windows are not drawn.
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func before_test() -> void:
	_fx = AppFixture.new(16, 16)
	_texture = PaletteTexture.new(_fx.bus.document.palette)
	var _display: PaletteDisplay = PaletteDisplay.new(_texture, _fx.cycling)


func after_test() -> void:
	if _view != null:
		_view.queue_free()
		_view = null


func _render() -> Image:
	_view = CanvasView.new()
	_view.size = VIEW_SIZE
	add_child(_view)
	_view.setup(_fx.bus, _fx.state, _fx.controller, CelTextureCache.new(), _texture)
	_view.set_show_grid(false)
	_view.set_zoom(8, Vector2.ZERO)
	_view.pan = Vector2(16, 16)
	_view.set_zoom(8, Vector2.ZERO)
	# Read back only after frames have actually been drawn. macOS may stop drawing an occluded
	# window, so wait with a time limit instead of awaiting frame_post_draw forever.
	var target: int = Engine.get_frames_drawn() + 3
	var deadline: int = Time.get_ticks_msec() + 3000
	while Engine.get_frames_drawn() < target and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if Engine.get_frames_drawn() < target:
		return null
	await RenderingServer.frame_post_draw
	return _view.capture()


func _check(name: String, image: Image) -> void:
	assert_object(image).override_failure_message("renderer did not draw within 3 s (is the test window hidden or occluded?)").is_not_null()
	if image == null:
		return
	# A blank capture would otherwise "match" a golden regenerated from it.
	var data: PackedByteArray = image.get_data()
	assert_int(data.count(data[0])).override_failure_message("render/%s capture is blank" % name).is_less(data.size())
	var expected: Image = Golden.expect_png("render/" + name, image)
	assert_object(expected).override_failure_message("missing golden render/%s.png" % name).is_not_null()
	assert_int(Golden.pixel_differences(image, expected)).override_failure_message("render/%s differs" % name).is_equal(0)


func _paint_layers() -> void:
	var bottom: IndexedImage = _fx.image_at(0, 0)
	for y: int in 16:
		for x: int in 16:
			if (x + y) % 4 != 0:
				bottom.set_index(x, y, 9 if x < 8 else 18)
	_fx.timeline.add_layer()
	var top: IndexedImage = _fx.image_at(1, 0)
	for y: int in range(4, 12):
		for x: int in range(2, 14):
			top.set_index(x, y, 27 if y < 8 else 6)
	_fx.timeline.set_layer_opacity(1, 128)


func test_lut_layers_transparency_and_opacity(do_skip: bool = DisplayServer.get_name() == "headless", skip_reason: String = "needs a real renderer") -> void:
	_paint_layers()
	_check("lut_layers", await _render())


func test_color_cycling_shifts_the_lut(do_skip: bool = DisplayServer.get_name() == "headless", skip_reason: String = "needs a real renderer") -> void:
	var image: IndexedImage = _fx.image()
	for y: int in 16:
		for x: int in 16:
			image.set_index(x, y, 16 + (y % 6))
	_fx.palette.add_cycle(16, 21, 10.0, 1)
	_fx.cycling.request(&"tab", true)
	_fx.cycling.advance(0.25)
	_check("cycling_offset_2", await _render())


func test_onion_skin_tints_neighbors(do_skip: bool = DisplayServer.get_name() == "headless", skip_reason: String = "needs a real renderer") -> void:
	_fx.timeline.insert_frame(1)
	_fx.timeline.insert_frame(2)
	for f: int in 3:
		var image: IndexedImage = _fx.image_at(0, f)
		for y: int in range(4, 12):
			for x: int in range(2 + f * 4, 6 + f * 4):
				image.set_index(x, y, 6)
	_fx.state.set_frame(1)
	_fx.state.set_onion(true, 1, 1, false)
	_fx.state.set_onion_in_front(false)
	_check("onion_1_past_1_future", await _render())


func test_onion_in_front_shows_over_an_identical_frame(do_skip: bool = DisplayServer.get_name() == "headless", skip_reason: String = "needs a real renderer") -> void:
	for y: int in range(4, 12):
		for x: int in range(4, 12):
			_fx.image().set_index(x, y, 6)
	_fx.timeline.duplicate_frame(0, false)
	_fx.state.set_onion(true, 1, 0, false)
	var image: Image = await _render()
	_check("onion_in_front_identical_frame", image)
	# The tint must show over the current frame's white square.
	var center: Color = image.get_pixel(int(VIEW_SIZE.x / 2), int(VIEW_SIZE.y / 2))
	assert_bool(center.is_equal_approx(Color.WHITE)).override_failure_message("onion not visible: %s" % center).is_false()
