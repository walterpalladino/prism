## Inserts a palette entry at `index` (GDD §7.4). Entries from `index` up move one place, and
## pixels, the transparent index, stencil, ramps and cycles follow them; a ramp or cycle the new
## entry lands inside grows by one.
class_name InsertPaletteColorCommand
extends PaletteResizeCommand

var index: int
var color: Color


func _init(p_index: int, p_color: Color) -> void:
	index = p_index
	color = Palette.quantize(p_color)


func get_label() -> String:
	return "Add Color %d" % index


func apply(doc: PrismDocument) -> void:
	assert(doc.palette.size() < Palette.MAX_COLORS and index >= 0 and index <= doc.palette.size())
	_save(doc)
	var table: PackedByteArray = shift_table(index, 1)
	_remap_pixels(doc, table)
	var inserted: int = doc.palette.colors.insert(index, color)
	assert(inserted == OK)
	_shift_references(doc, index, 1, table)


func revert(doc: PrismDocument) -> void:
	_remap_pixels(doc, shift_table(index, -1))
	_restore(doc)
