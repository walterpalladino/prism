## Menus and dropdowns get roomy rows and a filled hover highlight from the PRISM theme.
extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func test_theme_popup_values() -> void:
	var theme: Theme = PrismTheme.build()
	assert_int(theme.get_constant("v_separation", "PopupMenu")).is_greater_equal(8)
	var hover: StyleBoxFlat = theme.get_stylebox("hover", "PopupMenu") as StyleBoxFlat
	assert_object(hover).is_not_null()
	assert_that(hover.bg_color).is_equal(PrismTheme.BLUE)
	assert_array([hover.content_margin_top, hover.content_margin_bottom]).is_equal([-1.0, -1.0])
	assert_object(theme.get_stylebox("separator", "PopupMenu")).is_instanceof(StyleBoxLine)


func test_menu_bar_and_dropdown_popups_inherit_the_style(do_skip: bool = DisplayServer.get_name() == "headless", skip_reason: String = "needs a window") -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://ui/scenes/main.tscn")
	await runner.simulate_frames(2)
	var popups: Array[Node] = runner.scene().find_children("*", "PopupMenu", true, false)
	assert_int(popups.size()).is_greater(5)
	for node: Node in popups:
		var popup: PopupMenu = node as PopupMenu
		assert_int(popup.get_theme_constant("v_separation")).override_failure_message(String(popup.get_path())).is_greater_equal(8)
	var dropdowns: Array[Node] = runner.scene().find_children("*", "OptionButton", true, false)
	assert_int(dropdowns.size()).is_greater(0)
	for node: Node in dropdowns:
		var option: OptionButton = node as OptionButton
		assert_int(option.get_popup().get_theme_constant("v_separation")).is_greater_equal(8)


func test_menu_bar_items_are_padded_and_hover_changes_only_the_background() -> void:
	var theme: Theme = PrismTheme.build()
	assert_int(theme.get_constant("h_separation", "MenuBar")).is_greater(0)
	var normal: StyleBoxFlat = theme.get_stylebox("normal", "MenuBar") as StyleBoxFlat
	var hover: StyleBoxFlat = theme.get_stylebox("hover", "MenuBar") as StyleBoxFlat
	assert_float(normal.content_margin_left).is_greater_equal(8.0)
	assert_float(hover.content_margin_left).is_equal(normal.content_margin_left)
	assert_float(normal.bg_color.a).is_equal(0.0)
	assert_float(hover.bg_color.a).is_greater(0.0)
	assert_that(theme.get_color("font_hover_color", "MenuBar")).is_equal(theme.get_color("font_color", "MenuBar"))
