## Snapshot of a document's structure: layers, frames, cels, tags and the image table.
## Layers, frames, cels and tags are copied; images are shared by reference (their pixels are
## versioned by PixelPatch). Restoring assigns fresh copies, so later in-place edits to the
## document never alter a snapshot.
class_name DocumentStructure
extends RefCounted

var layers: Array[Layer] = []
var frames: Array[Frame] = []
var cels: Array[Cel] = []
var tags: Array[Tag] = []
var images: Dictionary[StringName, IndexedImage] = {}
var next_id: int = 1


static func capture(doc: PrismDocument) -> DocumentStructure:
	var snapshot: DocumentStructure = DocumentStructure.new()
	for layer: Layer in doc.layers:
		snapshot.layers.append(layer.duplicate_layer(layer.id))
	for frame: Frame in doc.frames:
		snapshot.frames.append(frame.duplicate_frame(frame.id))
	for cel: Cel in doc.cels.values():
		snapshot.cels.append(cel.duplicate_cel())
	for tag: Tag in doc.tags:
		snapshot.tags.append(tag.duplicate_tag())
	snapshot.images = doc.images.duplicate()
	snapshot.next_id = doc.next_id
	return snapshot


func restore(doc: PrismDocument) -> void:
	doc.layers.clear()
	for layer: Layer in layers:
		doc.layers.append(layer.duplicate_layer(layer.id))
	doc.frames.clear()
	for frame: Frame in frames:
		doc.frames.append(frame.duplicate_frame(frame.id))
	# Temporary unique keys; reindex_cels() derives the real ones from the ids.
	doc.cels.clear()
	for i: int in cels.size():
		doc.cels[Vector2i(i, -1)] = cels[i].duplicate_cel()
	doc.tags.clear()
	for tag: Tag in tags:
		doc.tags.append(tag.duplicate_tag())
	doc.images = images.duplicate()
	doc.reindex_cels()
	# Never hand out an id twice, even after undoing the command that used it.
	doc.next_id = maxi(doc.next_id, next_id)
