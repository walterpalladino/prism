## Color: the brush shape is painted in the solid FG/BG index; custom brushes act as masks.
class_name ColorInk
extends Ink


func apply(_dest: int, _brush_value: int, _brush_is_mask: bool, ctx: InkContext) -> int:
	return ctx.paint_index()
