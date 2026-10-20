## Loads and saves Settings with ConfigFile at user://settings.cfg (GDD §7.13). Unknown or
## wrong-typed values fall back to defaults, so a hand-edited file can never break startup.
class_name SettingsStore
extends RefCounted

const DEFAULT_PATH: String = "user://settings.cfg"
const SECTION: String = "prism"

var path: String


func _init(p_path: String = DEFAULT_PATH) -> void:
	path = p_path


func load_settings() -> Settings:
	var settings: Settings = Settings.new()
	var config: ConfigFile = ConfigFile.new()
	if config.load(path) != OK:
		return settings
	settings.theme = _string(config, "theme", settings.theme)
	settings.ui_scale = _float(config, "ui_scale", settings.ui_scale)
	settings.autosave_interval_s = int(_float(config, "autosave_interval_s", settings.autosave_interval_s))
	settings.key_preset = _string(config, "key_preset", settings.key_preset)
	settings.checker_a = _color(config, "checker_a", settings.checker_a)
	settings.checker_b = _color(config, "checker_b", settings.checker_b)
	settings.onion_past_tint = _color(config, "onion_past_tint", settings.onion_past_tint)
	settings.onion_future_tint = _color(config, "onion_future_tint", settings.onion_future_tint)
	settings.default_palette = _string(config, "default_palette", settings.default_palette)
	settings.sanitize()
	return settings


## Returns "" or an error message.
func save_settings(settings: Settings) -> String:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(SECTION, "theme", settings.theme)
	config.set_value(SECTION, "ui_scale", settings.ui_scale)
	config.set_value(SECTION, "autosave_interval_s", settings.autosave_interval_s)
	config.set_value(SECTION, "key_preset", settings.key_preset)
	config.set_value(SECTION, "checker_a", "#" + settings.checker_a.to_html(false))
	config.set_value(SECTION, "checker_b", "#" + settings.checker_b.to_html(false))
	config.set_value(SECTION, "onion_past_tint", "#" + settings.onion_past_tint.to_html(false))
	config.set_value(SECTION, "onion_future_tint", "#" + settings.onion_future_tint.to_html(false))
	config.set_value(SECTION, "default_palette", settings.default_palette)
	var error: int = config.save(path)
	return "" if error == OK else "could not save settings to %s (error %d)" % [path, error]


func _string(config: ConfigFile, key: String, fallback: String) -> String:
	var value: Variant = config.get_value(SECTION, key, fallback)
	return value if value is String else fallback


func _float(config: ConfigFile, key: String, fallback: float) -> float:
	var value: Variant = config.get_value(SECTION, key, fallback)
	return value if (value is float or value is int) else fallback


func _color(config: ConfigFile, key: String, fallback: Color) -> Color:
	var text: String = _string(config, key, "")
	var hex: String = text.trim_prefix("#")
	return Color.html(hex) if hex.length() == 6 and hex.is_valid_hex_number() else fallback
