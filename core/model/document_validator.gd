## Checks the invariants of GDD §6.3. Returns human-readable errors; empty means valid.
class_name DocumentValidator
extends RefCounted

const MAX_CYCLES: int = 4


static func validate(doc: PrismDocument) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	_check_canvas(doc, errors)
	_check_palette(doc, errors)
	_check_layers_and_frames(doc, errors)
	_check_images(doc, errors)
	_check_cels(doc, errors)
	_check_tags(doc, errors)
	errors.append_array(validate_cycles(doc.cycles, doc.palette.size()))
	return errors


static func validate_cycles(cycles: Array[CycleRange], palette_size: int) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if cycles.size() > MAX_CYCLES:
		_add(errors, "too many cycle ranges: %d (max %d)" % [cycles.size(), MAX_CYCLES])
	for i: int in cycles.size():
		var cycle: CycleRange = cycles[i]
		if cycle.start_index < 0 or cycle.end_index >= palette_size or cycle.start_index >= cycle.end_index:
			_add(errors, "cycle %d: invalid range %d-%d" % [i, cycle.start_index, cycle.end_index])
		if cycle.rate_hz <= 0.0:
			_add(errors, "cycle %d: rate must be positive" % i)
		if cycle.step != 1 and cycle.step != -1:
			_add(errors, "cycle %d: step must be +1 or -1" % i)
		for j: int in range(i + 1, cycles.size()):
			if cycle.overlaps(cycles[j]):
				_add(errors, "cycles %d and %d overlap" % [i, j])
	return errors


static func _check_canvas(doc: PrismDocument, errors: PackedStringArray) -> void:
	if doc.width < 1 or doc.height < 1 or doc.width > PrismDocument.MAX_CANVAS_SIZE or doc.height > PrismDocument.MAX_CANVAS_SIZE:
		_add(errors, "canvas size %dx%d out of range" % [doc.width, doc.height])


static func _check_palette(doc: PrismDocument, errors: PackedStringArray) -> void:
	var size: int = doc.palette.size()
	if size < 1 or size > Palette.MAX_COLORS:
		_add(errors, "palette size %d out of range" % size)
	if not doc.palette.has_index(doc.transparent_index):
		_add(errors, "transparent index %d outside palette" % doc.transparent_index)
	for ramp: Vector2i in doc.palette.ramps:
		if ramp.x >= ramp.y or not doc.palette.has_index(ramp.x) or not doc.palette.has_index(ramp.y):
			_add(errors, "invalid ramp %d-%d" % [ramp.x, ramp.y])


static func _check_layers_and_frames(doc: PrismDocument, errors: PackedStringArray) -> void:
	if doc.layers.is_empty():
		_add(errors, "document has no layers")
	if doc.frames.is_empty():
		_add(errors, "document has no frames")
	var seen: Dictionary[StringName, bool] = {}
	for layer: Layer in doc.layers:
		if seen.has(layer.id):
			_add(errors, "duplicate id %s" % layer.id)
		seen[layer.id] = true
		if layer.opacity < 0 or layer.opacity > 255:
			_add(errors, "layer %s: opacity %d out of range" % [layer.id, layer.opacity])
	for frame: Frame in doc.frames:
		if seen.has(frame.id):
			_add(errors, "duplicate id %s" % frame.id)
		seen[frame.id] = true
		if frame.duration_ms <= 0:
			_add(errors, "frame %s: duration must be positive" % frame.id)


static func _check_images(doc: PrismDocument, errors: PackedStringArray) -> void:
	var palette_size: int = doc.palette.size()
	for image_id: StringName in doc.images:
		var image: IndexedImage = doc.images[image_id]
		if image.id != image_id:
			_add(errors, "image key %s does not match id %s" % [image_id, image.id])
		if image.pixels.size() != image.width * image.height:
			_add(errors, "image %s: pixel count %d != %dx%d" % [image_id, image.pixels.size(), image.width, image.height])
			continue
		for value: int in image.pixels:
			if value >= palette_size:
				_add(errors, "image %s: index %d outside palette" % [image_id, value])
				break


static func _check_cels(doc: PrismDocument, errors: PackedStringArray) -> void:
	for key: Vector2i in doc.cels:
		var cel: Cel = doc.cels[key]
		if key.x < 0 or key.x >= doc.layers.size() or key.y < 0 or key.y >= doc.frames.size():
			_add(errors, "cel %s outside the layer/frame grid" % key)
			continue
		if cel.layer_id != doc.layers[key.x].id:
			_add(errors, "cel %s: layer id %s does not match %s" % [key, cel.layer_id, doc.layers[key.x].id])
		if cel.frame_id != doc.frames[key.y].id:
			_add(errors, "cel %s: frame id %s does not match %s" % [key, cel.frame_id, doc.frames[key.y].id])
		if not doc.images.has(cel.image_id):
			_add(errors, "cel %s: missing image %s" % [key, cel.image_id])


static func _check_tags(doc: PrismDocument, errors: PackedStringArray) -> void:
	for tag: Tag in doc.tags:
		if tag.from_frame < 0 or tag.from_frame > tag.to_frame or tag.to_frame >= doc.frames.size():
			_add(errors, "tag '%s': frame range %d-%d invalid" % [tag.tag_name, tag.from_frame, tag.to_frame])


static func _add(errors: PackedStringArray, message: String) -> void:
	@warning_ignore("return_value_discarded")
	errors.append(message)
