## Key binding overrides in user://keybindings.json (GDD §7.13), applied to the InputMap at
## startup on top of the chosen preset. Format: {"prism_tool_line": ["V", "Shift+L"], ...}.
## Unknown actions or unreadable keys are reported and skipped, never fatal.
class_name KeybindingStore
extends RefCounted

const DEFAULT_PATH: String = "user://keybindings.json"

var path: String
var errors: PackedStringArray = PackedStringArray()


func _init(p_path: String = DEFAULT_PATH) -> void:
	path = p_path


## Overrides from the file (empty if it does not exist).
func load_overrides() -> Dictionary[StringName, Array]:
	errors.clear()
	var overrides: Dictionary[StringName, Array] = {}
	if not FileAccess.file_exists(path):
		return overrides
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		errors.append_array(["%s is not a JSON object" % path.get_file()])
		return overrides
	var data: Dictionary = parsed
	for key: Variant in data:
		var action: StringName = StringName(str(key))
		if not Shortcuts.DEFAULTS.has(action):
			errors.append_array(["unknown action '%s'" % action])
			continue
		var list: Variant = data[key]
		if not (list is Array):
			errors.append_array(["'%s' must be a list of keys" % action])
			continue
		var bindings: Array = []
		var keys: Array = list
		for entry: Variant in keys:
			var binding: Array = Shortcuts.parse(str(entry))
			if binding.is_empty():
				errors.append_array(["'%s': cannot read key '%s'" % [action, entry]])
			else:
				bindings.append(binding)
		overrides[action] = bindings
	return overrides


## Writes `bindings` (all actions) as an editable template. Returns "" or an error message.
func save_bindings(bindings: Dictionary[StringName, Array]) -> String:
	var data: Dictionary = {}
	var actions: Array[StringName] = bindings.keys()
	actions.sort()
	for action: StringName in actions:
		var keys: Array = []
		for binding: Array in bindings[action]:
			keys.append(Shortcuts.describe(binding).replace("Cmd", "Ctrl"))
		data[String(action)] = keys
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "could not write %s" % path
	var stored: bool = file.store_string(JSON.stringify(data, "  "))
	file.close()
	return "" if stored else "could not write %s" % path


## Replaces the InputMap events of every action in `bindings`.
static func apply(bindings: Dictionary[StringName, Array]) -> void:
	for action: StringName in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for event: InputEventKey in Shortcuts.events_for(action, bindings):
			InputMap.action_add_event(action, event)
