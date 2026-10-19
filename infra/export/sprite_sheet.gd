## Sprite sheet + JSON export (GDD §7.12). The JSON follows the widely supported Aseprite
## "array" layout: frames with rect, trim info and duration, plus meta.frameTags.
class_name SpriteSheet
extends RefCounted

const DIRECTIONS: PackedStringArray = ["forward", "reverse", "pingpong"]

## The packed sheet image.
var image: Image
## Per sheet cell: Rect2i in the sheet (scaled pixels).
var rects: Array[Rect2i] = []
## Per sheet cell: trimmed area inside the source frame (scaled pixels).
var trims: Array[Rect2i] = []
## Document frame shown in each cell.
var frame_indices: PackedInt32Array = PackedInt32Array()


## Packs every frame in `options.frame_range` (each once, in timeline order).
static func pack(doc: PrismDocument, options: ExportOptions) -> SpriteSheet:
	var sheet: SpriteSheet = SpriteSheet.new()
	var images: Array[Image] = []
	for f: int in range(options.frame_range.x, options.frame_range.y + 1):
		var full: Image = PngExport.frame_image(doc, f, options.scale)
		var trim: Rect2i = Rect2i(Vector2i.ZERO, full.get_size())
		if options.layout == ExportOptions.Layout.TIGHT:
			trim = full.get_used_rect()
			if not trim.has_area():
				trim = Rect2i(0, 0, 1, 1)
		images.append(full.get_region(trim))
		sheet.trims.append(trim)
		@warning_ignore("return_value_discarded")
		sheet.frame_indices.append(f)
	var cell: Vector2i = Vector2i(doc.width, doc.height) * options.scale
	var count: int = images.size()
	var layout: ExportOptions.Layout = effective_layout(options)
	var margin: int = maxi(0, options.margin)
	var spacing: int = maxi(0, options.spacing)
	if layout == ExportOptions.Layout.TIGHT:
		sheet._pack_tight(images, margin, spacing)
		return sheet
	var grid: Vector2i = Vector2i(count, 1)
	match layout:
		ExportOptions.Layout.COLUMN:
			grid = Vector2i(1, count)
		ExportOptions.Layout.GRID:
			grid = grid_size(count, options.columns, options.rows)
	var columns: int = grid.x
	var rows: int = grid.y
	var sheet_size: Vector2i = Vector2i(columns, rows) * cell + Vector2i(columns - 1, rows - 1) * spacing + Vector2i(margin, margin) * 2
	sheet.image = Image.create_empty(sheet_size.x, sheet_size.y, false, Image.FORMAT_RGBA8)
	for i: int in count:
		var at: Vector2i = Vector2i(margin, margin) + Vector2i(i % columns, floori(i / float(columns))) * (cell + Vector2i(spacing, spacing))
		sheet.image.blit_rect(images[i], Rect2i(Vector2i.ZERO, images[i].get_size()), at)
		sheet.rects.append(Rect2i(at, cell))
	return sheet


## Shelf packing of trimmed frames: rows of frames no wider than ~sqrt(total area), with
## `margin` around the sheet and `spacing` between frames.
func _pack_tight(images: Array[Image], margin: int, spacing: int) -> void:
	var area: int = 0
	var widest: int = 1
	for img: Image in images:
		area += img.get_width() * img.get_height()
		widest = maxi(widest, img.get_width())
	var max_width: int = maxi(widest, ceili(sqrt(float(area)) * 1.2))
	var x: int = margin
	var y: int = margin
	var row_height: int = 0
	for img: Image in images:
		if x > margin and x - margin + img.get_width() > max_width:
			x = margin
			y += row_height + spacing
			row_height = 0
		rects.append(Rect2i(x, y, img.get_width(), img.get_height()))
		x += img.get_width() + spacing
		row_height = maxi(row_height, img.get_height())
	var width: int = 1
	var height: int = 1
	for rect: Rect2i in rects:
		width = maxi(width, rect.end.x + margin)
		height = maxi(height, rect.end.y + margin)
	image = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	for i: int in images.size():
		image.blit_rect(images[i], Rect2i(Vector2i.ZERO, images[i].get_size()), rects[i].position)


## The JSON description; `image_name` is the sheet file name referenced from meta.image.
func to_json(doc: PrismDocument, options: ExportOptions, image_name: String) -> String:
	var frames: Array = []
	var source_size: Vector2i = Vector2i(doc.width, doc.height) * options.scale
	for i: int in rects.size():
		var rect: Rect2i = rects[i]
		var trim: Rect2i = trims[i]
		frames.append({
			"filename": "frame %d" % (frame_indices[i] + 1),
			"frame": {"x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y},
			"rotated": false,
			"trimmed": trim.size != source_size,
			"spriteSourceSize": {"x": trim.position.x, "y": trim.position.y, "w": trim.size.x, "h": trim.size.y},
			"sourceSize": {"w": source_size.x, "h": source_size.y},
			"duration": doc.frames[frame_indices[i]].duration_ms,
		})
	var tags: Array = []
	for tag: Tag in doc.tags:
		if tag.from_frame >= options.frame_range.x and tag.to_frame <= options.frame_range.y:
			tags.append({"name": tag.tag_name, "from": tag.from_frame - options.frame_range.x, "to": tag.to_frame - options.frame_range.x, "direction": DIRECTIONS[tag.direction], "color": "#" + tag.color.to_html(false)})
	var meta: Dictionary = {
		"app": "PRISM",
		"version": ProjectSettings.get_setting("application/config/version", "0"),
		"image": image_name,
		"format": "RGBA8888",
		"size": {"w": image.get_width(), "h": image.get_height()},
		"scale": str(options.scale),
		"frameTags": tags,
	}
	return JSON.stringify({"frames": frames, "meta": meta}, "  ")


## Writes `<path>.png` and `<path>.json`; returns "" or an error.
## The layout actually used: asking for columns or rows means a grid.
static func effective_layout(options: ExportOptions) -> ExportOptions.Layout:
	if options.columns > 0 or options.rows > 0:
		return ExportOptions.Layout.GRID
	return options.layout


## Columns x rows for `count` frames. 0 = automatic: both automatic gives a near-square grid;
## with one given, the other is just enough to fit every frame. Both given are used as is
## (check grid_error first); unused cells stay transparent.
static func grid_size(count: int, columns: int, rows: int) -> Vector2i:
	var n: int = maxi(count, 1)
	if columns > 0 and rows > 0:
		return Vector2i(columns, rows)
	if columns > 0:
		return Vector2i(columns, ceili(n / float(columns)))
	if rows > 0:
		return Vector2i(ceili(n / float(rows)), rows)
	var auto_columns: int = ceili(sqrt(float(n)))
	return Vector2i(auto_columns, ceili(n / float(auto_columns)))


## "" if the requested grid holds every frame, else a message saying what is needed.
static func grid_error(count: int, options: ExportOptions) -> String:
	if effective_layout(options) != ExportOptions.Layout.GRID or options.columns <= 0 or options.rows <= 0:
		return ""
	if options.columns * options.rows >= count:
		return ""
	return "a %d × %d grid has %d cells but there are %d frames; use more columns or rows, or set one of them to 0 (automatic)" % [options.columns, options.rows, options.columns * options.rows, count]


static func write(doc: PrismDocument, options: ExportOptions, sink: FileSink, path: String) -> String:
	var invalid: String = grid_error(options.frame_range.y - options.frame_range.x + 1, options)
	if invalid != "":
		return invalid
	var sheet: SpriteSheet = pack(doc, options)
	var base: String = path.get_basename()
	var error: String = sink.write_png(base + ".png", sheet.image)
	if error != "":
		return error
	return sink.write_text(base + ".json", sheet.to_json(doc, options, base.get_file() + ".png"))
