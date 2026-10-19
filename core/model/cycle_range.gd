class_name CycleRange
extends RefCounted

var start_index: int   # inclusive
var end_index: int     # inclusive
var rate_hz: float     # steps per second
var step: int = 1      # +1 forward, -1 reverse
var active: bool = true


func _init(p_start: int, p_end: int, p_rate_hz: float, p_step: int = 1) -> void:
	start_index = p_start
	end_index = p_end
	rate_hz = p_rate_hz
	step = p_step


func length() -> int:
	return end_index - start_index + 1


func overlaps(other: CycleRange) -> bool:
	return start_index <= other.end_index and other.start_index <= end_index
