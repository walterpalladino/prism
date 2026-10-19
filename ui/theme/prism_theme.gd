## PRISM themes (GDD §8.2). Dark (default): deep slate background, panel slate, Workbench
## blue for selection/past and orange for active/future. Light: the same roles on pale slate.
## Built in code so values stay reviewable. Colors are static vars so custom-drawn controls
## pick up the active theme; call use() before building the UI.
class_name PrismTheme
extends RefCounted

const FONT_SIZE: int = 13
const DARK: Dictionary[String, Color] = {
	"bg": Color("#1b1c23"), "panel": Color("#262833"), "panel_2": Color("#2f3240"), "border": Color("#3c4052"),
	"text": Color("#c9cbd6"), "dim": Color("#7d8197"), "blue": Color("#3d7bff"), "orange": Color("#ff8a3d"),
	"cycle": Color("#3dffd0"), "workspace": Color("#15161c"),
}
const LIGHT: Dictionary[String, Color] = {
	"bg": Color("#e6e7ee"), "panel": Color("#f3f3f7"), "panel_2": Color("#dcdde6"), "border": Color("#b7bacb"),
	"text": Color("#22242d"), "dim": Color("#686c80"), "blue": Color("#2a63e0"), "orange": Color("#e2661a"),
	"cycle": Color("#0b9c80"), "workspace": Color("#cfd1db"),
}

static var BG: Color = DARK["bg"]
static var PANEL: Color = DARK["panel"]
static var PANEL_2: Color = DARK["panel_2"]
static var BORDER: Color = DARK["border"]
static var TEXT: Color = DARK["text"]
static var DIM: Color = DARK["dim"]
static var BLUE: Color = DARK["blue"]
static var ORANGE: Color = DARK["orange"]
## Color-cycle brackets (concept C1/C3).
static var CYCLE: Color = DARK["cycle"]
## Area around the canvas.
static var WORKSPACE: Color = DARK["workspace"]
static var is_light: bool = false


## Switches the active colors ("dark" or "light").
static func use(theme_name: String) -> void:
	is_light = theme_name == "light"
	var colors: Dictionary[String, Color] = LIGHT if is_light else DARK
	BG = colors["bg"]
	PANEL = colors["panel"]
	PANEL_2 = colors["panel_2"]
	BORDER = colors["border"]
	TEXT = colors["text"]
	DIM = colors["dim"]
	BLUE = colors["blue"]
	ORANGE = colors["orange"]
	CYCLE = colors["cycle"]
	WORKSPACE = colors["workspace"]


## The Theme resource for the active colors.
static func build() -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font_size = FONT_SIZE
	for type: String in ["Label", "Button", "CheckBox", "OptionButton", "MenuBar", "PopupMenu", "SpinBox", "LineEdit"]:
		theme.set_color("font_color", type, TEXT)
	var strong: Color = Color.BLACK if is_light else Color.WHITE
	theme.set_color("font_hover_color", "Button", strong)
	theme.set_color("font_pressed_color", "Button", Color("#1b1c23"))
	theme.set_color("font_hover_pressed_color", "Button", Color("#1b1c23"))
	theme.set_color("font_disabled_color", "PopupMenu", DIM)
	# Icons are white SVGs; buttons tint them per state.
	theme.set_color("icon_normal_color", "Button", TEXT)
	theme.set_color("icon_hover_color", "Button", strong)
	theme.set_color("icon_focus_color", "Button", TEXT)
	theme.set_color("icon_pressed_color", "Button", Color("#1b1c23"))
	theme.set_color("icon_hover_pressed_color", "Button", Color("#1b1c23"))
	theme.set_color("icon_disabled_color", "Button", DIM)
	theme.set_stylebox("panel", "PanelContainer", _box(PANEL, BORDER, 0))
	theme.set_stylebox("panel", "Panel", _box(PANEL, BORDER, 0))
	theme.set_stylebox("panel", "PopupMenu", _box(PANEL_2, BORDER, 1))
	theme.set_stylebox("panel", "Window", _box(PANEL, BORDER, 1))
	# Embedded windows (dialogs, preview): slate frame with a title bar band.
	var frame: StyleBoxFlat = _box(PANEL_2, BORDER, 1, 4)
	frame.expand_margin_top = 28
	frame.expand_margin_left = 1
	frame.expand_margin_right = 1
	frame.expand_margin_bottom = 1
	theme.set_stylebox("embedded_border", "Window", frame)
	var unfocused: StyleBoxFlat = frame.duplicate() as StyleBoxFlat
	unfocused.bg_color = PANEL
	theme.set_stylebox("embedded_unfocused_border", "Window", unfocused)
	theme.set_color("title_color", "Window", TEXT)
	theme.set_color("title_outline_modulate", "Window", Color(0, 0, 0, 0))
	theme.set_constant("title_height", "Window", 28)
	theme.set_stylebox("normal", "Button", _box(PANEL_2, BORDER, 1, 3))
	theme.set_stylebox("hover", "Button", _box(BORDER, BLUE, 1, 3))
	theme.set_stylebox("pressed", "Button", _box(ORANGE, ORANGE, 1, 3))
	theme.set_stylebox("hover_pressed", "Button", _box(ORANGE, strong, 1, 3))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_stylebox("normal", "OptionButton", _box(PANEL_2, BORDER, 1, 3))
	theme.set_stylebox("hover", "OptionButton", _box(BORDER, BLUE, 1, 3))
	theme.set_stylebox("pressed", "OptionButton", _box(PANEL_2, BLUE, 1, 3))
	theme.set_stylebox("normal", "LineEdit", _box(BG, BORDER, 1, 3))
	# Menu bar: flat items that highlight on hover/open.
	theme.set_stylebox("normal", "MenuBar", StyleBoxEmpty.new())
	theme.set_stylebox("hover", "MenuBar", _box(PANEL_2, PANEL_2, 0, 3))
	theme.set_stylebox("pressed", "MenuBar", _box(BLUE, BLUE, 0, 3))
	theme.set_stylebox("hover_pressed", "MenuBar", _box(BLUE, BLUE, 0, 3))
	theme.set_stylebox("disabled", "MenuBar", StyleBoxEmpty.new())
	theme.set_color("font_hover_color", "MenuBar", strong)
	theme.set_color("font_pressed_color", "MenuBar", Color.WHITE)
	theme.set_color("font_hover_pressed_color", "MenuBar", Color.WHITE)
	for state_name: String in ["normal", "pressed", "hover_pressed", "focus"]:
		theme.set_stylebox(state_name, "CheckBox", StyleBoxEmpty.new())
	theme.set_stylebox("hover", "CheckBox", _box(PANEL_2, PANEL_2, 0, 3))
	theme.set_color("font_pressed_color", "CheckBox", TEXT)
	theme.set_color("font_hover_pressed_color", "CheckBox", strong)
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
