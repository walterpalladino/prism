class_name Frame
extends RefCounted

const DEFAULT_DURATION_MS: int = 100

var id: StringName
var duration_ms: int = DEFAULT_DURATION_MS


func _init(p_id: StringName, p_duration_ms: int = DEFAULT_DURATION_MS) -> void:
	id = p_id
	duration_ms = p_duration_ms


func duplicate_frame(p_id: StringName) -> Frame:
	return Frame.new(p_id, duration_ms)
