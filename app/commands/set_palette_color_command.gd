## Changes one palette entry's color.
class_name SetPaletteColorCommand
extends Command

var index: int
var before: Color
var after: Color


func _init(p_index: int, p_before: Color, p_after: Color) -> void:
	index = p_index
	before = p_before
	after = p_after


func get_label() -> String:
	return "Edit Color %d" % index


func apply(doc: PrismDocument) -> void:
	doc.palette.set_color(index, after)


func revert(doc: PrismDocument) -> void:
	doc.palette.set_color(index, before)


func get_byte_size() -> int:
	return 48


func changes_palette() -> bool:
	return true
