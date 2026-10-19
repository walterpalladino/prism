## Undo/redo stacks bounded by command count and total byte size (GDD §7.11).
class_name History
extends RefCounted

const DEFAULT_MAX_COUNT: int = 500
const DEFAULT_MAX_BYTES: int = 256 * 1024 * 1024

var max_count: int = DEFAULT_MAX_COUNT
var max_bytes: int = DEFAULT_MAX_BYTES

var _undo: Array[Command] = []
var _redo: Array[Command] = []
var _bytes: int = 0


func _init(p_max_count: int = DEFAULT_MAX_COUNT, p_max_bytes: int = DEFAULT_MAX_BYTES) -> void:
	max_count = p_max_count
	max_bytes = p_max_bytes


## Records an already-applied command. Clears the redo stack and trims the oldest entries.
func push(command: Command) -> void:
	for undone: Command in _redo:
		_bytes -= undone.get_byte_size()
	_redo.clear()
	_undo.append(command)
	_bytes += command.get_byte_size()
	while _undo.size() > 1 and (_undo.size() > max_count or _bytes > max_bytes):
		var oldest: Command = _undo.pop_front()
		_bytes -= oldest.get_byte_size()


## Reverts the latest command and returns it, or null when there is nothing to undo.
func undo(doc: PrismDocument) -> Command:
	if _undo.is_empty():
		return null
	var command: Command = _undo.pop_back()
	command.revert(doc)
	_redo.append(command)
	return command


## Re-applies the latest undone command and returns it, or null.
func redo(doc: PrismDocument) -> Command:
	if _redo.is_empty():
		return null
	var command: Command = _redo.pop_back()
	command.apply(doc)
	_undo.append(command)
	return command


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


func undo_count() -> int:
	return _undo.size()


func redo_count() -> int:
	return _redo.size()


func total_bytes() -> int:
	return _bytes


## Label of the command the next undo would revert ("" if none).
func undo_label() -> String:
	return "" if _undo.is_empty() else _undo[_undo.size() - 1].get_label()


func redo_label() -> String:
	return "" if _redo.is_empty() else _redo[_redo.size() - 1].get_label()


func clear() -> void:
	_undo.clear()
	_redo.clear()
	_bytes = 0
