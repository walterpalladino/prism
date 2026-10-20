extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self

func test_about_includes_godot_and_third_party_notices() -> void:
	var notices: String = preload("res://ui/scenes/main.gd").engine_notices()
	assert_str(notices).contains("Godot Engine contributors")
	assert_str(notices).contains("- The FreeType Project")
	assert_str(notices).contains("### Expat")


func test_credits_name_every_icon_drawn_for_prism() -> void:
	var credits: String = FileAccess.get_file_as_string("res://CREDITS.md")
	for icon_name: String in ["line", "fill", "rotate", "rotate_ccw"]:
		assert_str(credits).contains("ui/icons/%s.svg" % icon_name)
