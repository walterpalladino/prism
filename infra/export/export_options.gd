## What to export: which frames (a tag or all), scale, cycling bake, sheet layout.
class_name ExportOptions
extends RefCounted

enum Layout { ROW, COLUMN, GRID, TIGHT }

var frame_range: Vector2i = Vector2i.ZERO
var direction: PrismEnums.TagDirection = PrismEnums.TagDirection.FORWARD
## Integer nearest-neighbor upscale.
var scale: int = 1
## Bake color cycling into frames (GIF, PNG sequence).
var bake_cycles: bool = false
var max_frames: int = FrameSchedule.DEFAULT_MAX_FRAMES
var layout: Layout = Layout.GRID


## All frames, forward.
static func whole(doc: PrismDocument) -> ExportOptions:
	var options: ExportOptions = ExportOptions.new()
	options.frame_range = Vector2i(0, doc.frames.size() - 1)
	return options


## The frames of tag `index`, in its direction.
static func for_tag(doc: PrismDocument, index: int) -> ExportOptions:
	var options: ExportOptions = ExportOptions.new()
	var tag: Tag = doc.tags[index]
	options.frame_range = Vector2i(tag.from_frame, tag.to_frame)
	options.direction = tag.direction
	return options


func order() -> PackedInt32Array:
	return FrameSchedule.play_order(frame_range, direction)


func schedule(doc: PrismDocument) -> Array[Vector3i]:
	return FrameSchedule.build(doc, order(), bake_cycles, max_frames)
