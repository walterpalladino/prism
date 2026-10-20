## Removes palette entry `index` (GDD §7.4). Pixels that used it are repainted with entry
## `remap_to` (an index in the palette before removal; -1 when no pixel uses it). Entries above
## `index` move down one place, and pixels, the transparent index, stencil, ramps and cycles
## follow them. Undo puts the remapped pixels back exactly.
class_name RemovePaletteColorCommand
extends PaletteResizeCommand

var index: int
var remap_to: int
## Pixel offsets that used `index`, per image, so revert can restore them.
var _remapped: Dictionary[StringName, PackedInt32Array] = {}


func _init(p_index: int, p_remap_to: int = -1) -> void:
	index = p_index
	remap_to = p_remap_to


func get_label() -> String:
	return "Remove Color %d" % index


func apply(doc: PrismDocument) -> void:
	assert(doc.palette.size() > 1 and doc.palette.has_index(index) and doc.transparent_index != index)
	_save(doc)
	var table: PackedByteArray = shift_table(index, -1)
	table[index] = table[remap_to] if doc.palette.has_index(remap_to) else 0
	_remapped.clear()
	for image_id: StringName in doc.images:
		var px: PackedByteArray = doc.images[image_id].pixels
		var hits: PackedInt32Array = PackedInt32Array()
		for i: int in px.size():
			var v: int = px[i]
			if v == index:
				@warning_ignore("return_value_discarded")
				hits.append(i)
			px[i] = table[v]
		if not hits.is_empty():
			_remapped[image_id] = hits
	doc.palette.colors.remove_at(index)
	_shift_references(doc, index, -1, table)


func revert(doc: PrismDocument) -> void:
	_remap_pixels(doc, shift_table(index, 1))
	for image_id: StringName in _remapped:
		var px: PackedByteArray = doc.images[image_id].pixels
		for offset: int in _remapped[image_id]:
			px[offset] = index
	_restore(doc)


func get_byte_size() -> int:
	var size: int = super.get_byte_size()
	for hits: PackedInt32Array in _remapped.values():
		size += hits.size() * 4
	return size
