## Flattens a frame's visible layers for export (GDD §7.12). Shared by every exporter.
class_name FrameCompositor
extends RefCounted


## 256 RGBA entries (4 bytes each) for `colors`, with the transparent index fully clear.
static func color_table(colors: PackedColorArray, transparent_index: int, alpha: float = 1.0) -> PackedByteArray:
	var table: PackedByteArray = PackedByteArray()
	var resize_error: int = table.resize(256 * 4)
	assert(resize_error == OK)
	for i: int in mini(colors.size(), 256):
		if i == transparent_index:
			continue
		var c: Color = colors[i]
		table[i * 4] = c.r8
		table[i * 4 + 1] = c.g8
		table[i * 4 + 2] = c.b8
		table[i * 4 + 3] = roundi(c.a * alpha * 255.0)
	return table


## The frame as RGBA, composited bottom to top with layer opacity. `colors` lets exports
## use a cycled palette; pass the document palette otherwise.
static func composite_rgba(doc: PrismDocument, frame_index: int, colors: PackedColorArray) -> Image:
	var result: Image = Image.create_empty(doc.width, doc.height, false, Image.FORMAT_RGBA8)
	for layer_index: int in doc.layers.size():
		var layer: Layer = doc.layers[layer_index]
		var cel: Cel = doc.get_cel(layer_index, frame_index)
		if not layer.visible or cel == null or layer.opacity == 0:
			continue
		var source: IndexedImage = doc.images[cel.image_id]
		var layer_image: Image = to_rgba(source, color_table(colors, doc.transparent_index, layer.opacity / 255.0))
		result.blend_rect(layer_image, Rect2i(Vector2i.ZERO, source.get_size()), cel.offset)
	return result


## Indices -> RGBA through a color table.
static func to_rgba(source: IndexedImage, table: PackedByteArray) -> Image:
	var px: PackedByteArray = source.pixels
	var rgba: PackedByteArray = PackedByteArray()
	var resize_error: int = rgba.resize(px.size() * 4)
	assert(resize_error == OK)
	for i: int in px.size():
		var t: int = px[i] * 4
		var o: int = i * 4
		rgba[o] = table[t]
		rgba[o + 1] = table[t + 1]
		rgba[o + 2] = table[t + 2]
		rgba[o + 3] = table[t + 3]
	return Image.create_from_data(source.width, source.height, false, Image.FORMAT_RGBA8, rgba)


## The frame as palette indices: the topmost visible non-transparent index wins. Layer opacity
## cannot be expressed in indices and is ignored (GIF export).
static func composite_indices(doc: PrismDocument, frame_index: int) -> IndexedImage:
	var result: IndexedImage = IndexedImage.new(&"composite", doc.width, doc.height, doc.transparent_index)
	var out: PackedByteArray = result.pixels
	var w: int = doc.width
	for layer_index: int in doc.layers.size():
		var layer: Layer = doc.layers[layer_index]
		var cel: Cel = doc.get_cel(layer_index, frame_index)
		if not layer.visible or cel == null or layer.opacity == 0:
			continue
		var source: IndexedImage = doc.images[cel.image_id]
		var area: Rect2i = Rect2i(cel.offset, source.get_size()).intersection(result.get_rect())
		var src: PackedByteArray = source.pixels
		var transparent: int = doc.transparent_index
		for y: int in range(area.position.y, area.end.y):
			var src_row: int = (y - cel.offset.y) * source.width - cel.offset.x
			var dst_row: int = y * w
			for x: int in range(area.position.x, area.end.x):
				var value: int = src[src_row + x]
				if value != transparent:
					out[dst_row + x] = value
	return result


## Nearest-neighbor upscale by an integer factor (1 = unchanged).
static func scaled(image: Image, factor: int) -> Image:
	if factor <= 1:
		return image
	var copy: Image = image.duplicate() as Image
	copy.resize(image.get_width() * factor, image.get_height() * factor, Image.INTERPOLATE_NEAREST)
	return copy
