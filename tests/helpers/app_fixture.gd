## A document + bus + state + every M2 tool, without any nodes.
class_name AppFixture
extends RefCounted

const PRIMARY: PrismEnums.PaintButton = PrismEnums.PaintButton.PRIMARY
const SECONDARY: PrismEnums.PaintButton = PrismEnums.PaintButton.SECONDARY

var bus: CommandBus
var state: EditorState
var controller: ToolController
var selection: SelectionActions
var palette: PaletteActions
var timeline: TimelineActions
var playback: Playback
var cycling: ColorCycling


func _init(width: int = 8, height: int = 8) -> void:
	bus = CommandBus.new(PrismDocument.create(width, height), History.new())
	state = EditorState.new(bus)
	controller = ToolController.new()
	controller.register(PencilTool.new(bus, state))
	controller.register(PencilTool.new(bus, state, true))
	controller.register(ShapeTool.new(bus, state, ShapeTool.Kind.LINE))
	controller.register(ShapeTool.new(bus, state, ShapeTool.Kind.RECT))
	controller.register(ShapeTool.new(bus, state, ShapeTool.Kind.ELLIPSE))
	controller.register(FillTool.new(bus, state, GDScriptRasterBackend.new()))
	controller.register(PickerTool.new(bus, state))
	controller.register(RectSelectTool.new(bus, state))
	controller.register(MoveCelTool.new(bus, state))
	controller.register(BrushPickupTool.new(bus, state))
	selection = SelectionActions.new(bus, state)
	palette = PaletteActions.new(bus, state)
	timeline = TimelineActions.new(bus, state)
	playback = Playback.new(bus)
	cycling = ColorCycling.new(bus)


func image() -> IndexedImage:
	return bus.document.get_cel_image(0, 0)


func image_at(layer: int, frame: int) -> IndexedImage:
	return bus.document.get_cel_image(layer, frame)


func rows() -> PackedStringArray:
	return image().to_rows()


## Press at the first point, drag through the rest, release at the last.
func stroke(tool_id: StringName, points: Array[Vector2i], button: PrismEnums.PaintButton = PRIMARY, mods: int = 0) -> void:
	controller.activate(tool_id)
	controller.press(points[0], button, mods)
	for i: int in range(1, points.size()):
		controller.motion(points[i], mods)
	controller.release(points[points.size() - 1], mods)


func click(tool_id: StringName, at: Vector2i, button: PrismEnums.PaintButton = PRIMARY, mods: int = 0) -> void:
	var points: Array[Vector2i] = [at]
	stroke(tool_id, points, button, mods)
