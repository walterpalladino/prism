extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func test_every_toolbox_tool_has_a_24px_icon() -> void:
	for entry: Array in Toolbox.TOOLS:
		var icon_name: String = entry[1]
		var icon: Texture2D = PrismIcons.get_icon(icon_name)
		assert_object(icon).override_failure_message("missing icon %s" % icon_name).is_not_null()
		assert_that(icon.get_size()).is_equal(Vector2(24, 24))


func test_every_menu_icon_exists() -> void:
	for menu: Array in preload("res://ui/scenes/main.gd").MENUS:
		var items: Array = menu[1]
		for item: Array in items:
			var icon_name: String = item[2]
			if icon_name != "":
				assert_bool(PrismIcons.has_icon(icon_name)).override_failure_message("missing icon %s" % icon_name).is_true()


func test_unknown_icon_is_null() -> void:
	assert_object(PrismIcons.get_icon("no_such_icon")).is_null()
