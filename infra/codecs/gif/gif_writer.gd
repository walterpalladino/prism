## Animated GIF89a encoder (GDD §7.12): global palette, per-frame delays, transparency, loop
## forever. With cycling baked in, each frame carries a local color table with that moment's
## cycled palette (pixels stay the same; only the table rotates, as in PRISM itself).
class_name GifWriter
extends RefCounted

## Browsers treat delays under 2 cs as 10 cs, so never write less.
const MIN_DELAY_CS: int = 2


## Encodes the schedule. Layer opacity is ignored (GIF has no partial transparency).
static func encode(doc: PrismDocument, options: ExportOptions) -> PackedByteArray:
	var schedule: Array[Vector3i] = options.schedule(doc)
	var size: Vector2i = Vector2i(doc.width, doc.height) * options.scale
	var table_bits: int = maxi(1, ceili(log(float(maxi(doc.palette.size(), 2))) / log(2.0)))
	var out: PackedByteArray = PackedByteArray()
	out.append_array("GIF89a".to_ascii_buffer())
	_u16(out, size.x)
	_u16(out, size.y)
	_byte(out, 0x80 | (7 << 4) | (table_bits - 1))
	_byte(out, doc.transparent_index)
	_byte(out, 0)
	out.append_array(_color_table(doc.palette.colors, table_bits))
	# NETSCAPE2.0 application extension: loop forever.
	out.append_array(PackedByteArray([0x21, 0xFF, 0x0B]))
	out.append_array("NETSCAPE2.0".to_ascii_buffer())
	out.append_array(PackedByteArray([0x03, 0x01, 0x00, 0x00, 0x00]))
	var min_code_size: int = maxi(2, table_bits)
	var emitted_cs: int = 0
	for entry: Vector3i in schedule:
		# Round the frame's end time, not its length, so delays never drift.
		var end_cs: int = roundi((entry.y + entry.z) / 10.0)
		var delay: int = maxi(MIN_DELAY_CS, end_cs - emitted_cs)
		emitted_cs += delay
		# Graphic control extension: disposal 2 (restore to background), transparency on.
		out.append_array(PackedByteArray([0x21, 0xF9, 0x04, (2 << 2) | 1]))
		_u16(out, delay)
		_byte(out, doc.transparent_index)
		_byte(out, 0)
		# Image descriptor (+ local color table when cycling is baked in).
		_byte(out, 0x2C)
		_u16(out, 0)
		_u16(out, 0)
		_u16(out, size.x)
		_u16(out, size.y)
		if options.bake_cycles and not doc.cycles.is_empty():
			_byte(out, 0x80 | (table_bits - 1))
			out.append_array(_color_table(ColorCycler.cycled_colors(doc.palette.colors, doc.cycles, entry.y / 1000.0), table_bits))
		else:
			_byte(out, 0)
		var indices: IndexedImage = FrameCompositor.composite_indices(doc, entry.x)
		var pixels: PackedByteArray = indices.pixels
		if options.scale > 1:
			var l8: Image = Image.create_from_data(indices.width, indices.height, false, Image.FORMAT_L8, pixels)
			l8.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
			pixels = l8.get_data()
		_byte(out, min_code_size)
		out.append_array(GifLzw.to_sub_blocks(GifLzw.encode(pixels, min_code_size)))
	_byte(out, 0x3B)
	return out


static func write(doc: PrismDocument, options: ExportOptions, sink: FileSink, path: String) -> String:
	var target: String = path if path.get_extension().to_lower() == "gif" else path + ".gif"
	return sink.write_bytes(target, encode(doc, options))


static func _color_table(colors: PackedColorArray, bits: int) -> PackedByteArray:
	var table: PackedByteArray = PackedByteArray()
	var resize_error: int = table.resize(3 * (1 << bits))
	assert(resize_error == OK)
	for i: int in mini(colors.size(), 1 << bits):
		table[i * 3] = colors[i].r8
		table[i * 3 + 1] = colors[i].g8
		table[i * 3 + 2] = colors[i].b8
	return table


static func _u16(out: PackedByteArray, value: int) -> void:
	_byte(out, value & 0xFF)
	_byte(out, (value >> 8) & 0xFF)


static func _byte(out: PackedByteArray, value: int) -> void:
	@warning_ignore("return_value_discarded")
	out.append(value)
