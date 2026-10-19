class_name PrismDocument
extends RefCounted

const MAX_CANVAS_SIZE: int = 512

var id: StringName
var width: int
var height: int
var color_mode: PrismEnums.ColorMode = PrismEnums.ColorMode.INDEXED
var palette: Palette
var transparent_index: int = 0
var layers: Array[Layer] = []
var frames: Array[Frame] = []
var images: Dictionary[StringName, IndexedImage] = {}
## Keyed by Vector2i(layer_index, frame_index). A missing key is an empty cel.
var cels: Dictionary[Vector2i, Cel] = {}
var tags: Array[Tag] = []
var cycles: Array[CycleRange] = []
var stencil: Stencil = Stencil.new()
## Counter behind new_id(); persisted so ids stay unique across save/load.
var next_id: int = 1


func _init(p_id: StringName, p_width: int, p_height: int, p_palette: Palette) -> void:
	id = p_id
	width = p_width
	height = p_height
	palette = p_palette


## New document with one layer, one frame and one empty cel filled with the transparent index.
static func create(p_width: int, p_height: int, p_palette: Palette = null) -> PrismDocument:
	var doc_palette: Palette = p_palette if p_palette != null else PalettePresets.default_32()
	var doc: PrismDocument = PrismDocument.new(&"doc", p_width, p_height, doc_palette)
	var layer: Layer = Layer.new(doc.new_id("L"), "Layer 1")
	var frame: Frame = Frame.new(doc.new_id("F"))
	doc.layers.append(layer)
	doc.frames.append(frame)
	var image: IndexedImage = doc.create_image()
	doc.cels[Vector2i(0, 0)] = Cel.new(layer.id, frame.id, image.id)
	return doc


## Deterministic, document-unique id such as "L1", "F2", "I3".
func new_id(prefix: String) -> StringName:
	var result: StringName = StringName("%s%d" % [prefix, next_id])
	next_id += 1
	return result


## Creates a canvas-sized image filled with the transparent index and registers it.
func create_image() -> IndexedImage:
	var image: IndexedImage = IndexedImage.new(new_id("I"), width, height, transparent_index)
	images[image.id] = image
	return image


func layer_index_of(layer_id: StringName) -> int:
	for i: int in layers.size():
		if layers[i].id == layer_id:
			return i
	return -1


func frame_index_of(frame_id: StringName) -> int:
	for i: int in frames.size():
		if frames[i].id == frame_id:
			return i
	return -1


func has_cel(layer_index: int, frame_index: int) -> bool:
	return cels.has(Vector2i(layer_index, frame_index))


## The cel at (layer, frame), or null if empty.
func get_cel(layer_index: int, frame_index: int) -> Cel:
	var key: Vector2i = Vector2i(layer_index, frame_index)
	if not cels.has(key):
		return null
	return cels[key]


## The image of the cel at (layer, frame), or null if empty.
func get_cel_image(layer_index: int, frame_index: int) -> IndexedImage:
	var cel: Cel = get_cel(layer_index, frame_index)
	if cel == null:
		return null
	return images[cel.image_id]


## Number of cels referencing `image_id`; more than one means the cels are linked.
func count_image_users(image_id: StringName) -> int:
	var count: int = 0
	for cel: Cel in cels.values():
		if cel.image_id == image_id:
			count += 1
	return count
