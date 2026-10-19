## Replaces the palette colors and ramps (palette load, presets). Pixel indices are unchanged.
class_name ReplacePaletteCommand
extends Command

var before: Palette
var after: Palette
var label: String


func _init(p_before: Palette, p_after: Palette, p_label: String = "Load Palette") -> void:
	before = p_before.duplicate_palette()
	after = p_after.duplicate_palette()
	label = p_label


func get_label() -> String:
	return label


func apply(doc: PrismDocument) -> void:
	_assign(doc, after)


func revert(doc: PrismDocument) -> void:
	_assign(doc, before)


func get_byte_size() -> int:
	return (before.size() + after.size()) * 16


func changes_palette() -> bool:
	return true


static func _assign(doc: PrismDocument, source: Palette) -> void:
	doc.palette.colors = source.colors.duplicate()
	doc.palette.ramps = source.ramps.duplicate()
