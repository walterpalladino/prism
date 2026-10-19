## Editor actions and their default keys (GDD §8.3). The defaults are written into
## project.godot's InputMap; the UI dispatches by action name. Ctrl means Cmd on macOS.
##
## After editing DEFAULTS, regenerate project.godot's [input] section with a SceneTree script that,
## for each action, calls ProjectSettings.set_setting("input/<action>", {"deadzone": 0.2,
## "events": Shortcuts.events_for(action)}) and then ProjectSettings.save().
## shortcuts_test.gd fails if the two drift apart.
class_name Shortcuts
extends RefCounted

const SHIFT: int = 1
const CTRL: int = 2
const ALT: int = 4

## action name -> list of [keycode, modifier mask].
const DEFAULTS: Dictionary[StringName, Array] = {
	&"prism_tool_pencil": [[KEY_D, 0]],
	&"prism_tool_eraser": [[KEY_E, 0]],
	&"prism_tool_line": [[KEY_L, 0]],
	&"prism_tool_rect": [[KEY_R, 0]],
	&"prism_tool_rect_filled": [[KEY_R, SHIFT]],
	&"prism_tool_ellipse": [[KEY_O, 0]],
	&"prism_tool_ellipse_filled": [[KEY_O, SHIFT]],
	&"prism_tool_fill": [[KEY_F, 0]],
	&"prism_tool_fill_global": [[KEY_F, SHIFT]],
	&"prism_tool_picker": [[KEY_I, 0]],
	&"prism_tool_select": [[KEY_M, 0]],
	&"prism_tool_move": [[KEY_V, 0]],
	&"prism_tool_brush_pickup": [[KEY_B, 0]],
	&"prism_brush_restore": [[KEY_B, SHIFT]],
	&"prism_brush_flip_h": [[KEY_X, 0]],
	&"prism_brush_flip_v": [[KEY_Y, 0]],
	&"prism_brush_rotate": [[KEY_Z, 0]],
	&"prism_fg_prev": [[KEY_BRACKETLEFT, 0]],
	&"prism_fg_next": [[KEY_BRACKETRIGHT, 0]],
	&"prism_bg_prev": [[KEY_BRACKETLEFT, SHIFT]],
	&"prism_bg_next": [[KEY_BRACKETRIGHT, SHIFT]],
	&"prism_zoom_in": [[KEY_EQUAL, 0], [KEY_EQUAL, SHIFT], [KEY_KP_ADD, 0]],
	&"prism_zoom_out": [[KEY_MINUS, 0], [KEY_KP_SUBTRACT, 0]],
	&"prism_zoom_reset": [[KEY_1, 0]],
	&"prism_toggle_grid": [[KEY_G, 0]],
	&"prism_open": [[KEY_O, CTRL]],
	&"prism_save": [[KEY_S, CTRL]],
	&"prism_save_as": [[KEY_S, CTRL | SHIFT]],
	&"prism_undo": [[KEY_Z, CTRL]],
	&"prism_redo": [[KEY_Z, CTRL | SHIFT], [KEY_Y, CTRL]],
	&"prism_select_all": [[KEY_A, CTRL]],
	&"prism_copy": [[KEY_C, CTRL]],
	&"prism_cut": [[KEY_X, CTRL]],
	&"prism_paste": [[KEY_V, CTRL]],
	&"prism_cancel": [[KEY_ESCAPE, 0]],
	&"prism_toggle_timeline": [[KEY_T, CTRL]],
	&"prism_toggle_stencil": [[KEY_QUOTELEFT, SHIFT], [KEY_ASCIITILDE, 0], [KEY_ASCIITILDE, SHIFT]],
	&"prism_toggle_onion": [[KEY_F3, 0]],
	&"prism_toggle_cycling": [[KEY_TAB, 0]],
	&"prism_frame_prev": [[KEY_COMMA, 0]],
	&"prism_frame_next": [[KEY_PERIOD, 0]],
	&"prism_play": [[KEY_ENTER, 0], [KEY_KP_ENTER, 0]],
	&"prism_frame_new": [[KEY_N, ALT]],
	&"prism_frame_duplicate": [[KEY_D, ALT]],
	&"prism_nudge_left": [[KEY_LEFT, 0]],
	&"prism_nudge_right": [[KEY_RIGHT, 0]],
	&"prism_nudge_up": [[KEY_UP, 0]],
	&"prism_nudge_down": [[KEY_DOWN, 0]],
}

## The "classic" preset (DPaint heritage) overrides these on top of DEFAULTS. It resolves the
## `.` conflict of GDD §8.3 the DPaint way: `.` restores the brush and frames move with 1 / 2.
const CLASSIC: Dictionary[StringName, Array] = {
	&"prism_brush_restore": [[KEY_PERIOD, 0], [KEY_KP_PERIOD, 0]],
	&"prism_frame_prev": [[KEY_1, 0]],
	&"prism_frame_next": [[KEY_2, 0]],
	&"prism_zoom_reset": [[KEY_0, 0]],
	&"prism_tool_line": [[KEY_V, 0]],
	&"prism_tool_move": [[KEY_V, SHIFT]],
}

## Actions that repeat while the key is held.
const REPEATING: Array[StringName] = [
	&"prism_fg_prev", &"prism_fg_next", &"prism_bg_prev", &"prism_bg_next",
	&"prism_nudge_left", &"prism_nudge_right", &"prism_nudge_up", &"prism_nudge_down",
	&"prism_undo", &"prism_redo", &"prism_frame_prev", &"prism_frame_next",
]


## Builds the InputEventKey for one default binding.
static func make_event(keycode: Key, mods: int) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.device = -1  # all devices
	event.keycode = keycode
	event.shift_pressed = (mods & SHIFT) != 0
	event.alt_pressed = (mods & ALT) != 0
	if (mods & CTRL) != 0:
		event.command_or_control_autoremap = true
	return event


## Every action's bindings for a preset ("modern" = DEFAULTS, "classic" = DEFAULTS + CLASSIC).
static func preset(preset_name: String) -> Dictionary[StringName, Array]:
	var bindings: Dictionary[StringName, Array] = DEFAULTS.duplicate()
	if preset_name == "classic":
		bindings.merge(CLASSIC, true)
	return bindings


## Human-readable binding, e.g. "Ctrl+Shift+Z" (Ctrl means Cmd on macOS).
static func describe(binding: Array) -> String:
	var keycode: Key = binding[0]
	var mods: int = binding[1]
	var parts: PackedStringArray = PackedStringArray()
	if mods & CTRL:
		parts.append_array(["Cmd" if OS.has_feature("macos") else "Ctrl"])
	if mods & ALT:
		parts.append_array(["Alt"])
	if mods & SHIFT:
		parts.append_array(["Shift"])
	parts.append_array([OS.get_keycode_string(keycode)])
	return "+".join(parts)


## Parses "Ctrl+Shift+Z" style text into [keycode, mods]; an empty array if it is not valid.
static func parse(text: String) -> Array:
	var parts: PackedStringArray = text.split("+", false)
	if parts.is_empty():
		return []
	var mods: int = 0
	for i: int in parts.size() - 1:
		match parts[i].strip_edges().to_lower():
			"ctrl", "cmd", "command":
				mods |= CTRL
			"shift":
				mods |= SHIFT
			"alt", "option":
				mods |= ALT
			_:
				return []
	var keycode: Key = OS.find_keycode_from_string(parts[parts.size() - 1].strip_edges())
	if keycode == KEY_NONE:
		return []
	return [keycode, mods]


static func events_for(action: StringName, bindings: Dictionary[StringName, Array] = DEFAULTS) -> Array[InputEventKey]:
	var events: Array[InputEventKey] = []
	for binding: Array in bindings[action]:
		var keycode: Key = binding[0]
		var mods: int = binding[1]
		events.append(make_event(keycode, mods))
	return events
