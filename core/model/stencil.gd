class_name Stencil
extends RefCounted

## 256 flags, 1 = locked. A PackedByteArray lookup is faster than a Dictionary in hot loops.
var locked: PackedByteArray


func _init() -> void:
	locked = PackedByteArray()
	var resize_error: int = locked.resize(256)
	assert(resize_error == OK)


func is_locked(index: int) -> bool:
	return locked[index] == 1


func set_locked(index: int, value: bool) -> void:
	locked[index] = 1 if value else 0


func toggle(index: int) -> void:
	locked[index] = 1 - locked[index]


func clear() -> void:
	locked.fill(0)


func invert() -> void:
	for i: int in locked.size():
		locked[i] = 1 - locked[i]


func lock_all_except(index: int) -> void:
	locked.fill(1)
	locked[index] = 0


func has_any() -> bool:
	return locked.has(1)


func locked_indices() -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	for i: int in locked.size():
		if locked[i] == 1:
			@warning_ignore("return_value_discarded")
			result.append(i)
	return result


func duplicate_stencil() -> Stencil:
	var copy: Stencil = Stencil.new()
	copy.locked = locked.duplicate()
	return copy
