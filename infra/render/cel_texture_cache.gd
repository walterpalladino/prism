## One FORMAT_R8 ImageTexture per IndexedImage, shared by every view that shows it.
## Pixel edits mark an image dirty; flush() uploads each dirty image once (ADR 0001).
class_name CelTextureCache
extends RefCounted

var _textures: Dictionary[StringName, ImageTexture] = {}
var _images: Dictionary[StringName, Image] = {}
var _dirty: Dictionary[StringName, bool] = {}


func get_texture(image: IndexedImage) -> ImageTexture:
	if not _textures.has(image.id):
		var source: Image = Image.create_from_data(image.width, image.height, false, Image.FORMAT_R8, image.pixels)
		_images[image.id] = source
		_textures[image.id] = ImageTexture.create_from_image(source)
	return _textures[image.id]


func mark_dirty(image_id: StringName) -> void:
	if _textures.has(image_id):
		_dirty[image_id] = true


func mark_all_dirty() -> void:
	for image_id: StringName in _textures:
		_dirty[image_id] = true


func has_dirty() -> bool:
	return not _dirty.is_empty()


## Uploads every dirty image of `doc`. Call at most once per rendered frame.
func flush(doc: PrismDocument) -> void:
	for image_id: StringName in _dirty:
		if not doc.images.has(image_id):
			continue
		var image: IndexedImage = doc.images[image_id]
		var source: Image = _images[image_id]
		source.set_data(image.width, image.height, false, Image.FORMAT_R8, image.pixels)
		_textures[image_id].update(source)
	_dirty.clear()


## The CPU-side Image last uploaded for `image_id` (null if not cached).
func get_source(image_id: StringName) -> Image:
	return _images.get(image_id, null)


func size() -> int:
	return _textures.size()


func clear() -> void:
	_textures.clear()
	_images.clear()
	_dirty.clear()
