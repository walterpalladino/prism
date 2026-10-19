## PNG import (GDD §7.12): RGBA pixels -> palette indices. Exact colors map directly; others
## go to the nearest palette entry (RGB distance); fully transparent pixels become the
## transparent index.
class_name PngImport
extends RefCounted


static func load_image(bytes: PackedByteArray) -> Image:
	var image: Image = Image.new()
	if bytes.is_empty() or image.load_png_from_buffer(bytes) != OK:
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image


## Maps `image` onto `palette`. `exact_count` (if given) receives how many pixels matched exactly.
static func to_indexed(image: Image, palette: Palette, transparent_index: int, p_id: StringName = &"import") -> IndexedImage:
	var result: IndexedImage = IndexedImage.new(p_id, image.get_width(), image.get_height(), transparent_index)
	var data: PackedByteArray = image.get_data()
	var cache: Dictionary[int, int] = {}
	var out: PackedByteArray = result.pixels
	for i: int in out.size():
		var o: int = i * 4
		if data[o + 3] < 128:
			continue
		var key: int = (data[o] << 16) | (data[o + 1] << 8) | data[o + 2]
		if not cache.has(key):
			cache[key] = nearest_index(palette, data[o], data[o + 1], data[o + 2], transparent_index)
		out[i] = cache[key]
	return result


static func nearest_index(palette: Palette, r: int, g: int, b: int, transparent_index: int) -> int:
	var best: int = 0
	var best_distance: int = 1 << 30
	for i: int in palette.size():
		if i == transparent_index:
			continue
		var c: Color = palette.get_color(i)
		var dr: int = c.r8 - r
		var dg: int = c.g8 - g
		var db: int = c.b8 - b
		var distance: int = dr * dr + dg * dg + db * db
		if distance < best_distance:
			best_distance = distance
			best = i
			if distance == 0:
				break
	return best


## A new document from a PNG. Uses the image's own colors as the palette when it has at most
## 255 opaque colors (index 0 stays transparent); otherwise maps onto `fallback`.
static func to_document(image: Image, fallback: Palette) -> DocumentResult:
	if image.get_width() > PrismDocument.MAX_CANVAS_SIZE or image.get_height() > PrismDocument.MAX_CANVAS_SIZE:
		return DocumentResult.fail("image is %dx%d; the maximum canvas is %d×%d" % [image.get_width(), image.get_height(), PrismDocument.MAX_CANVAS_SIZE, PrismDocument.MAX_CANVAS_SIZE])
	var extracted: PaletteResult = PaletteCodecs.decode_png_image(image)
	var palette: Palette = fallback.duplicate_palette()
	if extracted.is_ok() and extracted.palette.size() < Palette.MAX_COLORS:
		var colors: PackedColorArray = PackedColorArray([Color(0, 0, 0, 1)])
		colors.append_array(extracted.palette.colors)
		palette = Palette.new(colors)
	var doc: PrismDocument = PrismDocument.create(image.get_width(), image.get_height(), palette)
	var cel_image: IndexedImage = doc.get_cel_image(0, 0)
	cel_image.pixels = to_indexed(image, palette, doc.transparent_index, cel_image.id).pixels
	return DocumentResult.ok(doc)
