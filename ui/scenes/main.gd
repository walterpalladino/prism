## Main editor window (GDD §8.1, concept C1): menu bar, canvas, toolbox, side panel,
## timeline dock and status bar. Reads services from the EditorContext autoload and
## turns menu items and shortcuts into service calls. Never mutates the document.
extends Control

const NEW_SIZES: Array[Vector2i] = [Vector2i(16, 16), Vector2i(32, 32), Vector2i(64, 64), Vector2i(128, 128), Vector2i(256, 256)]

## Menu name -> list of [label, action, icon] ("" action = separator, "-" = disabled placeholder).
const MENUS: Array[Array] = [
	["Project", [["New 16×16", "new_16", "new"], ["New 32×32", "new_32", "new"], ["New 64×64", "new_64", "new"], ["New 128×128", "new_128", "new"], ["New 256×256", "new_256", "new"], ["", "", ""], ["Quit", "quit", "close"]]],
	["Edit", [["Undo", "prism_undo", "undo"], ["Redo", "prism_redo", "redo"], ["", "", ""], ["Cut", "prism_cut", "cut"], ["Copy", "prism_copy", "copy"], ["Paste", "prism_paste", "paste"], ["", "", ""], ["Deselect", "deselect", "close"]]],
	["Picture", [["Coming in M3–M6", "-", ""]]],
	["Brush", [["Restore built-in", "prism_brush_restore", "brush"], ["Flip horizontal", "prism_brush_flip_h", "flip_h"], ["Flip vertical", "prism_brush_flip_v", "flip_v"], ["Rotate 90°", "prism_brush_rotate", "rotate"]]],
	["Mode", [["Color", "mode_color", ""], ["Replace", "mode_replace", ""], ["Shade", "mode_shade", ""]]],
	["Anim", [["Coming in M4–M5", "-", ""]]],
	["Effect", [["Coming later", "-", ""]]],
	["View", [["Zoom in", "prism_zoom_in", "zoom_in"], ["Zoom out", "prism_zoom_out", "zoom_out"], ["Zoom 1:1", "prism_zoom_reset", ""], ["Fit", "fit", ""], ["", "", ""], ["Pixel grid", "prism_toggle_grid", "grid"], ["Tile grid: off / 8 / 16 / 32", "tile_grid", "grid"], ["Timeline", "prism_toggle_timeline", "play"], ["", "", ""], ["Preview window", "preview", "preview"], ["Preview 1×", "preview_1", ""], ["Preview 2×", "preview_2", ""]]],
]

var canvas: CanvasView
var status_bar: StatusBar
var preview: PreviewWindow
var timeline: PanelContainer

var _menu_actions: Dictionary[String, PackedStringArray] = {}


func _ready() -> void:
	theme = PrismTheme.build_dark()
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
	var side: SidePanel = SidePanel.new()
	side.setup(EditorContext.state)
	body.add_child(side)

	timeline = PanelContainer.new()
	timeline.custom_minimum_size = Vector2(0, 110)
	var timeline_label: Label = Label.new()
	timeline_label.text = "TIMELINE — layers × frames grid arrives in M4  (Ctrl+T hides this dock)"
	timeline_label.add_theme_color_override("font_color", PrismTheme.DIM)
	timeline.add_child(timeline_label)
	root.add_child(timeline)

	canvas.setup(EditorContext.bus, EditorContext.state, EditorContext.tools, EditorContext.textures, EditorContext.palette_texture)
	status_bar = StatusBar.new()
	status_bar.name = "StatusBar"
	status_bar.setup(EditorContext.state, EditorContext.tools, canvas)
	root.add_child(status_bar)

	preview = PreviewWindow.new()
	preview.setup(EditorContext.bus, EditorContext.state, EditorContext.textures, EditorContext.palette_texture)
	add_child(preview)
	preview.visible = false
	Signals.on(EditorContext.bus.document_replaced, func() -> void: EditorContext.palette_texture.update(EditorContext.bus.document.palette))


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
				var _undone: bool = bus.undo()
		"prism_redo":
			if not tools.is_stroke_active():
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
			get_tree().quit()
		_:
			if action.begins_with("new_"):
				var side: int = action.trim_prefix("new_").to_int()
				ctx.call(&"new_document", Vector2i(side, side))
				canvas.fit()


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
			actions.append_array([action])
		_menu_actions[menu_name] = actions
		Signals.on(popup.index_pressed, func(index: int) -> void: run_action(_menu_actions[menu_name][index]))
		bar.add_child(popup)
	return bar
