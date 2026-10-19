class_name Layer
extends RefCounted

var id: StringName
var layer_name: String
var visible: bool = true
var locked: bool = false
## Display opacity 0-255 (display-only in indexed mode).
var opacity: int = 255


func _init(p_id: StringName, p_name: String) -> void:
	id = p_id
	layer_name = p_name


func duplicate_layer(p_id: StringName) -> Layer:
	var copy: Layer = Layer.new(p_id, layer_name)
	copy.visible = visible
	copy.locked = locked
	copy.opacity = opacity
	return copy
