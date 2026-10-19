## `.prism` v1 schema (GDD §9.6): PrismDocument <-> document.json + images/*.bin.
##
## Security: only JSON.parse_string() and raw bytes are used. Never str_to_var(),
## bytes_to_var_with_objects() or ResourceLoader on project files: those can instantiate
## arbitrary objects. Every field is type- and range-checked; bad input yields an error.
class_name PrismJson
extends RefCounted

const FORMAT: String = "prism"
const DIRECTIONS: PackedStringArray = ["forward", "reverse", "pingpong"]
const MAX_ITEMS: int = 100000


# --- writing -----------------------------------------------------------------

static func to_package(doc: PrismDocument) -> PrismPackage:
	var package: PrismPackage = PrismPackage.new()
	var palette: Array = []
	for i: int in doc.palette.size():
		palette.append("#" + doc.palette.get_color(i).to_html(false))
	var ramps: Array = []
	for ramp: Vector2i in doc.palette.ramps:
		ramps.append([ramp.x, ramp.y])
	var layers: Array = []
	for layer: Layer in doc.layers:
		layers.append({"id": String(layer.id), "name": layer.layer_name, "visible": layer.visible, "locked": layer.locked, "opacity": layer.opacity})
	var frames: Array = []
	for frame: Frame in doc.frames:
		frames.append({"id": String(frame.id), "durationMs": frame.duration_ms})
	var cels: Array = []
	var keys: Array[Vector2i] = doc.cels.keys()
	keys.sort()
	for key: Vector2i in keys:
		var cel: Cel = doc.cels[key]
		cels.append({"layer": String(cel.layer_id), "frame": String(cel.frame_id), "image": String(cel.image_id), "x": cel.offset.x, "y": cel.offset.y})
	var images: Array = []
	var image_ids: Array[StringName] = doc.images.keys()
	image_ids.sort()
	for image_id: StringName in image_ids:
		var image: IndexedImage = doc.images[image_id]
		var path: String = "images/%s.bin" % image_id
		images.append({"id": String(image_id), "w": image.width, "h": image.height, "path": path})
		package.files[path] = image.pixels.duplicate()
	var tags: Array = []
	for tag: Tag in doc.tags:
		tags.append({"name": tag.tag_name, "from": tag.from_frame, "to": tag.to_frame, "direction": DIRECTIONS[tag.direction], "color": "#" + tag.color.to_html(false)})
	var cycles: Array = []
	for cycle: CycleRange in doc.cycles:
		cycles.append({"start": cycle.start_index, "end": cycle.end_index, "rateHz": cycle.rate_hz, "direction": cycle.step, "active": cycle.active})
	var data: Dictionary = {
		"format": FORMAT,
		"version": PrismMigrations.CURRENT_VERSION,
		"width": doc.width,
		"height": doc.height,
		"colorMode": "indexed",
		"transparentIndex": doc.transparent_index,
		"nextId": doc.next_id,
		"palette": palette,
		"ramps": ramps,
		"layers": layers,
		"frames": frames,
		"cels": cels,
		"images": images,
		"tags": tags,
		"cycles": cycles,
		"stencil": Array(doc.stencil.locked_indices()),
	}
	package.document_json = JSON.stringify(data, "  ")
	return package


# --- reading -----------------------------------------------------------------

static func from_package(package: PrismPackage) -> DocumentResult:
	var parsed: Variant = JSON.parse_string(package.document_json)
	if not (parsed is Dictionary):
		return DocumentResult.fail("document.json is not valid JSON")
	var data: Dictionary = parsed
	if data.get("format") != FORMAT:
		return DocumentResult.fail("not a PRISM document")
	var migration_error: String = PrismMigrations.migrate(data)
	if migration_error != "":
		return DocumentResult.fail(migration_error)
	var r: JsonReader = JsonReader.new()
	var doc: PrismDocument = _read(data, package, r)
	if not r.ok():
		return DocumentResult.fail(r.errors[0] if r.errors.size() == 1 else "%s (and %d more problems)" % [r.errors[0], r.errors.size() - 1])
	var invalid: PackedStringArray = DocumentValidator.validate(doc)
	if not invalid.is_empty():
		return DocumentResult.fail("invalid document: " + invalid[0])
	for layer_index: int in doc.layers.size():
		for frame_index: int in doc.frames.size():
			if not doc.has_cel(layer_index, frame_index):
				return DocumentResult.fail("invalid document: missing cel for layer %d, frame %d" % [layer_index, frame_index])
	return DocumentResult.ok(doc)


static func _read(data: Dictionary, package: PrismPackage, r: JsonReader) -> PrismDocument:
	var width: int = r.get_int(data, "width", "document", 1, PrismDocument.MAX_CANVAS_SIZE, 1)
	var height: int = r.get_int(data, "height", "document", 1, PrismDocument.MAX_CANVAS_SIZE, 1)
	var mode: String = r.get_string(data, "colorMode", "document", "indexed")
	if mode != "indexed":
		r.fail("document: color mode '%s' is not supported" % mode)

	var colors: PackedColorArray = PackedColorArray()
	var palette_list: Array = r.get_array(data, "palette", "document")
	if palette_list.is_empty() or palette_list.size() > Palette.MAX_COLORS:
		r.fail("document: palette must have 1-%d colors" % Palette.MAX_COLORS)
	for i: int in mini(palette_list.size(), Palette.MAX_COLORS):
		var entry: Variant = palette_list[i]
		var text: String = entry if entry is String else ""
		@warning_ignore("return_value_discarded")
		colors.append(r.parse_color(text, "palette[%d]" % i))
	var palette: Palette = Palette.new(colors if not colors.is_empty() else PackedColorArray([Color.BLACK]))
	for ramp_value: Variant in _limited(r.get_array(data, "ramps", "document"), r, "ramps"):
		var pair: Array = ramp_value if ramp_value is Array else []
		if pair.size() != 2 or not _is_whole(pair[0]) or not _is_whole(pair[1]) or not palette.add_ramp(_to_int(pair[0]), _to_int(pair[1])):
			r.fail("ramps: %s is not a valid [start, end] ramp" % [ramp_value])

	var doc: PrismDocument = PrismDocument.new(&"doc", width, height, palette)
	doc.transparent_index = r.get_int(data, "transparentIndex", "document", 0, Palette.MAX_COLORS - 1)
	doc.next_id = r.get_int(data, "nextId", "document", 1, 1 << 30, 1)

	var images_by_id: Dictionary[String, IndexedImage] = {}
	for i: int in _limited(r.get_array(data, "images", "document"), r, "images").size():
		var entry: Dictionary = _entry(data["images"], i, r, "images")
		var where: String = "images[%d]" % i
		var id: String = r.get_string(entry, "id", where)
		var w: int = r.get_int(entry, "w", where, 1, PrismDocument.MAX_CANVAS_SIZE, 1)
		var h: int = r.get_int(entry, "h", where, 1, PrismDocument.MAX_CANVAS_SIZE, 1)
		var path: String = r.get_string(entry, "path", where)
		if not package.files.has(path):
			r.fail("%s: missing file '%s'" % [where, path])
			continue
		var bytes: PackedByteArray = package.files[path]
		if bytes.size() != w * h:
			r.fail("%s: '%s' has %d bytes, expected %d" % [where, path, bytes.size(), w * h])
			continue
		var image: IndexedImage = IndexedImage.new(StringName(id), w, h)
		image.pixels = bytes.duplicate()
		images_by_id[id] = image
		doc.images[image.id] = image

	for i: int in _limited(r.get_array(data, "layers", "document"), r, "layers").size():
		var entry: Dictionary = _entry(data["layers"], i, r, "layers")
		var where: String = "layers[%d]" % i
		var layer: Layer = Layer.new(StringName(r.get_string(entry, "id", where)), r.get_string(entry, "name", where))
		layer.visible = r.get_bool(entry, "visible", where, true)
		layer.locked = r.get_bool(entry, "locked", where)
		layer.opacity = r.get_int(entry, "opacity", where, 0, 255, 255)
		doc.layers.append(layer)

	for i: int in _limited(r.get_array(data, "frames", "document"), r, "frames").size():
		var entry: Dictionary = _entry(data["frames"], i, r, "frames")
		var where: String = "frames[%d]" % i
		doc.frames.append(Frame.new(StringName(r.get_string(entry, "id", where)), r.get_int(entry, "durationMs", where, 1, 600000, Frame.DEFAULT_DURATION_MS)))

	for i: int in _limited(r.get_array(data, "cels", "document"), r, "cels").size():
		var entry: Dictionary = _entry(data["cels"], i, r, "cels")
		var where: String = "cels[%d]" % i
		var image_id: String = r.get_string(entry, "image", where)
		if not images_by_id.has(image_id):
			r.fail("%s: unknown image '%s'" % [where, image_id])
			continue
		var offset: Vector2i = Vector2i(r.get_int(entry, "x", where, -4096, 4096), r.get_int(entry, "y", where, -4096, 4096))
		var cel: Cel = Cel.new(StringName(r.get_string(entry, "layer", where)), StringName(r.get_string(entry, "frame", where)), StringName(image_id), offset)
		doc.cels[Vector2i(-1, i)] = cel
	var cel_count: int = doc.cels.size()
	doc.reindex_cels()
	if doc.cels.size() != cel_count:
		r.fail("cels: some cels refer to unknown layers or frames, or two cels share a slot")

	for i: int in _limited(r.get_array(data, "tags", "document"), r, "tags").size():
		var entry: Dictionary = _entry(data["tags"], i, r, "tags")
		var where: String = "tags[%d]" % i
		var direction: int = DIRECTIONS.find(r.get_string(entry, "direction", where, "forward"))
		if direction == -1:
			r.fail("%s: unknown direction" % where)
			direction = 0
		var tag: Tag = Tag.new(r.get_string(entry, "name", where), r.get_int(entry, "from", where, 0, MAX_ITEMS), r.get_int(entry, "to", where, 0, MAX_ITEMS), direction as PrismEnums.TagDirection)
		tag.color = r.get_color(entry, "color", where)
		doc.tags.append(tag)

	for i: int in _limited(r.get_array(data, "cycles", "document"), r, "cycles").size():
		var entry: Dictionary = _entry(data["cycles"], i, r, "cycles")
		var where: String = "cycles[%d]" % i
		var cycle: CycleRange = CycleRange.new(r.get_int(entry, "start", where, 0, 255), r.get_int(entry, "end", where, 0, 255), r.get_float(entry, "rateHz", where, 0.001, 1000.0, 1.0), r.get_int(entry, "direction", where, -1, 1, 1))
		cycle.active = r.get_bool(entry, "active", where, true)
		doc.cycles.append(cycle)

	for value: Variant in _limited(r.get_array(data, "stencil", "document"), r, "stencil"):
		if _is_whole(value) and _to_int(value) >= 0 and _to_int(value) < 256:
			doc.stencil.set_locked(_to_int(value), true)
		else:
			r.fail("stencil: %s is not a palette index" % [value])
	return doc


static func _entry(list: Variant, index: int, r: JsonReader, where: String) -> Dictionary:
	var items: Array = list
	if items[index] is Dictionary:
		return items[index]
	r.fail("%s[%d] must be an object" % [where, index])
	return {}


static func _limited(list: Array, r: JsonReader, where: String) -> Array:
	if list.size() > MAX_ITEMS:
		r.fail("%s: too many entries" % where)
		return []
	return list


static func _is_whole(value: Variant) -> bool:
	if not (value is float or value is int):
		return false
	var number: float = value
	return number == floorf(number)


## Only call after _is_whole(value).
static func _to_int(value: Variant) -> int:
	var number: float = value
	return int(number)
