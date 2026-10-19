## Moves one palette entry to another position (GDD §7.4).
##
## With remap, every pixel, the transparent index and the stencil follow their color, so the
## picture looks the same. Without remap, pixels keep their indices and so change color.
class_name ReorderPaletteCommand
extends Command

var from_index: int
var to_index: int
var remap: bool


func _init(p_from: int, p_to: int, p_remap: bool) -> void:
	from_index = p_from
	to_index = p_to
	remap = p_remap


## new_index_of[old] for moving `from` to `to` in a palette of `size` entries.
static func permutation(size: int, from: int, to: int) -> PackedByteArray:
	var order: Array[int] = []
	for i: int in size:
		order.append(i)
	order.remove_at(from)
	var inserted: int = order.insert(to, from)
	assert(inserted == OK)
	var new_index_of: PackedByteArray = PackedByteArray()
	var resize_error: int = new_index_of.resize(256)
	assert(resize_error == OK)
	for i: int in 256:
		new_index_of[i] = i
	for new_index: int in order.size():
		new_index_of[order[new_index]] = new_index
	return new_index_of


func get_label() -> String:
	return "Reorder Palette" if remap else "Reorder Palette (no remap)"


func apply(doc: PrismDocument) -> void:
	_move(doc, from_index, to_index)


func revert(doc: PrismDocument) -> void:
	_move(doc, to_index, from_index)


func get_byte_size() -> int:
	return 64


func changes_palette() -> bool:
	return true


func _move(doc: PrismDocument, from: int, to: int) -> void:
	var colors: PackedColorArray = doc.palette.colors
	var moved: Color = colors[from]
	colors.remove_at(from)
	var inserted: int = colors.insert(to, moved)
	assert(inserted == OK)
	if not remap:
		return
	var new_index_of: PackedByteArray = permutation(colors.size(), from, to)
	for image: IndexedImage in doc.images.values():
		var px: PackedByteArray = image.pixels
		for i: int in px.size():
			px[i] = new_index_of[px[i]]
	doc.transparent_index = new_index_of[doc.transparent_index]
	var locked: PackedByteArray = doc.stencil.locked.duplicate()
	for i: int in locked.size():
		doc.stencil.locked[new_index_of[i]] = locked[i]
