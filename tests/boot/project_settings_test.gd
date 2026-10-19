extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func test_renderer_is_compatibility() -> void:
	var method: String = ProjectSettings.get_setting("rendering/renderer/rendering_method")
	assert_str(method).is_equal("gl_compatibility")


func test_typing_warnings_are_errors() -> void:
	var names: PackedStringArray = [
		"untyped_declaration",
		"inferred_declaration",
		"unsafe_property_access",
		"unsafe_method_access",
		"unsafe_cast",
		"unsafe_call_argument",
		"return_value_discarded",
	]
	for warning_name: String in names:
		var level: int = ProjectSettings.get_setting("debug/gdscript/warnings/" + warning_name)
		assert_int(level).override_failure_message(warning_name).is_equal(2)


func test_editor_context_is_autoloaded() -> void:
	var context: Node = get_tree().root.get_node_or_null("EditorContext")
	assert_object(context).is_not_null()
