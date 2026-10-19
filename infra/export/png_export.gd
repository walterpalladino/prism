## PNG frame and PNG sequence export (GDD §7.12).
class_name PngExport
extends RefCounted


## One frame as an RGBA image.
static func frame_image(doc: PrismDocument, frame_index: int, scale: int = 1, time_s: float = 0.0, cycled: bool = false) -> Image:
	var colors: PackedColorArray = ColorCycler.cycled_colors(doc.palette.colors, doc.cycles, time_s) if cycled else doc.palette.colors
	return FrameCompositor.scaled(FrameCompositor.composite_rgba(doc, frame_index, colors), scale)


## Writes `base_0001.png`, `base_0002.png`… for the schedule; returns "" or an error.
## `path` is any file path; its extension is dropped and the numbers appended.
static func write_sequence(doc: PrismDocument, options: ExportOptions, sink: FileSink, path: String) -> String:
	var base: String = path.get_basename()
	var schedule: Array[Vector3i] = options.schedule(doc)
	for i: int in schedule.size():
		var entry: Vector3i = schedule[i]
		var image: Image = frame_image(doc, entry.x, options.scale, entry.y / 1000.0, options.bake_cycles)
		var error: String = sink.write_png("%s_%04d.png" % [base, i + 1], image)
		if error != "":
			return error
	return ""
