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


func test_atlas_holds_every_icon() -> void:
	var atlas: ImageTexture = PrismIcons.atlas()
	assert_object(PrismIcons.atlas()).is_same(atlas)
	var region: Rect2 = PrismIcons.atlas_region("eye")
	assert_that(region.size).is_equal(Vector2(24, 24))
	var from_atlas: Image = atlas.get_image().get_region(Rect2i(region))
	var original: Image = PrismIcons.get_icon("eye").get_image()
	original.convert(Image.FORMAT_RGBA8)
	assert_bool(from_atlas.get_data() == original.get_data()).is_true()
	assert_bool(PrismIcons.atlas_region("no_such_icon").has_area()).is_false()
