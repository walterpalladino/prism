## A drawing mode (GDD §7.3): maps a destination index and a brush index to a new index.
@abstract
class_name Ink
extends RefCounted

const SKIP: int = -1


## Returns the new destination index, or SKIP to leave the pixel unchanged.
## Callers never pass transparent brush pixels and enforce the stencil themselves.
@abstract func apply(dest: int, brush_value: int, brush_is_mask: bool, ctx: InkContext) -> int


static func for_mode(mode: PrismEnums.DrawMode) -> Ink:
	match mode:
		PrismEnums.DrawMode.COLOR:
			return ColorInk.new()
		PrismEnums.DrawMode.REPLACE:
			return ReplaceInk.new()
		PrismEnums.DrawMode.SHADE:
			return ShadeInk.new()
	assert(false, "Draw mode %d is not implemented yet (P1)" % mode)
	return ColorInk.new()
