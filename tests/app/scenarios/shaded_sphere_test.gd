## M3 exit: a sphere shaded with Shade mode only, the outline protected by the stencil
## (GDD §10 M3, §13 task 3). The result must match a reviewed golden image.
extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self

const OUTLINE: int = 1
const BASE: int = 3


func _ellipse(fx: AppFixture, from: Vector2i, to: Vector2i, button: PrismEnums.PaintButton = AppFixture.PRIMARY) -> void:
	fx.stroke(&"ellipse", [from, to], button)


func test_shaded_sphere_matches_golden() -> void:
	var fx: AppFixture = AppFixture.new(24, 24)
	var ramp: Vector2i = fx.bus.document.palette.find_ramp(BASE)
	assert_that(ramp).is_equal(Vector2i(1, 6))

	# Base disk and outline in Color mode.
	fx.state.filled_shapes = true
	fx.state.set_fg(BASE)
	_ellipse(fx, Vector2i(2, 2), Vector2i(21, 21))
	fx.state.filled_shapes = false
	fx.state.set_fg(OUTLINE)
	_ellipse(fx, Vector2i(2, 2), Vector2i(21, 21))
	var outline_pixels: int = fx.image().pixels.count(OUTLINE)

	# Protect the outline, then shade with Shade mode only.
	fx.palette.toggle_lock(OUTLINE)
	fx.state.set_draw_mode(PrismEnums.DrawMode.SHADE)
	fx.state.filled_shapes = true
	_ellipse(fx, Vector2i(2, 2), Vector2i(21, 21), AppFixture.SECONDARY)
	_ellipse(fx, Vector2i(3, 3), Vector2i(17, 17))
	_ellipse(fx, Vector2i(4, 4), Vector2i(13, 13))
	_ellipse(fx, Vector2i(5, 5), Vector2i(10, 10))
	_ellipse(fx, Vector2i(6, 6), Vector2i(8, 8))
	_ellipse(fx, Vector2i(6, 6), Vector2i(8, 8))

	var image: IndexedImage = fx.image()
	assert_int(image.pixels.count(OUTLINE)).override_failure_message("stencil must protect the outline").is_equal(outline_pixels)
	assert_int(image.get_index(0, 0)).override_failure_message("Shade must not touch pixels outside a ramp").is_equal(0)
	assert_int(image.get_index(7, 7)).override_failure_message("highlight clamps at the ramp end").is_equal(ramp.y)
	assert_int(image.get_index(18, 18)).is_equal(BASE - 1)
	var text: String = Golden.image_text(image)
	assert_str(text).is_equal(Golden.expect("scenarios/shaded_sphere", text))
