## A reversible document mutation (GDD §7.11, §9.5). Commands are plain data so they can be
## unit-tested and memory-bounded; Godot's UndoRedo is not used.
@abstract
class_name Command
extends RefCounted


@abstract func get_label() -> String
@abstract func apply(doc: PrismDocument) -> void
@abstract func revert(doc: PrismDocument) -> void
@abstract func get_byte_size() -> int


## Image whose pixels this command changes, or &"" for structural changes.
func get_image_id() -> StringName:
	return &""


## Changed area in image space; an empty rect means "refresh everything".
func get_dirty_rect() -> Rect2i:
	return Rect2i()
