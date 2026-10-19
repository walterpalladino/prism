## User preferences (GDD §7.13). A plain value object: SettingsStore loads/saves it.
class_name Settings
extends RefCounted

const THEMES: PackedStringArray = ["dark", "light"]
## "modern" keeps `.` for next frame; "classic" follows DPaint (1/2 frames, `.` restores the brush).
const KEY_PRESETS: PackedStringArray = ["modern", "classic"]
const MIN_UI_SCALE: float = 0.75
const MAX_UI_SCALE: float = 2.0

var theme: String = "dark"
var ui_scale: float = 1.0
## Seconds between autosaves; 0 turns autosave off.
var autosave_interval_s: int = 60
var key_preset: String = "modern"
var checker_a: Color = Color(0.227, 0.227, 0.267)
var checker_b: Color = Color(0.267, 0.267, 0.31)
var onion_past_tint: Color = Color("#3d7bff")
var onion_future_tint: Color = Color("#ff8a3d")


func duplicate_settings() -> Settings:
	var copy: Settings = Settings.new()
	copy.theme = theme
	copy.ui_scale = ui_scale
	copy.autosave_interval_s = autosave_interval_s
	copy.key_preset = key_preset
	copy.checker_a = checker_a
	copy.checker_b = checker_b
	copy.onion_past_tint = onion_past_tint
	copy.onion_future_tint = onion_future_tint
	return copy


## Brings every value into its valid range (after loading a hand-edited file).
func sanitize() -> void:
	if not THEMES.has(theme):
		theme = THEMES[0]
	if not KEY_PRESETS.has(key_preset):
		key_preset = KEY_PRESETS[0]
	ui_scale = clampf(ui_scale, MIN_UI_SCALE, MAX_UI_SCALE)
	autosave_interval_s = clampi(autosave_interval_s, 0, 3600)
