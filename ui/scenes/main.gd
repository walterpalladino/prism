## Main editor window (GDD §8.1, concept C1): menu bar, canvas, toolbox, side panel,
## timeline dock and status bar. Reads services from the EditorContext autoload and
## turns menu items and shortcuts into service calls. Never mutates the document.
extends Control

const NEW_SIZES: Array[Vector2i] = [Vector2i(16, 16), Vector2i(32, 32), Vector2i(64, 64), Vector2i(128, 128), Vector2i(256, 256)]

## Menu name -> list of [label, action, icon] ("" action = separator, "-" = disabled placeholder).
const MENUS: Array[Array] = [
	["Project", [["New 16×16", "new_16", "new"], ["New 32×32", "new_32", "new"], ["New 64×64", "new_64", "new"], ["New 128×128", "new_128", "new"], ["New 256×256", "new_256", "new"], ["", "", ""], ["Open…", "prism_open", "folder"], ["Save", "prism_save", "save"], ["Save as…", "prism_save_as", "save"], ["", "", ""], ["Import PNG into cel…", "import_png", "preview"], ["New from PNG…", "new_from_png", "preview"], ["", "", ""], ["Export PNG (current frame)…", "export_png", ""], ["Export PNG sequence…", "export_sequence", ""], ["Export sprite sheet (all frames in one PNG + JSON)…", "export_sheet", ""], ["Export Godot SpriteFrames…", "export_sprite_frames", ""], ["Export GIF…", "export_gif", ""], ["", "", ""], ["Open demo: Waterfall (color cycling)", "demo_waterfall", "play"], ["", "", ""], ["Load palette…", "palette_load", "folder"], ["Save palette…", "palette_save", "save"], ["", "", ""], ["Preferences…", "preferences", ""], ["", "", ""], ["Quit", "quit", "close"]]],
	["Edit", [["Undo", "prism_undo", "undo"], ["Redo", "prism_redo", "redo"], ["", "", ""], ["Cut", "prism_cut", "cut"], ["Copy", "prism_copy", "copy"], ["Paste", "prism_paste", "paste"], ["", "", ""], ["Select all", "prism_select_all", "select"], ["Deselect", "deselect", "close"]]],
	["Picture", [["Palette: PRISM 32", "preset_default", ""], ["Palette: PICO-8 style 16", "preset_pico8", ""], ["Palette: EGA 16", "preset_ega", ""], ["Palette: Grayscale 16", "preset_gray", ""], ["", "", ""], ["Invert stencil", "stencil_invert", "lock"], ["Lock all except FG", "stencil_all_but_fg", "lock"], ["Clear stencil", "stencil_clear", "unlock"], ["", "", ""], ["Clear cel", "cel_clear", "trash"]]],
	["Brush", [["Restore built-in", "prism_brush_restore", "brush"], ["Flip horizontal", "prism_brush_flip_h", "flip_h"], ["Flip vertical", "prism_brush_flip_v", "flip_v"], ["Rotate 90°", "prism_brush_rotate", "rotate"]]],
	["Mode", [["Color", "mode_color", ""], ["Replace", "mode_replace", ""], ["Shade", "mode_shade", ""]]],
	["Anim", [["Play / stop", "prism_play", "play"], ["Previous frame", "prism_frame_prev", "prev"], ["Next frame", "prism_frame_next", "next"], ["", "", ""], ["New frame", "prism_frame_new", "plus"], ["Duplicate frame", "prism_frame_duplicate", "duplicate"], ["Duplicate frame (linked)", "frame_duplicate_linked", "duplicate"], ["Delete frame", "frame_delete", "trash"], ["", "", ""], ["New layer", "layer_new", "plus"], ["Duplicate layer", "layer_duplicate", "duplicate"], ["Delete layer", "layer_delete", "trash"], ["", "", ""], ["New tag from selection", "tag_new", ""], ["", "", ""], ["Onion skin", "prism_toggle_onion", "eye"], ["Color cycling preview", "prism_toggle_cycling", "play"]]],
	["Effect", [["Flip cel horizontally", "fx_flip_h", "flip_h"], ["Flip cel vertically", "fx_flip_v", "flip_v"], ["Rotate cel 90° clockwise", "fx_rotate_cw", "rotate"], ["Rotate cel 90° counter-clockwise", "fx_rotate_ccw", "rotate_ccw"], ["", "", ""], ["Outline with FG", "fx_outline", ""], ["Replace FG with BG", "fx_replace", ""]]],
	["View", [["Zoom in", "prism_zoom_in", "zoom_in"], ["Zoom out", "prism_zoom_out", "zoom_out"], ["Zoom 1:1", "prism_zoom_reset", ""], ["Fit", "fit", ""], ["", "", ""], ["Pixel grid", "prism_toggle_grid", "grid"], ["Tile grid: off / 8 / 16 / 32", "tile_grid", "grid"], ["Timeline", "prism_toggle_timeline", "play"], ["", "", ""], ["Preview window", "preview", "preview"], ["Preview 1×", "preview_1", ""], ["Preview 2×", "preview_2", ""]]],
	["Help", [["Keyboard shortcuts…", "help_shortcuts", ""], ["Edit key bindings file…", "help_keybindings", ""], ["", "", ""], ["About PRISM…", "help_about", ""]]],
]

var canvas: CanvasView
var status_bar: StatusBar
var preview: PreviewWindow
var timeline: TimelineDock
var side_panel: SidePanel
var message: AcceptDialog

var _menu_actions: Dictionary[String, PackedStringArray] = {}


const PRISM_FILTERS: PackedStringArray = ["*.prism ; PRISM document"]
const PNG_FILTERS: PackedStringArray = ["*.png ; PNG image"]
const GIF_FILTERS: PackedStringArray = ["*.gif ; Animated GIF"]
const TRES_FILTERS: PackedStringArray = ["*.tres ; Godot SpriteFrames"]
const LAYOUTS: PackedStringArray = ["Row", "Column", "Grid", "Tight (trimmed)"]


func _ready() -> void:
	var settings: Settings = EditorContext.settings
	PrismTheme.use(settings.theme)
	theme = PrismTheme.build()
	get_window().content_scale_factor = settings.ui_scale
	get_tree().set_auto_accept_quit(false)
	var background: ColorRect = ColorRect.new()
	background.color = PrismTheme.BG
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	root.add_child(_build_menu_bar())

	var body: HBoxContainer = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	canvas = CanvasView.new()
	canvas.name = "CanvasView"
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(canvas)
	var toolbox_panel: PanelContainer = PanelContainer.new()
	var toolbox: Toolbox = Toolbox.new()
	toolbox.setup(EditorContext.tools, EditorContext.state)
	toolbox_panel.add_child(toolbox)
	body.add_child(toolbox_panel)
	side_panel = SidePanel.new()
	side_panel.setup(EditorContext.state, EditorContext.palette, EditorContext.cycling)
	body.add_child(side_panel)

	timeline = TimelineDock.new()
	timeline.name = "TimelineDock"
	timeline.setup(EditorContext.bus, EditorContext.state, EditorContext.timeline, EditorContext.playback)
	root.add_child(timeline)

	canvas.setup(EditorContext.bus, EditorContext.state, EditorContext.tools, EditorContext.textures, EditorContext.palette_texture)
	canvas.set_colors(PrismTheme.WORKSPACE, settings.checker_a, settings.checker_b)
	status_bar = StatusBar.new()
	status_bar.name = "StatusBar"
	status_bar.setup(EditorContext.state, EditorContext.tools, canvas)
	root.add_child(status_bar)

	preview = PreviewWindow.new()
	preview.setup(EditorContext.bus, EditorContext.state, EditorContext.textures, EditorContext.palette_texture, EditorContext.cycling)
	add_child(preview)
	preview.visible = false
	Signals.on(EditorContext.playback.playing_changed, canvas.set_playing)
	message = AcceptDialog.new()
	message.title = "PRISM"
	add_child(message)
	Signals.on(EditorContext.session.changed, _update_title)
	_update_title()
	if EditorContext.recovery_available:
		EditorContext.recovery_available = false
		_offer_recovery.call_deferred()


## Tab toggles color cycling (DPaint). It is caught here, before the GUI would use it to
## move keyboard focus. Text fields keep Tab for themselves.
func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"prism_toggle_cycling", false, true):
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	run_action("prism_toggle_cycling")
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Deferred: this notification is delivered while Godot walks the scene tree, and nodes
		# cannot get new children during that walk, so the "Unsaved changes" dialog would fail
		# to open and the app would stay running with nothing on screen.
		run_action.call_deferred("quit")


func _update_title() -> void:
	get_window().title = "PRISM — " + EditorContext.session.title()


func _unhandled_key_input(event: InputEvent) -> void:
	for action: StringName in Shortcuts.DEFAULTS:
		if event.is_action_pressed(action, Shortcuts.REPEATING.has(action), true):
			run_action(String(action))
			get_viewport().set_input_as_handled()
			return


## Executes a menu or shortcut action by name.
func run_action(action: String) -> void:
	var ctx: Node = EditorContext
	var state: EditorState = EditorContext.state
	var tools: ToolController = EditorContext.tools
	var bus: CommandBus = EditorContext.bus
	match action:
		"prism_tool_pencil", "prism_tool_eraser", "prism_tool_line", "prism_tool_picker", "prism_tool_select", "prism_tool_move", "prism_tool_brush_pickup":
			tools.activate(StringName(action.trim_prefix("prism_tool_")))
		"prism_tool_rect", "prism_tool_rect_filled":
			state.filled_shapes = action.ends_with("filled")
			tools.activate(&"rect")
			state.changed.emit()
		"prism_tool_ellipse", "prism_tool_ellipse_filled":
			state.filled_shapes = action.ends_with("filled")
			tools.activate(&"ellipse")
			state.changed.emit()
		"prism_tool_fill", "prism_tool_fill_global":
			state.global_fill = action.ends_with("global")
			tools.activate(&"fill")
			state.changed.emit()
		"prism_brush_restore":
			state.restore_builtin_brush()
			state.set_draw_mode(PrismEnums.DrawMode.COLOR)
		"prism_brush_flip_h":
			state.flip_brush_h()
		"prism_brush_flip_v":
			state.flip_brush_v()
		"prism_brush_rotate":
			state.rotate_brush()
		"prism_fg_prev":
			state.step_fg(-1)
		"prism_fg_next":
			state.step_fg(1)
		"prism_bg_prev":
			state.step_bg(-1)
		"prism_bg_next":
			state.step_bg(1)
		"prism_zoom_in":
			canvas.zoom_step(1, canvas.get_local_mouse_position())
		"prism_zoom_out":
			canvas.zoom_step(-1, canvas.get_local_mouse_position())
		"prism_zoom_reset":
			canvas.reset_zoom()
		"fit":
			canvas.fit()
		"prism_toggle_grid":
			canvas.set_show_grid(not canvas.show_grid)
		"prism_undo":
			if not tools.is_stroke_active():
				EditorContext.palette.commit_color()
				var _undone: bool = bus.undo()
		"prism_redo":
			if not tools.is_stroke_active():
				EditorContext.palette.commit_color()
				var _redone: bool = bus.redo()
		"prism_copy":
			var _copied: bool = EditorContext.selection.copy()
		"prism_cut":
			var _cut: bool = EditorContext.selection.cut()
		"prism_paste":
			var _pasted: bool = EditorContext.selection.paste()
		"prism_cancel":
			if tools.is_stroke_active():
				tools.cancel()
			else:
				state.set_selection(Rect2i())
		"deselect":
			state.set_selection(Rect2i())
		"prism_nudge_left":
			var _l: bool = EditorContext.selection.nudge(Vector2i.LEFT)
		"prism_nudge_right":
			var _r: bool = EditorContext.selection.nudge(Vector2i.RIGHT)
		"prism_nudge_up":
			var _u: bool = EditorContext.selection.nudge(Vector2i.UP)
		"prism_nudge_down":
			var _d: bool = EditorContext.selection.nudge(Vector2i.DOWN)
		"tile_grid":
			var next_tile: int = 0 if canvas.tile_grid >= 32 else maxi(8, canvas.tile_grid * 2)
			canvas.set_tile_grid(next_tile)
		"prism_frame_prev":
			EditorContext.playback.stop()
			EditorContext.timeline.previous_frame()
		"prism_frame_next":
			EditorContext.playback.stop()
			EditorContext.timeline.next_frame()
		"prism_play":
			EditorContext.playback.toggle(state.frame_index)
		"prism_frame_new":
			EditorContext.timeline.insert_frame(state.frame_index + 1)
		"prism_frame_duplicate":
			EditorContext.timeline.duplicate_frame(state.frame_index, false)
		"frame_duplicate_linked":
			EditorContext.timeline.duplicate_frame(state.frame_index, true)
		"frame_delete":
			var _frame_deleted: bool = EditorContext.timeline.delete_frame(state.frame_index)
		"layer_new":
			EditorContext.timeline.add_layer()
		"layer_duplicate":
			EditorContext.timeline.duplicate_layer(state.layer_index)
		"layer_delete":
			var _layer_deleted: bool = EditorContext.timeline.delete_layer(state.layer_index)
		"tag_new":
			var _tag: int = EditorContext.timeline.add_tag(state.frame_range)
		"prism_toggle_onion":
			state.set_onion(not state.onion_enabled, state.onion_past, state.onion_future, state.onion_tag_bounded)
		"prism_toggle_cycling":
			EditorContext.cycling.toggle(&"tab")
		"demo_waterfall":
			_confirm_discard(func() -> void:
				ctx.call(&"open_document", DemoDocuments.waterfall())
				EditorContext.cycling.request(&"tab", true)
				canvas.fit())
		"prism_select_all":
			EditorContext.effects.select_all()
		"cel_clear":
			var _cleared: bool = EditorContext.timeline.clear_cel(state.layer_index, state.frame_index)
		"fx_flip_h":
			_show_result(EditorContext.effects.flip_horizontal(), "")
		"fx_flip_v":
			_show_result(EditorContext.effects.flip_vertical(), "")
		"fx_rotate_cw":
			_show_result(EditorContext.effects.rotate_90(true), "")
		"fx_rotate_ccw":
			_show_result(EditorContext.effects.rotate_90(false), "")
		"fx_outline":
			_show_result(EditorContext.effects.outline_with_fg(), "")
		"fx_replace":
			_show_result(EditorContext.effects.replace_fg_with_bg(), "")
		"preferences":
			_open_preferences()
		"help_shortcuts":
			_show_shortcuts()
		"help_keybindings":
			_open_keybindings_file()
		"help_about":
			_show_about()
		"prism_toggle_stencil":
			side_panel.toggle_stencil_section()
		"stencil_invert":
			EditorContext.palette.invert_stencil()
		"stencil_all_but_fg":
			EditorContext.palette.lock_all_except_fg()
		"stencil_clear":
			EditorContext.palette.clear_stencil()
		"preset_default":
			_load_preset(PalettePresets.default_32(), "PRISM 32")
		"preset_pico8":
			_load_preset(PalettePresets.pico8_style_16(), "PICO-8 style 16")
		"preset_ega":
			_load_preset(PalettePresets.ega_16(), "EGA 16")
		"preset_gray":
			_load_preset(PalettePresets.grayscale(16), "Grayscale 16")
		"palette_load":
			_open_palette_dialog(FileDialog.FILE_MODE_OPEN_FILE)
		"palette_save":
			_open_palette_dialog(FileDialog.FILE_MODE_SAVE_FILE)
		"prism_toggle_timeline":
			timeline.visible = not timeline.visible
		"mode_color":
			state.set_draw_mode(PrismEnums.DrawMode.COLOR)
		"mode_replace":
			state.set_draw_mode(PrismEnums.DrawMode.REPLACE)
		"mode_shade":
			state.set_draw_mode(PrismEnums.DrawMode.SHADE)
		"preview":
			preview.visible = not preview.visible
			if preview.visible:
				preview.position = Vector2i(int(size.x) - preview.size.x - 260, 60)
		"preview_1":
			preview.set_preview_scale(1)
		"preview_2":
			preview.set_preview_scale(2)
		"quit":
			_confirm_discard(func() -> void:
				EditorContext.shutdown()
				get_tree().quit())
		"prism_open":
			_confirm_discard(func() -> void: _file_dialog(FileDialog.FILE_MODE_OPEN_FILE, "Open", PRISM_FILTERS, "", _open_file))
		"prism_save":
			if EditorContext.session.path == "":
				run_action("prism_save_as")
			else:
				_show_result(EditorContext.session.save(), "")
				EditorContext.autosave.discard()
		"prism_save_as":
			_file_dialog(FileDialog.FILE_MODE_SAVE_FILE, "Save as", PRISM_FILTERS, EditorContext.session.display_name().get_basename() + ".prism", func(path: String) -> void:
				_show_result(EditorContext.session.save_as(path), "")
				EditorContext.autosave.discard())
		"import_png":
			_file_dialog(FileDialog.FILE_MODE_OPEN_FILE, "Import PNG into the current cel", PNG_FILTERS, "", func(path: String) -> void:
				_show_result(EditorContext.exports.import_png_into_cel(path), ""))
		"new_from_png":
			_confirm_discard(func() -> void: _file_dialog(FileDialog.FILE_MODE_OPEN_FILE, "New from PNG", PNG_FILTERS, "", _new_from_png))
		"export_png":
			_export_form("Export PNG", false, false, false, func(values: Dictionary) -> void:
				var scale: int = values["scale"]
				_file_dialog(FileDialog.FILE_MODE_SAVE_FILE, "Export PNG", PNG_FILTERS, _export_name() + ".png", func(path: String) -> void:
					_show_result(EditorContext.exports.export_frame_png(path, scale), "Exported " + path.get_file())))
		"export_sequence":
			_export_form("Export PNG sequence", true, true, false, func(values: Dictionary) -> void:
				var options: ExportOptions = _options(values)
				_file_dialog(FileDialog.FILE_MODE_SAVE_FILE, "Export PNG sequence (frames are numbered)", PNG_FILTERS, _export_name() + ".png", func(path: String) -> void:
					_show_result(EditorContext.exports.export_png_sequence(path, options), "Exported %d frames" % options.schedule(EditorContext.bus.document).size())))
		"export_sheet":
			_export_form("Export sprite sheet", true, false, true, func(values: Dictionary) -> void:
				var options: ExportOptions = _options(values)
				_file_dialog(FileDialog.FILE_MODE_SAVE_FILE, "Export sprite sheet (+ .json)", PNG_FILTERS, _export_name() + ".png", func(path: String) -> void:
					_show_result(EditorContext.exports.export_sprite_sheet(path, options), "Exported " + path.get_basename().get_file() + ".png + .json")))
		"export_sprite_frames":
			_export_form("Export Godot SpriteFrames", false, false, false, func(values: Dictionary) -> void:
				var scale: int = values["scale"]
				_file_dialog(FileDialog.FILE_MODE_SAVE_FILE, "Export SpriteFrames into a Godot project", TRES_FILTERS, _export_name() + ".tres", func(path: String) -> void:
					_show_result(EditorContext.exports.export_sprite_frames(path, scale), "Exported " + path.get_basename().get_file() + ".tres + .png (one animation per tag)")))
		"export_gif":
			_export_form("Export GIF", true, true, false, func(values: Dictionary) -> void:
				var options: ExportOptions = _options(values)
				_file_dialog(FileDialog.FILE_MODE_SAVE_FILE, "Export GIF", GIF_FILTERS, _export_name() + ".gif", func(path: String) -> void:
					_show_result(EditorContext.exports.export_gif(path, options), "Exported " + path.get_file())))
		_:
			if action.begins_with("new_"):
				var side: int = action.trim_prefix("new_").to_int()
				_confirm_discard(func() -> void:
					ctx.call(&"new_document", Vector2i(side, side))
					canvas.fit())


# --- files -------------------------------------------------------------------

## Runs `then` right away, or after asking whether to discard unsaved changes.
func _confirm_discard(then: Callable) -> void:
	if not EditorContext.session.has_unsaved_changes():
		then.call()
		return
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "Unsaved changes"
	dialog.dialog_text = "%s has unsaved changes." % EditorContext.session.display_name()
	dialog.ok_button_text = "Discard"
	var save_button: Button = dialog.add_button("Save", true, "save")
	save_button.custom_minimum_size = Vector2(70, 0)
	add_child(dialog)
	Signals.on(dialog.confirmed, func() -> void:
		dialog.queue_free()
		then.call())
	Signals.on(dialog.canceled, dialog.queue_free)
	Signals.on(dialog.custom_action, func(_action: StringName) -> void:
		dialog.queue_free()
		_save_then(then))
	dialog.popup_centered()


## Saves (asking for a path if needed), then runs `then` if the save worked.
func _save_then(then: Callable) -> void:
	var session: DocumentSession = EditorContext.session
	if session.path != "":
		if _report(session.save(), ""):
			then.call()
		return
	_file_dialog(FileDialog.FILE_MODE_SAVE_FILE, "Save as", PRISM_FILTERS, "untitled.prism", func(path: String) -> void:
		if _report(session.save_as(path), ""):
			then.call())


func _open_file(path: String) -> void:
	if _report(EditorContext.open_file(path), ""):
		canvas.fit()


func _new_from_png(path: String) -> void:
	var result: DocumentResult = EditorContext.exports.document_from_png(path)
	if not result.is_ok():
		show_message(result.error)
		return
	EditorContext.call(&"open_document", result.document)
	canvas.fit()


func _offer_recovery() -> void:
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "Recover unsaved work?"
	dialog.dialog_text = "PRISM did not close properly last time.\nOpen the autosaved document?"
	dialog.ok_button_text = "Recover"
	dialog.cancel_button_text = "Discard"
	add_child(dialog)
	Signals.on(dialog.confirmed, func() -> void:
		dialog.queue_free()
		var result: DocumentResult = EditorContext.autosave.load_recovered()
		if result.is_ok():
			EditorContext.session.open_recovered(result.document)
			canvas.fit()
		else:
			show_message("The autosave could not be read:\n" + result.error))
	Signals.on(dialog.canceled, func() -> void:
		dialog.queue_free()
		EditorContext.autosave.discard())
	dialog.popup_centered()


func _show_result(error: String, success: String) -> void:
	var _ok: bool = _report(error, success)


## Shows `error` if there is one, else `success` (if not empty). Returns true on success.
func _report(error: String, success: String) -> bool:
	if error != "":
		show_message(error)
		return false
	if success != "":
		show_message(success)
	return true


func _export_name() -> String:
	return EditorContext.session.display_name().get_basename().to_snake_case()


func _file_dialog(mode: FileDialog.FileMode, title_text: String, filters: PackedStringArray, file_name: String, on_selected: Callable) -> void:
	var dialog: FileDialog = FileDialog.new()
	dialog.use_native_dialog = true
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = mode
	dialog.filters = filters
	dialog.title = title_text
	if file_name != "":
		dialog.current_file = file_name
	if EditorContext.session.path != "":
		dialog.current_dir = EditorContext.session.path.get_base_dir()
	add_child(dialog)
	Signals.on(dialog.file_selected, func(path: String) -> void:
		dialog.queue_free()
		on_selected.call(path))
	Signals.on(dialog.canceled, dialog.queue_free)
	dialog.popup_centered_ratio(0.6)


## Asks for export options, then calls `then` with the form values.
func _export_form(title_text: String, with_scope: bool, with_bake: bool, with_layout: bool, then: Callable) -> void:
	var form: FormDialog = FormDialog.new()
	form.title = title_text
	if with_scope:
		form.add_choice("scope", "Frames", EditorContext.exports.scope_names(), 0)
	form.add_number("scale", "Scale", 1, 1, 8, "×")
	if with_layout:
		form.add_choice("layout", "Layout", LAYOUTS, ExportOptions.Layout.GRID)
		form.add_number("columns", "Columns", 0, 0, 256, "  (0 = auto)")
		form.add_number("rows", "Rows", 0, 0, 256, "  (0 = auto)")
		form.add_number("margin", "Outer margin", 0, 0, 256, " px")
		form.add_number("spacing", "Spacing", 0, 0, 256, " px between frames")
	if with_bake and not EditorContext.bus.document.cycles.is_empty():
		form.add_check("bake", "Bake color cycling", true)
	Signals.on(form.submitted, func(values: Dictionary) -> void:
		if values.get("bake", false):
			var predicted: int = EditorContext.exports.predicted_frames(_options(values))
			if predicted > FrameSchedule.DEFAULT_MAX_FRAMES:
				show_message("Baking color cycling needs %d frames; the export is capped at %d." % [predicted, FrameSchedule.DEFAULT_MAX_FRAMES])
		then.call(values))
	form.open(self)


func _options(values: Dictionary) -> ExportOptions:
	var scope: int = values.get("scope", 0)
	var options: ExportOptions = EditorContext.exports.options_for(scope)
	options.scale = values.get("scale", 1)
	var layout: int = values.get("layout", ExportOptions.Layout.GRID)
	options.layout = layout as ExportOptions.Layout
	options.columns = values.get("columns", 0)
	options.rows = values.get("rows", 0)
	options.margin = values.get("margin", 0)
	options.spacing = values.get("spacing", 0)
	options.bake_cycles = values.get("bake", false)
	return options


# --- preferences & help --------------------------------------------------------

const THEME_NAMES: PackedStringArray = ["Dark", "Light"]
const PRESET_NAMES: PackedStringArray = ["Modern (. = next frame)", "Classic DPaint (1/2 frames, . = restore brush)"]


func _open_preferences() -> void:
	var current: Settings = EditorContext.settings
	var form: FormDialog = FormDialog.new()
	form.title = "Preferences"
	form.add_choice("theme", "Theme", THEME_NAMES, Settings.THEMES.find(current.theme))
	form.add_number("ui_scale", "UI scale", roundi(current.ui_scale * 100.0), roundi(Settings.MIN_UI_SCALE * 100.0), roundi(Settings.MAX_UI_SCALE * 100.0), "%")
	form.add_number("autosave", "Autosave every", current.autosave_interval_s, 0, 3600, " s (0 = off)")
	form.add_choice("keys", "Key preset", PRESET_NAMES, Settings.KEY_PRESETS.find(current.key_preset))
	form.add_color("checker_a", "Checker 1", current.checker_a)
	form.add_color("checker_b", "Checker 2", current.checker_b)
	form.add_color("onion_past", "Onion past", current.onion_past_tint)
	form.add_color("onion_future", "Onion future", current.onion_future_tint)
	Signals.on(form.submitted, func(values: Dictionary) -> void:
		var updated: Settings = current.duplicate_settings()
		var theme_index: int = values["theme"]
		var preset_index: int = values["keys"]
		var scale_percent: int = values["ui_scale"]
		var autosave_s: int = values["autosave"]
		updated.theme = Settings.THEMES[theme_index]
		updated.key_preset = Settings.KEY_PRESETS[preset_index]
		updated.ui_scale = scale_percent / 100.0
		updated.autosave_interval_s = autosave_s
		updated.checker_a = values["checker_a"]
		updated.checker_b = values["checker_b"]
		updated.onion_past_tint = values["onion_past"]
		updated.onion_future_tint = values["onion_future"]
		var rebuild: bool = updated.theme != current.theme or updated.key_preset != current.key_preset
		_show_result(EditorContext.save_settings(updated), "")
		get_window().content_scale_factor = updated.ui_scale
		canvas.set_colors(PrismTheme.WORKSPACE, updated.checker_a, updated.checker_b)
		if rebuild:
			# Rebuild the window so every control picks up the new theme / menu shortcuts.
			# The document lives in EditorContext and is untouched.
			get_tree().reload_current_scene.call_deferred())
	form.open(self)


## Readable name for an action ("prism_tool_rect_filled" -> "Tool rect filled").
static func action_label(action: StringName) -> String:
	return String(action).trim_prefix("prism_").replace("_", " ").capitalize()


func _show_shortcuts() -> void:
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = "Keyboard shortcuts (%s)" % EditorContext.settings.key_preset
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 420)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	scroll.add_child(grid)
	var bindings: Dictionary[StringName, Array] = EditorContext.current_bindings()
	var actions: Array[StringName] = bindings.keys()
	actions.sort_custom(func(a: StringName, b: StringName) -> bool: return action_label(a) < action_label(b))
	for action: StringName in actions:
		var name_label: Label = Label.new()
		name_label.text = action_label(action)
		grid.add_child(name_label)
		var keys: PackedStringArray = PackedStringArray()
		for binding: Array in bindings[action]:
			keys.append_array([Shortcuts.describe(binding)])
		var key_label: Label = Label.new()
		key_label.text = ",  ".join(keys)
		key_label.add_theme_color_override("font_color", PrismTheme.ORANGE)
		grid.add_child(key_label)
	dialog.add_child(scroll)
	add_child(dialog)
	Signals.on(dialog.confirmed, dialog.queue_free)
	Signals.on(dialog.canceled, dialog.queue_free)
	dialog.popup_centered()


func _open_keybindings_file() -> void:
	var store: KeybindingStore = EditorContext.keybindings
	if not FileAccess.file_exists(store.path):
		var error: String = store.save_bindings(EditorContext.current_bindings())
		if error != "":
			show_message(error)
			return
	EditorContext.files.open_in_system(store.path)
	show_message("Edit the key list in keybindings.json, then restart PRISM.\nExample: \"prism_tool_line\": [\"L\", \"Shift+V\"]\n\n%s" % ProjectSettings.globalize_path(store.path))


func _show_about() -> void:
	var credits: String = FileAccess.get_file_as_string("res://CREDITS.md") if FileAccess.file_exists("res://CREDITS.md") else ""
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = "About PRISM"
	var box: VBoxContainer = VBoxContainer.new()
	var heading: Label = Label.new()
	heading.text = "PRISM %s — palette-first pixel painter with a modern animation timeline.\nDPaint's hands, Aseprite's timeline. Built with Godot %s." % [ProjectSettings.get_setting("application/config/version", ""), Engine.get_version_info()["string"]]
	box.add_child(heading)
	var text: TextEdit = TextEdit.new()
	text.text = credits
	text.editable = false
	text.custom_minimum_size = Vector2(560, 320)
	box.add_child(text)
	dialog.add_child(box)
	add_child(dialog)
	Signals.on(dialog.confirmed, dialog.queue_free)
	Signals.on(dialog.canceled, dialog.queue_free)
	dialog.popup_centered()


func _load_preset(palette: Palette, preset_name: String) -> void:
	var padded: int = EditorContext.palette.load_palette(palette, "Palette: " + preset_name)
	if padded > 0:
		show_message("The image uses more colors than %s has; %d entries were kept from the old palette." % [preset_name, padded])


func show_message(text: String) -> void:
	message.dialog_text = text
	message.popup_centered()


func _open_palette_dialog(mode: FileDialog.FileMode) -> void:
	var dialog: FileDialog = FileDialog.new()
	dialog.use_native_dialog = true
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = mode
	dialog.filters = PaletteFiles.FILTERS
	dialog.title = "Load palette" if mode == FileDialog.FILE_MODE_OPEN_FILE else "Save palette"
	if mode == FileDialog.FILE_MODE_SAVE_FILE:
		dialog.current_file = "palette.gpl"
	add_child(dialog)
	Signals.on(dialog.file_selected, func(path: String) -> void:
		_on_palette_file(path, mode)
		dialog.queue_free())
	Signals.on(dialog.canceled, dialog.queue_free)
	dialog.popup_centered_ratio(0.6)


func _on_palette_file(path: String, mode: FileDialog.FileMode) -> void:
	if mode == FileDialog.FILE_MODE_SAVE_FILE:
		var error: String = PaletteFiles.save_file(path, EditorContext.bus.document.palette)
		if error != "":
			show_message("Could not save the palette:\n" + error)
		return
	var result: PaletteResult = PaletteFiles.load_file(path)
	if not result.is_ok():
		show_message("Could not load the palette:\n" + result.error)
		return
	_load_preset(result.palette, path.get_file())


func _build_menu_bar() -> MenuBar:
	var bar: MenuBar = MenuBar.new()
	bar.prefer_global_menu = false
	for menu: Array in MENUS:
		var menu_name: String = menu[0]
		var items: Array = menu[1]
		var popup: PopupMenu = PopupMenu.new()
		popup.name = menu_name
		var actions: PackedStringArray = PackedStringArray()
		for item: Array in items:
			var label: String = item[0]
			var action: String = item[1]
			var icon_name: String = item[2]
			if action == "":
				popup.add_separator()
			elif icon_name != "":
				popup.add_icon_item(PrismIcons.get_icon(icon_name), label)
				popup.set_item_icon_modulate(popup.item_count - 1, PrismTheme.TEXT)
			else:
				popup.add_item(label)
				if action == "-":
					popup.set_item_disabled(popup.item_count - 1, true)
			# Show the key next to the item (handled by _unhandled_key_input, not the menu).
			if InputMap.has_action(StringName(action)):
				var shortcut: Shortcut = Shortcut.new()
				shortcut.events = InputMap.action_get_events(StringName(action))
				popup.set_item_shortcut(popup.item_count - 1, shortcut, false)
			actions.append_array([action])
		_menu_actions[menu_name] = actions
		Signals.on(popup.index_pressed, func(index: int) -> void: run_action(_menu_actions[menu_name][index]))
		bar.add_child(popup)
	return bar
