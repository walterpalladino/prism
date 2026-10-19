## Replace: custom brush pixels are copied as-is. Built-in (mask) brushes paint FG/BG.
class_name ReplaceInk
extends Ink


func apply(_dest: int, brush_value: int, brush_is_mask: bool, ctx: InkContext) -> int:
	return ctx.paint_index() if brush_is_mask else brush_value
