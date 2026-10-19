## Replaces the document's color-cycle ranges (add, edit, delete, toggle).
class_name SetCyclesCommand
extends Command

var before: Array[CycleRange] = []
var after: Array[CycleRange] = []
var label: String


func _init(p_before: Array[CycleRange], p_after: Array[CycleRange], p_label: String) -> void:
	before = _copy(p_before)
	after = _copy(p_after)
	label = p_label


func get_label() -> String:
	return label


func apply(doc: PrismDocument) -> void:
	doc.cycles = _copy(after)


func revert(doc: PrismDocument) -> void:
	doc.cycles = _copy(before)


func get_byte_size() -> int:
	return 32 * (before.size() + after.size())


func changes_palette() -> bool:
	return true


static func _copy(cycles: Array[CycleRange]) -> Array[CycleRange]:
	var copies: Array[CycleRange] = []
	for cycle: CycleRange in cycles:
		copies.append(cycle.duplicate_cycle())
	return copies
