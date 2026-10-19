## Shade: steps the destination one index along the ramp that contains it.
## Primary button = +1 (lighter), secondary = -1. Pixels outside any ramp are untouched.
class_name ShadeInk
extends Ink


func apply(dest: int, _brush_value: int, _brush_is_mask: bool, ctx: InkContext) -> int:
	var ramp: Vector2i = ctx.palette.find_ramp(dest)
	if ramp == Palette.NO_RAMP:
		return SKIP
	var next: int = dest + ctx.direction()
	if next > ramp.y:
		next = ramp.x if ctx.shade_wrap else ramp.y
	elif next < ramp.x:
		next = ramp.y if ctx.shade_wrap else ramp.x
	return SKIP if next == dest else next
