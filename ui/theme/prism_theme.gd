## PRISM dark theme (GDD §8.2): deep slate background, panel slate, Workbench blue for
## selection/past and orange for active/future. Built in code so values stay reviewable.
class_name PrismTheme
extends RefCounted

const BG: Color = Color("#1b1c23")
const PANEL: Color = Color("#262833")
const PANEL_2: Color = Color("#2f3240")
const BORDER: Color = Color("#3c4052")
const TEXT: Color = Color("#c9cbd6")
const DIM: Color = Color("#7d8197")
const BLUE: Color = Color("#3d7bff")
const ORANGE: Color = Color("#ff8a3d")
const FONT_SIZE: int = 13


static func build_dark() -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font_size = FONT_SIZE
	for type: String in ["Label", "Button", "CheckBox", "OptionButton", "MenuBar", "PopupMenu", "SpinBox", "LineEdit"]:
		theme.set_color("font_color", type, TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", BG)
	theme.set_color("font_hover_pressed_color", "Button", BG)
	theme.set_color("font_disabled_color", "PopupMenu", DIM)
	theme.set_stylebox("panel", "PanelContainer", _box(PANEL, BORDER, 0))
	theme.set_stylebox("panel", "Panel", _box(PANEL, BORDER, 0))
	theme.set_stylebox("panel", "PopupMenu", _box(PANEL_2, BORDER, 1))
	theme.set_stylebox("panel", "Window", _box(PANEL, BORDER, 1))
	theme.set_stylebox("normal", "Button", _box(PANEL_2, BORDER, 1, 3))
	theme.set_stylebox("hover", "Button", _box(BORDER, BLUE, 1, 3))
	theme.set_stylebox("pressed", "Button", _box(ORANGE, ORANGE, 1, 3))
	theme.set_stylebox("hover_pressed", "Button", _box(ORANGE, Color.WHITE, 1, 3))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_stylebox("normal", "OptionButton", _box(PANEL_2, BORDER, 1, 3))
	theme.set_stylebox("hover", "OptionButton", _box(BORDER, BLUE, 1, 3))
	theme.set_stylebox("pressed", "OptionButton", _box(PANEL_2, BLUE, 1, 3))
	theme.set_stylebox("normal", "LineEdit", _box(BG, BORDER, 1, 3))
	for state_name: String in ["normal", "pressed", "hover_pressed", "focus"]:
		theme.set_stylebox(state_name, "CheckBox", StyleBoxEmpty.new())
	theme.set_stylebox("hover", "CheckBox", _box(PANEL_2, PANEL_2, 0, 3))
	theme.set_color("font_pressed_color", "CheckBox", TEXT)
	theme.set_color("font_hover_pressed_color", "CheckBox", Color.WHITE)
	theme.set_stylebox("hover", "PopupMenu", _box(BLUE, BLUE, 0, 2))
	return theme


static func _box(fill: Color, border: Color, border_width: int, radius: int = 0) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	return box
