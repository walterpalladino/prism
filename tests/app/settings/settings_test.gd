extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self

const PATH: String = "user://test_settings.cfg"
const KEYS: String = "user://test_keybindings.json"


func after_test() -> void:
	for path: String in [PATH, KEYS]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func test_defaults_when_no_file() -> void:
	var settings: Settings = SettingsStore.new(PATH).load_settings()
	assert_str(settings.theme).is_equal("dark")
	assert_str(settings.key_preset).is_equal("modern")
	assert_float(settings.ui_scale).is_equal(1.0)
	assert_int(settings.autosave_interval_s).is_equal(60)


func test_save_load_round_trip() -> void:
	var store: SettingsStore = SettingsStore.new(PATH)
	var settings: Settings = Settings.new()
	settings.theme = "light"
	settings.ui_scale = 1.5
	settings.autosave_interval_s = 0
	settings.key_preset = "classic"
	settings.checker_a = Color.html("#112233")
	settings.onion_future_tint = Color.html("#00ff00")
	assert_str(store.save_settings(settings)).is_empty()
	var loaded: Settings = store.load_settings()
	assert_array([loaded.theme, loaded.ui_scale, loaded.autosave_interval_s, loaded.key_preset]).is_equal(["light", 1.5, 0, "classic"])
	assert_str(loaded.checker_a.to_html(false)).is_equal("112233")
	assert_str(loaded.onion_future_tint.to_html(false)).is_equal("00ff00")


func test_hand_edited_garbage_falls_back() -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("[prism]\ntheme=\"neon\"\nui_scale=9.0\nautosave_interval_s=\"soon\"\nkey_preset=3\nchecker_a=\"#nothex\"\n")
	file.close()
	var loaded: Settings = SettingsStore.new(PATH).load_settings()
	assert_str(loaded.theme).is_equal("dark")
	assert_float(loaded.ui_scale).is_equal(Settings.MAX_UI_SCALE)
	assert_int(loaded.autosave_interval_s).is_equal(60)
	assert_str(loaded.key_preset).is_equal("modern")
	assert_str(loaded.checker_a.to_html(false)).is_equal(Settings.new().checker_a.to_html(false))


func test_duplicate_is_independent() -> void:
	var settings: Settings = Settings.new()
	var copy: Settings = settings.duplicate_settings()
	copy.theme = "light"
	assert_str(settings.theme).is_equal("dark")


func test_presets_and_key_text() -> void:
	var modern: Dictionary[StringName, Array] = Shortcuts.preset("modern")
	var classic: Dictionary[StringName, Array] = Shortcuts.preset("classic")
	assert_int(modern.size()).is_equal(Shortcuts.DEFAULTS.size())
	assert_array(classic[&"prism_frame_next"]).is_equal([[KEY_2, 0]])
	assert_array(modern[&"prism_frame_next"]).is_equal([[KEY_PERIOD, 0]])
	assert_array(classic[&"prism_brush_restore"][0]).is_equal([KEY_PERIOD, 0])
	assert_array(Shortcuts.parse("Ctrl+Shift+Z")).is_equal([KEY_Z, Shortcuts.CTRL | Shortcuts.SHIFT])
	assert_array(Shortcuts.parse("alt+n")).is_equal([KEY_N, Shortcuts.ALT])
	assert_array(Shortcuts.parse("Hyper+Z")).is_empty()
	assert_array(Shortcuts.parse("Ctrl+Nonsense")).is_empty()
	assert_array(Shortcuts.parse("")).is_empty()
	assert_str(Shortcuts.describe([KEY_R, Shortcuts.SHIFT])).is_equal("Shift+R")
	assert_str(Shortcuts.describe([KEY_Z, Shortcuts.CTRL])).contains("+Z")


func test_classic_has_no_conflicting_keys() -> void:
	for preset_name: String in Settings.KEY_PRESETS:
		var seen: Dictionary[String, StringName] = {}
		var bindings: Dictionary[StringName, Array] = Shortcuts.preset(preset_name)
		for action: StringName in bindings:
			for binding: Array in bindings[action]:
				var key: String = Shortcuts.describe(binding)
				assert_bool(seen.has(key)).override_failure_message("%s: %s used by %s and %s" % [preset_name, key, seen.get(key, &""), action]).is_false()
				seen[key] = action


func test_keybinding_overrides() -> void:
	var store: KeybindingStore = KeybindingStore.new(KEYS)
	assert_bool(store.load_overrides().is_empty()).is_true()
	var file: FileAccess = FileAccess.open(KEYS, FileAccess.WRITE)
	file.store_string(JSON.stringify({"prism_tool_line": ["K", "Shift+K"], "prism_nope": ["A"], "prism_undo": "Z", "prism_redo": ["Ctrl+Bogus"]}))
	file.close()
	var overrides: Dictionary[StringName, Array] = store.load_overrides()
	assert_array(overrides[&"prism_tool_line"]).is_equal([[KEY_K, 0], [KEY_K, Shortcuts.SHIFT]])
	assert_int(store.errors.size()).is_equal(3)
	assert_bool(overrides.has(&"prism_redo")).is_true()
	assert_bool(overrides[&"prism_redo"].is_empty()).is_true()
	file = FileAccess.open(KEYS, FileAccess.WRITE)
	file.store_string("[not an object]")
	file.close()
	assert_bool(store.load_overrides().is_empty()).is_true()
	assert_str(store.errors[0]).contains("not a JSON object")


func test_save_bindings_template_round_trips() -> void:
	var store: KeybindingStore = KeybindingStore.new(KEYS)
	assert_str(store.save_bindings(Shortcuts.preset("classic"))).is_empty()
	var loaded: Dictionary[StringName, Array] = store.load_overrides()
	assert_array(store.errors).is_empty()
	assert_array(loaded[&"prism_frame_prev"]).is_equal([[KEY_1, 0]])
	assert_array(loaded[&"prism_undo"]).is_equal([[KEY_Z, Shortcuts.CTRL]])


func test_apply_changes_the_input_map_and_restores() -> void:
	var original: Array[InputEvent] = InputMap.action_get_events(&"prism_tool_line")
	var bindings: Dictionary[StringName, Array] = {&"prism_tool_line": [[KEY_K, 0]]}
	KeybindingStore.apply(bindings)
	var events: Array[InputEvent] = InputMap.action_get_events(&"prism_tool_line")
	assert_int((events[0] as InputEventKey).keycode).is_equal(KEY_K)
	KeybindingStore.apply(Shortcuts.preset("modern"))
	assert_int((InputMap.action_get_events(&"prism_tool_line")[0] as InputEventKey).keycode).is_equal((original[0] as InputEventKey).keycode)
