## Built-in palettes (GDD §7.4).
class_name PalettePresets
extends RefCounted

## The 32-color PRISM project palette shown in concept art C1.
const DEFAULT_32: PackedStringArray = [
	"#000000", "#1a1430", "#3b2d5c", "#5b4b8a", "#8a7bc4", "#c4b8f0", "#ffffff", "#7d8197",
	"#2c7a4b", "#4fc35a", "#a6f08a", "#e8ffd0", "#7a2c2c", "#c34f4f", "#f08a8a", "#ffd0d0",
	"#0a2a5c", "#1650a0", "#2f86e0", "#6ec0ff", "#a8e0ff", "#e0f6ff", "#5c3a0a", "#a0661a",
	"#e0a040", "#ffd080", "#fff0c0", "#ff8a3d", "#ff5ea8", "#ffe14a", "#3dffd0", "#202020",
]
const DEFAULT_32_RAMPS: Array[Vector2i] = [
	Vector2i(1, 6), Vector2i(8, 11), Vector2i(12, 15), Vector2i(16, 21), Vector2i(22, 26),
]

## The widely published PICO-8 16-color palette values.
const PICO8_STYLE_16: PackedStringArray = [
	"#000000", "#1d2b53", "#7e2553", "#008751", "#ab5236", "#5f574f", "#c2c3c7", "#fff1e8",
	"#ff004d", "#ffa300", "#ffec27", "#00e436", "#29adff", "#83769c", "#ff77a8", "#ffccaa",
]

## Standard IBM EGA 16-color default palette.
const EGA_16: PackedStringArray = [
	"#000000", "#0000aa", "#00aa00", "#00aaaa", "#aa0000", "#aa00aa", "#aa5500", "#aaaaaa",
	"#555555", "#5555ff", "#55ff55", "#55ffff", "#ff5555", "#ff55ff", "#ffff55", "#ffffff",
]


static func default_32() -> Palette:
	var palette: Palette = Palette.from_hex(DEFAULT_32)
	for ramp: Vector2i in DEFAULT_32_RAMPS:
		var added: bool = palette.add_ramp(ramp.x, ramp.y)
		assert(added)
	return palette


static func pico8_style_16() -> Palette:
	return Palette.from_hex(PICO8_STYLE_16)


static func ega_16() -> Palette:
	return Palette.from_hex(EGA_16)


## `count` evenly spaced grays from black to white, as one ramp.
static func grayscale(count: int = 16) -> Palette:
	assert(count >= 2 and count <= Palette.MAX_COLORS)
	return gradient(count, Color.BLACK, Color.WHITE)


## Built-in presets as [id, display name] rows, for menus and the default-palette preference.
const PRESETS: Array[Array] = [
	["prism32", "PRISM 32"], ["pico8", "PICO-8 style 16"], ["ega16", "EGA 16"], ["gray16", "Grayscale 16"],
]
const DEFAULT_ID: String = "prism32"


static func has_preset(id: String) -> bool:
	return preset_index(id) != -1


## Row of `id` in PRESETS, or -1.
static func preset_index(id: String) -> int:
	for i: int in PRESETS.size():
		if PRESETS[i][0] == id:
			return i
	return -1


## The preset named by `id`; PRISM 32 for an unknown id.
static func by_id(id: String) -> Palette:
	match id:
		"pico8":
			return pico8_style_16()
		"ega16":
			return ega_16()
		"gray16":
			return grayscale(16)
	return default_32()


## `count` (1–256) entries of `color` ("New palette…" with blank entries).
static func blank(count: int, color: Color = Color.BLACK) -> Palette:
	assert(count >= 1 and count <= Palette.MAX_COLORS)
	var colors: PackedColorArray = PackedColorArray()
	var resize_error: int = colors.resize(count)
	assert(resize_error == OK)
	colors.fill(color)
	return Palette.new(colors)


## `count` (1–256) entries blending evenly from `from` to `to`; two or more form one ramp.
static func gradient(count: int, from: Color, to: Color) -> Palette:
	assert(count >= 1 and count <= Palette.MAX_COLORS)
	var colors: PackedColorArray = PackedColorArray()
	var resize_error: int = colors.resize(count)
	assert(resize_error == OK)
	for i: int in count:
		colors[i] = from.lerp(to, float(i) / float(maxi(count - 1, 1)))
	var palette: Palette = Palette.new(colors)
	if count >= 2:
		var added: bool = palette.add_ramp(0, count - 1)
		assert(added)
	return palette
