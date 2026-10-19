## Layer, frame, cel and tag operations (GDD §7.7, §7.8). Each is one undoable command.
##
## Invariant: every (layer, frame) slot has a cel. An "empty" cel is one whose image is all
## transparent. Linked cels share one image; unlinking gives a cel its own copy.
## Layer index 0 is the bottom layer.
class_name TimelineActions
extends RefCounted

const MIN_DURATION_MS: int = 1
const MAX_DURATION_MS: int = 60000
const TAG_COLORS: Array[Color] = [Color("#3d7bff"), Color("#ff8a3d"), Color("#4fc35a"), Color("#ff5ea8"), Color("#ffe14a"), Color("#3dffd0")]

var bus: CommandBus
var state: EditorState


func _init(p_bus: CommandBus, p_state: EditorState) -> void:
	bus = p_bus
	state = p_state
	Signals.on(bus.history_changed, state.clamp_to_document)


func doc() -> PrismDocument:
	return bus.document


# --- layers ------------------------------------------------------------------

## Adds an empty layer above the current one and selects it.
func add_layer() -> void:
	var at: int = state.layer_index + 1
	_edit("New Layer", func(d: PrismDocument) -> void:
		var layer: Layer = Layer.new(d.new_id("L"), "Layer %d" % (d.layers.size() + 1))
		var _inserted: int = d.layers.insert(at, layer)
		for frame: Frame in d.frames:
			d.cels[Vector2i(-1, d.cels.size())] = Cel.new(layer.id, frame.id, d.create_image().id))
	state.set_layer(at)


## Deletes a layer (never the last one). Returns false if refused.
func delete_layer(index: int) -> bool:
	if doc().layers.size() <= 1 or not _valid_layer(index):
		return false
	_edit("Delete Layer", func(d: PrismDocument) -> void: d.layers.remove_at(index))
	state.set_layer(mini(index, doc().layers.size() - 1))
	return true


## Copies a layer (with its own pixels; links inside the layer are kept) above the original.
func duplicate_layer(index: int) -> void:
	if not _valid_layer(index):
		return
	_edit("Duplicate Layer", func(d: PrismDocument) -> void:
		var source: Layer = d.layers[index]
		var copy: Layer = source.duplicate_layer(d.new_id("L"))
		copy.layer_name = source.layer_name + " copy"
		var _inserted: int = d.layers.insert(index + 1, copy)
		var copies: Dictionary[StringName, StringName] = {}
		for frame_index: int in d.frames.size():
			var cel: Cel = d.get_cel(index, frame_index)
			if not copies.has(cel.image_id):
				var image: IndexedImage = d.images[cel.image_id].duplicate_image(d.new_id("I"))
				d.images[image.id] = image
				copies[cel.image_id] = image.id
			d.cels[Vector2i(-1, d.cels.size())] = Cel.new(copy.id, cel.frame_id, copies[cel.image_id], cel.offset))
	state.set_layer(index + 1)


func rename_layer(index: int, new_name: String) -> void:
	var cleaned: String = new_name.strip_edges()
	if not _valid_layer(index) or cleaned == "" or doc().layers[index].layer_name == cleaned:
		return
	_edit("Rename Layer", func(d: PrismDocument) -> void: d.layers[index].layer_name = cleaned)


func set_layer_visible(index: int, value: bool) -> void:
	if _valid_layer(index) and doc().layers[index].visible != value:
		_edit("Show Layer" if value else "Hide Layer", func(d: PrismDocument) -> void: d.layers[index].visible = value)


func set_layer_locked(index: int, value: bool) -> void:
	if _valid_layer(index) and doc().layers[index].locked != value:
		_edit("Lock Layer" if value else "Unlock Layer", func(d: PrismDocument) -> void: d.layers[index].locked = value)


func set_layer_opacity(index: int, opacity: int) -> void:
	var clamped: int = clampi(opacity, 0, 255)
	if _valid_layer(index) and doc().layers[index].opacity != clamped:
		_edit("Layer Opacity", func(d: PrismDocument) -> void: d.layers[index].opacity = clamped)


## Moves a layer to another stack position; the current layer follows it.
func move_layer(from: int, to: int) -> void:
	if from == to or not _valid_layer(from) or not _valid_layer(to):
		return
	_edit("Move Layer", func(d: PrismDocument) -> void:
		var layer: Layer = d.layers[from]
		d.layers.remove_at(from)
		var _inserted: int = d.layers.insert(to, layer))
	state.set_layer(to)


# --- frames ------------------------------------------------------------------

## Inserts an empty frame at `at` (0..frame count) and moves to it.
func insert_frame(at: int) -> void:
	var index: int = clampi(at, 0, doc().frames.size())
	_edit("New Frame", func(d: PrismDocument) -> void:
		var frame: Frame = Frame.new(d.new_id("F"), d.frames[mini(index, d.frames.size() - 1)].duration_ms)
		var _inserted: int = d.frames.insert(index, frame)
		for layer: Layer in d.layers:
			d.cels[Vector2i(-1, d.cels.size())] = Cel.new(layer.id, frame.id, d.create_image().id)
		_shift_tags_for_insert(d, index))
	state.set_frame(index)


## Copies frame `index` right after itself. Linked: the copy shares the images; otherwise
## it gets its own pixels.
func duplicate_frame(index: int, linked: bool) -> void:
	if not _valid_frame(index):
		return
	_edit("Duplicate Frame (Linked)" if linked else "Duplicate Frame", func(d: PrismDocument) -> void:
		var source: Frame = d.frames[index]
		var copy: Frame = source.duplicate_frame(d.new_id("F"))
		var _inserted: int = d.frames.insert(index + 1, copy)
		for layer_index: int in d.layers.size():
			var cel: Cel = d.get_cel(layer_index, index)
			var image_id: StringName = cel.image_id
			if not linked:
				var image: IndexedImage = d.images[image_id].duplicate_image(d.new_id("I"))
				d.images[image.id] = image
				image_id = image.id
			d.cels[Vector2i(-1, d.cels.size())] = Cel.new(cel.layer_id, copy.id, image_id, cel.offset)
		_shift_tags_for_insert(d, index + 1))
	state.set_frame(index + 1)


## Deletes a frame (never the last one). Tags shrink or disappear. Returns false if refused.
func delete_frame(index: int) -> bool:
	if doc().frames.size() <= 1 or not _valid_frame(index):
		return false
	_edit("Delete Frame", func(d: PrismDocument) -> void:
		d.frames.remove_at(index)
		var kept: Array[Tag] = []
		for tag: Tag in d.tags:
			if tag.from_frame > index:
				tag.from_frame -= 1
			if tag.to_frame >= index:
				tag.to_frame -= 1
			if tag.from_frame <= tag.to_frame:
				kept.append(tag)
		d.tags = kept)
	state.set_frame(mini(index, doc().frames.size() - 1))
	return true


## Moves a frame to another position (tags keep their frame numbers); the playhead follows it.
func move_frame(from: int, to: int) -> void:
	if from == to or not _valid_frame(from) or not _valid_frame(to):
		return
	_edit("Move Frame", func(d: PrismDocument) -> void:
		var frame: Frame = d.frames[from]
		d.frames.remove_at(from)
		var _inserted: int = d.frames.insert(to, frame))
	state.set_frame(to)


## Sets the duration of every frame in the inclusive range.
func set_duration(frame_range: Vector2i, ms: int) -> void:
	var clamped: int = clampi(ms, MIN_DURATION_MS, MAX_DURATION_MS)
	var changed: bool = false
	for i: int in range(frame_range.x, frame_range.y + 1):
		changed = changed or (_valid_frame(i) and doc().frames[i].duration_ms != clamped)
	if not changed:
		return
	_edit("Frame Duration", func(d: PrismDocument) -> void:
		for i: int in range(frame_range.x, frame_range.y + 1):
			if i >= 0 and i < d.frames.size():
				d.frames[i].duration_ms = clamped)


func next_frame() -> void:
	state.set_frame(posmod(state.frame_index + 1, doc().frames.size()))


func previous_frame() -> void:
	state.set_frame(posmod(state.frame_index - 1, doc().frames.size()))


# --- cels --------------------------------------------------------------------

## Makes every cel of `layer` in the frame range share the first cel's image.
func link_cels(layer: int, frame_range: Vector2i) -> bool:
	if not _valid_layer(layer) or not _valid_frame(frame_range.x) or not _valid_frame(frame_range.y) or frame_range.x >= frame_range.y:
		return false
	var shared: StringName = doc().get_cel(layer, frame_range.x).image_id
	var needed: bool = false
	for i: int in range(frame_range.x + 1, frame_range.y + 1):
		needed = needed or doc().get_cel(layer, i).image_id != shared
	if not needed:
		return false
	_edit("Link Cels", func(d: PrismDocument) -> void:
		for i: int in range(frame_range.x + 1, frame_range.y + 1):
			d.get_cel(layer, i).image_id = shared)
	return true


## Gives a linked cel its own copy of the image. Returns false if it was not linked.
func unlink_cel(layer: int, frame: int) -> bool:
	if not _valid_layer(layer) or not _valid_frame(frame):
		return false
	var cel: Cel = doc().get_cel(layer, frame)
	if doc().count_image_users(cel.image_id) < 2:
		return false
	_edit("Unlink Cel", func(d: PrismDocument) -> void:
		var target: Cel = d.get_cel(layer, frame)
		var image: IndexedImage = d.images[target.image_id].duplicate_image(d.new_id("I"))
		d.images[image.id] = image
		target.image_id = image.id)
	return true


func is_linked(layer: int, frame: int) -> bool:
	var cel: Cel = doc().get_cel(layer, frame)
	return cel != null and doc().count_image_users(cel.image_id) > 1


## Clears a cel to the transparent index (linked cels change together). One PixelPatch.
func clear_cel(layer: int, frame: int) -> bool:
	if not _valid_layer(layer) or not _valid_frame(frame):
		return false
	var image: IndexedImage = doc().get_cel_image(layer, frame)
	var session: StrokeSession = StrokeSession.new(image)
	image.fill(doc().transparent_index)
	session.add_dirty(image.get_rect())
	return _record_patch(session, "Clear Cel")


func copy_cel(layer: int, frame: int) -> bool:
	if not _valid_layer(layer) or not _valid_frame(frame):
		return false
	state.cel_clipboard = doc().get_cel_image(layer, frame).duplicate_image(&"cel_clipboard")
	return true


## Replaces a cel's pixels with the copied cel. Returns false if nothing was copied.
func paste_cel(layer: int, frame: int) -> bool:
	if state.cel_clipboard == null or not _valid_layer(layer) or not _valid_frame(frame):
		return false
	var image: IndexedImage = doc().get_cel_image(layer, frame)
	if image.get_size() != state.cel_clipboard.get_size():
		return false
	var session: StrokeSession = StrokeSession.new(image)
	RasterOps.write_rect(image, image.get_rect(), state.cel_clipboard.pixels)
	session.add_dirty(image.get_rect())
	return _record_patch(session, "Paste Cel")


# --- tags --------------------------------------------------------------------

## Creates a forward tag over the frame range and returns its index.
func add_tag(frame_range: Vector2i, tag_name: String = "") -> int:
	var index: int = doc().tags.size()
	var label: String = tag_name if tag_name != "" else "tag%d" % (index + 1)
	_edit("New Tag", func(d: PrismDocument) -> void:
		var tag: Tag = Tag.new(label, frame_range.x, frame_range.y)
		tag.color = TAG_COLORS[index % TAG_COLORS.size()]
		d.tags.append(tag))
	return index


func update_tag(index: int, tag_name: String, frame_range: Vector2i, direction: PrismEnums.TagDirection, color: Color) -> void:
	if index < 0 or index >= doc().tags.size():
		return
	var last: int = doc().frames.size() - 1
	var first_frame: int = clampi(mini(frame_range.x, frame_range.y), 0, last)
	var last_frame: int = clampi(maxi(frame_range.x, frame_range.y), 0, last)
	_edit("Edit Tag", func(d: PrismDocument) -> void:
		var tag: Tag = d.tags[index]
		tag.tag_name = tag_name.strip_edges() if tag_name.strip_edges() != "" else tag.tag_name
		tag.from_frame = first_frame
		tag.to_frame = last_frame
		tag.direction = direction
		tag.color = color)


func delete_tag(index: int) -> void:
	if index >= 0 and index < doc().tags.size():
		_edit("Delete Tag", func(d: PrismDocument) -> void: d.tags.remove_at(index))


# --- helpers -----------------------------------------------------------------

func _edit(label: String, mutate: Callable) -> void:
	var d: PrismDocument = doc()
	var before: DocumentStructure = DocumentStructure.capture(d)
	mutate.call(d)
	d.reindex_cels()
	d.prune_images()
	bus.record(StructureCommand.new(label, before, DocumentStructure.capture(d)))


func _record_patch(session: StrokeSession, label: String) -> bool:
	var patch: PixelPatch = session.commit(label)
	if patch == null:
		return false
	bus.record(patch)
	return true


func _shift_tags_for_insert(d: PrismDocument, index: int) -> void:
	for tag: Tag in d.tags:
		if tag.from_frame >= index:
			tag.from_frame += 1
			tag.to_frame += 1
		elif tag.to_frame >= index:
			tag.to_frame += 1


func _valid_layer(index: int) -> bool:
	return index >= 0 and index < doc().layers.size()


func _valid_frame(index: int) -> bool:
	return index >= 0 and index < doc().frames.size()
