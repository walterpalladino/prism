## The editable canvas: SubViewport + zoom/pan + checkerboard, cel stack, pixel grid,
## selection overlay and ghost brush (GDD §9.4). Translates mouse input into canvas
## pixels for ToolController; never mutates the document itself.
class_name CanvasView
extends SubViewportContainer

signal cursor_moved(pixel: Vector2i, inside: bool)
signal zoom_changed(zoom: int)

const ZOOM_LEVELS: PackedInt32Array = [1, 2, 3, 4, 5, 6, 8, 10, 12, 16, 20, 24, 32]
const GRID_MIN_ZOOM: int = 6
const WORKSPACE_COLOR: Color = Color("#15161c")
const GHOST_OPACITY: float = 0.75
const CHECKER_SHADER: Shader = preload("res://infra/render/checkerboard.gdshader")
const GRID_SHADER: Shader = preload("res://infra/render/pixel_grid.gdshader")

var zoom: int = 1
var pan: Vector2 = Vector2.ZERO
var show_grid: bool = true
## Optional tile grid size in pixels (0 = off).
var tile_grid: int = 0

var _bus: CommandBus
var _state: EditorState
var _tools: ToolController
var _cache: CelTextureCache
var _palette_texture: PaletteTexture

var _viewport: SubViewport
var _world: Node2D
var _checker: ColorRect
var _stack: CelStack
var _grid: ColorRect
var _overlay: SelectionOverlay
var _flash: StencilFlash
var _ghost: Sprite2D
var _hover: Vector2i = Vector2i(-1, -1)
var _hovering: bool = false
var _panning: bool = false
var _pan_from: Vector2
var _needs_fit: bool = true


func _init() -> void:
	stretch = true
	focus_mode = Control.FOCUS_CLICK
	_viewport = SubViewport.new()
	_viewport.handle_input_locally = false
	_viewport.snap_2d_transforms_to_pixel = true
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_viewport)
	var background: ColorRect = ColorRect.new()
	background.color = WORKSPACE_COLOR
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(background)
	_world = Node2D.new()
	_viewport.add_child(_world)
	_checker = _shaded_rect(CHECKER_SHADER)
	_world.add_child(_checker)
	_stack = CelStack.new()
	_world.add_child(_stack)
	_grid = _shaded_rect(GRID_SHADER)
	_world.add_child(_grid)
	_flash = StencilFlash.new()
	_world.add_child(_flash)
	_overlay = SelectionOverlay.new()
	_world.add_child(_overlay)
	_ghost = Sprite2D.new()
	_ghost.centered = false
	_ghost.visible = false
	_world.add_child(_ghost)
	Signals.on(mouse_exited, _on_mouse_exited)
	Signals.on(resized, _on_resized)


func setup(bus: CommandBus, state: EditorState, tools: ToolController, cache: CelTextureCache, palette_texture: PaletteTexture) -> void:
	_bus = bus
	_state = state
	_tools = tools
	_cache = cache
	_palette_texture = palette_texture
	_stack.setup(cache, palette_texture)
	Signals.on(_bus.image_changed, _on_image_changed)
	Signals.on(_bus.document_changed, _on_document_changed)
	Signals.on(_bus.document_replaced, _on_document_replaced)
	Signals.on(_bus.palette_changed, _on_palette_changed)
	Signals.on(_bus.stencil_blocked, _on_stencil_blocked)
	Signals.on(_state.changed, _on_state_changed)
	Signals.on(_tools.tool_changed, func(_id: StringName) -> void: _rebuild_ghost())
	_on_document_replaced()


func _process(_delta: float) -> void:
	if _cache != null and _cache.has_dirty():
		_cache.flush(_bus.document)


# --- view transform ----------------------------------------------------------

func get_canvas_size() -> Vector2i:
	return Vector2i(_bus.document.width, _bus.document.height)


## Canvas pixel under a point in this control's local coordinates (may be outside the canvas).
func local_to_pixel(local: Vector2) -> Vector2i:
	return Vector2i(((local - pan) / zoom).floor())


## Local coordinates of the center of canvas pixel `pixel`.
func pixel_to_local(pixel: Vector2i) -> Vector2:
	return pan + (Vector2(pixel) + Vector2(0.5, 0.5)) * zoom


## Sets an integer zoom, keeping the canvas point under `focus` (local coords) fixed.
func set_zoom(level: int, focus: Vector2) -> void:
	var clamped: int = clampi(level, ZOOM_LEVELS[0], ZOOM_LEVELS[ZOOM_LEVELS.size() - 1])
	var canvas_point: Vector2 = (focus - pan) / zoom
	zoom = clamped
	pan = (focus - canvas_point * zoom).round()
	_apply_transform()
	zoom_changed.emit(zoom)


## Steps through ZOOM_LEVELS; zooms toward the cursor when it is over the view.
func zoom_step(direction: int, focus: Vector2 = Vector2(-1, -1)) -> void:
	var index: int = ZOOM_LEVELS.find(zoom)
	if index == -1:
		index = 0
		while index < ZOOM_LEVELS.size() - 1 and ZOOM_LEVELS[index] < zoom:
			index += 1
	index = clampi(index + direction, 0, ZOOM_LEVELS.size() - 1)
	set_zoom(ZOOM_LEVELS[index], _focus_or_center(focus))


func reset_zoom() -> void:
	set_zoom(1, _focus_or_center(Vector2(-1, -1)))


## Largest zoom level at which the canvas fits in ~85% of the view, centered.
func fit() -> void:
	var canvas: Vector2 = Vector2(get_canvas_size())
	var level: int = ZOOM_LEVELS[0]
	for z: int in ZOOM_LEVELS:
		if canvas.x * z <= size.x * 0.85 and canvas.y * z <= size.y * 0.85:
			level = z
	zoom = level
	pan = ((size - canvas * zoom) / 2.0).round()
	_apply_transform()
	zoom_changed.emit(zoom)


func _focus_or_center(focus: Vector2) -> Vector2:
	if focus.x >= 0.0 and Rect2(Vector2.ZERO, size).has_point(focus):
		return focus
	return size / 2.0


func _apply_transform() -> void:
	_world.position = pan
	_world.scale = Vector2(zoom, zoom)
	_overlay.zoom = zoom
	var checker_material: ShaderMaterial = _checker.material as ShaderMaterial
	checker_material.set_shader_parameter("zoom", float(zoom))
	var grid_material: ShaderMaterial = _grid.material as ShaderMaterial
	grid_material.set_shader_parameter("zoom", float(zoom))
	grid_material.set_shader_parameter("tile", float(tile_grid))
	grid_material.set_shader_parameter("pixel_grid", zoom >= GRID_MIN_ZOOM)
	_grid.visible = show_grid and (zoom >= GRID_MIN_ZOOM or tile_grid > 0)


func set_show_grid(value: bool) -> void:
	show_grid = value
	_apply_transform()


## Tile grid every `pixels` canvas pixels (0 turns it off).
func set_tile_grid(pixels: int) -> void:
	tile_grid = maxi(0, pixels)
	_apply_transform()


# --- input -------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var button_event: InputEventMouseButton = event as InputEventMouseButton
	if button_event != null:
		_handle_button(button_event)
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		_handle_motion(motion)
		return
	var pan_gesture: InputEventPanGesture = event as InputEventPanGesture
	if pan_gesture != null:
		pan -= pan_gesture.delta * 8.0
		_apply_transform()
		accept_event()
		return
	var magnify: InputEventMagnifyGesture = event as InputEventMagnifyGesture
	if magnify != null and absf(magnify.factor - 1.0) > 0.02:
		zoom_step(1 if magnify.factor > 1.0 else -1, magnify.position)
		accept_event()


func _handle_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				zoom_step(1, event.position)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				zoom_step(-1, event.position)
		MOUSE_BUTTON_MIDDLE:
			_set_panning(event.pressed, event.position)
		MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
			if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_SPACE):
				_set_panning(true, event.position)
			elif not event.pressed and _panning:
				_set_panning(false, event.position)
			elif event.pressed:
				grab_focus()
				Input.use_accumulated_input = false
				var button: PrismEnums.PaintButton = PrismEnums.PaintButton.PRIMARY if event.button_index == MOUSE_BUTTON_LEFT else PrismEnums.PaintButton.SECONDARY
				_tools.press(local_to_pixel(event.position), button, modifiers_of(event))
			else:
				_tools.release(local_to_pixel(event.position), modifiers_of(event))
				Input.use_accumulated_input = true
		_:
			return
	accept_event()


func _handle_motion(event: InputEventMouseMotion) -> void:
	if _panning:
		pan += event.position - _pan_from
		_pan_from = event.position
		_apply_transform()
	var pixel: Vector2i = local_to_pixel(event.position)
	if _tools.is_stroke_active():
		_tools.motion(pixel, modifiers_of(event))
	_hovering = true
	if pixel != _hover or not _ghost.visible:
		_hover = pixel
		_update_ghost()
		cursor_moved.emit(pixel, Rect2i(Vector2i.ZERO, get_canvas_size()).has_point(pixel))
	accept_event()


func _set_panning(active: bool, at: Vector2) -> void:
	_panning = active
	_pan_from = at
	mouse_default_cursor_shape = Control.CURSOR_DRAG if active else Control.CURSOR_ARROW
	_update_ghost()


## Tool modifier bitmask from an input event (Ctrl means Cmd on macOS).
static func modifiers_of(event: InputEventWithModifiers) -> int:
	var mods: int = 0
	if event.shift_pressed:
		mods |= Tool.MOD_SHIFT
	if event.is_command_or_control_pressed():
		mods |= Tool.MOD_CTRL
	if event.alt_pressed:
		mods |= Tool.MOD_ALT
	return mods


func _on_mouse_exited() -> void:
	_hovering = false
	_update_ghost()
	cursor_moved.emit(_hover, false)


# --- document & state --------------------------------------------------------

func _on_image_changed(image_id: StringName, _dirty: Rect2i) -> void:
	_cache.mark_dirty(image_id)


func _on_document_changed(dirty: Rect2i) -> void:
	if not dirty.has_area():
		_cache.mark_all_dirty()
	_stack.rebuild(_bus.document, _state.frame_index)


func _on_palette_changed() -> void:
	_palette_texture.update(_bus.document.palette)
	_rebuild_ghost()


func _on_stencil_blocked(image_id: StringName, offsets: PackedInt32Array) -> void:
	if not _state.flash_stencil:
		return
	var cel: Cel = _state.current_cel()
	if cel == null or cel.image_id != image_id:
		return
	var image: IndexedImage = _bus.document.images[image_id]
	var pixels: PackedVector2Array = PackedVector2Array()
	var resize_error: int = pixels.resize(offsets.size())
	assert(resize_error == OK)
	for i: int in offsets.size():
		var offset: int = offsets[i]
		var y: int = floori(offset / float(image.width))
		pixels[i] = Vector2(offset - y * image.width, y) + Vector2(cel.offset)
	_flash.flash(pixels)


## True while a stencil flash is fading (for tests).
func is_flashing() -> bool:
	return _flash.is_flashing()


func _on_document_replaced() -> void:
	var doc: PrismDocument = _bus.document
	_cache.clear()
	_palette_texture.update(doc.palette)
	var canvas: Vector2 = Vector2(doc.width, doc.height)
	_checker.size = canvas
	_grid.size = canvas
	(_checker.material as ShaderMaterial).set_shader_parameter("canvas_size", canvas)
	(_grid.material as ShaderMaterial).set_shader_parameter("canvas_size", canvas)
	_stack.rebuild(doc, _state.frame_index)
	_needs_fit = true
	if size.x > 0.0:
		fit()
		_needs_fit = false
	_rebuild_ghost()


func _on_resized() -> void:
	if _needs_fit and _bus != null and size.x > 0.0:
		fit()
		_needs_fit = false


func _on_state_changed() -> void:
	_overlay.selection = _state.selection
	_overlay.pickup = _state.pickup_rect
	_overlay.queue_redraw()
	_rebuild_ghost()


## Shows/hides the ghost brush and snaps it to the hovered pixel.
func _update_ghost() -> void:
	if _bus == null:
		return
	var tool: Tool = _tools.get_active()
	_ghost.visible = _hovering and not _panning and tool != null and tool.shows_brush_preview()
	_ghost.position = Vector2(_hover - _state.brush.anchor)


## Rebuilds the ghost texture from the current brush and FG (on brush, color or tool change).
func _rebuild_ghost() -> void:
	if _bus == null:
		return
	var brush: Brush = _state.brush
	var doc: PrismDocument = _bus.document
	var ghost_image: IndexedImage = IndexedImage.new(&"ghost", brush.image.width, brush.image.height, doc.transparent_index)
	for i: int in brush.image.pixels.size():
		var value: int = brush.image.pixels[i]
		if value != brush.transparent_index:
			ghost_image.pixels[i] = _state.fg if brush.is_mask else value
	var texture: ImageTexture = ImageTexture.create_from_image(Image.create_from_data(ghost_image.width, ghost_image.height, false, Image.FORMAT_R8, ghost_image.pixels))
	_ghost.texture = texture
	_ghost.material = CelStack.make_material(texture, _palette_texture.texture, doc.transparent_index, GHOST_OPACITY)
	_update_ghost()


func _shaded_rect(shader: Shader) -> ColorRect:
	var rect: ColorRect = ColorRect.new()
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	rect.material = material
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect
