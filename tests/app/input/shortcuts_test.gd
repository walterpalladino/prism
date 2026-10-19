extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func test_every_default_is_in_the_project_input_map() -> void:
	for action: StringName in Shortcuts.DEFAULTS:
		assert_bool(InputMap.has_action(action)).override_failure_message("missing action %s" % action).is_true()
		assert_int(InputMap.action_get_events(action).size()).is_equal(Shortcuts.DEFAULTS[action].size())


func test_make_event() -> void:
	var plain: InputEventKey = Shortcuts.make_event(KEY_D, 0)
	assert_int(plain.keycode).is_equal(KEY_D)
	assert_bool(plain.shift_pressed).is_false()
	assert_int(plain.device).is_equal(-1)
	var combo: InputEventKey = Shortcuts.make_event(KEY_Z, Shortcuts.CTRL | Shortcuts.SHIFT)
	assert_bool(combo.shift_pressed).is_true()
	assert_bool(combo.command_or_control_autoremap).is_true()
	assert_int(Shortcuts.events_for(&"prism_zoom_in").size()).is_equal(3)


func test_exact_match_keeps_shifted_and_plain_keys_apart() -> void:
	var shift_r: InputEventKey = InputEventKey.new()
	shift_r.keycode = KEY_R
	shift_r.shift_pressed = true
	shift_r.pressed = true
	assert_bool(shift_r.is_action_pressed(&"prism_tool_rect_filled", false, true)).is_true()
	assert_bool(shift_r.is_action_pressed(&"prism_tool_rect", false, true)).is_false()
