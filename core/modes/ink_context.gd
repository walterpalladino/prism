## Per-stroke inputs shared by all inks.
class_name InkContext
extends RefCounted

var fg: int
var bg: int
var button: PrismEnums.PaintButton
var palette: Palette
## Shade mode at a ramp end: false clamps (default, GDD Q1), true wraps.
var shade_wrap: bool = false


func _init(p_fg: int, p_bg: int, p_button: PrismEnums.PaintButton, p_palette: Palette) -> void:
	fg = p_fg
	bg = p_bg
	button = p_button
	palette = p_palette


## FG for the primary button, BG for the secondary (DPaint heritage).
func paint_index() -> int:
	return fg if button == PrismEnums.PaintButton.PRIMARY else bg


## +1 for the primary button, -1 for the secondary.
func direction() -> int:
	return 1 if button == PrismEnums.PaintButton.PRIMARY else -1
