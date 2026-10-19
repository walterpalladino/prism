## Minimal GIF89a reader for tests, written independently of GifWriter/GifLzw.
class_name GifReader
extends RefCounted
@warning_ignore_start("return_value_discarded")  # Packed*Array.append in a test helper

var width: int
var height: int
var global_colors: PackedColorArray = PackedColorArray()
var loops_forever: bool = false
## Each frame: {"indices": PackedByteArray, "delay_cs": int, "transparent": int, "local_colors": PackedColorArray}
var frames: Array[Dictionary] = []
var error: String = ""


static func parse(bytes: PackedByteArray) -> GifReader:
	var gif: GifReader = GifReader.new()
	gif._parse(bytes)
	return gif


func _parse(b: PackedByteArray) -> void:
	if b.size() < 13 or b.slice(0, 6).get_string_from_ascii() != "GIF89a":
		error = "bad header"
		return
	width = b[6] | (b[7] << 8)
	height = b[8] | (b[9] << 8)
	var flags: int = b[10]
	var pos: int = 13
	if flags & 0x80:
		var count: int = 1 << ((flags & 7) + 1)
		global_colors = _colors(b, pos, count)
		pos += 3 * count
	var delay: int = 0
	var transparent: int = -1
	while pos < b.size():
		var marker: int = b[pos]
		pos += 1
		if marker == 0x3B:
			return
		if marker == 0x21:
			var label: int = b[pos]
			pos += 1
			if label == 0xF9:
				transparent = b[pos + 4] if b[pos + 1] & 1 else -1
				delay = b[pos + 2] | (b[pos + 3] << 8)
			if label == 0xFF and b.slice(pos + 1, pos + 12).get_string_from_ascii() == "NETSCAPE2.0":
				loops_forever = (b[pos + 14] | (b[pos + 15] << 8)) == 0
			pos = _skip_blocks(b, pos)
		elif marker == 0x2C:
			var w: int = b[pos + 4] | (b[pos + 5] << 8)
			var h: int = b[pos + 6] | (b[pos + 7] << 8)
			var image_flags: int = b[pos + 8]
			pos += 9
			var local: PackedColorArray = PackedColorArray()
			if image_flags & 0x80:
				var count: int = 1 << ((image_flags & 7) + 1)
				local = _colors(b, pos, count)
				pos += 3 * count
			var min_code: int = b[pos]
			pos += 1
			var data: PackedByteArray = PackedByteArray()
			while b[pos] != 0:
				data.append_array(b.slice(pos + 1, pos + 1 + b[pos]))
				pos += b[pos] + 1
			pos += 1
			var indices: PackedByteArray = decode_lzw(data, min_code)
			if indices.size() != w * h:
				error = "frame %d: %d pixels, expected %d" % [frames.size(), indices.size(), w * h]
			frames.append({"indices": indices, "delay_cs": delay, "transparent": transparent, "local_colors": local})
		else:
			error = "unexpected block 0x%x at %d" % [marker, pos - 1]
			return
	error = "missing trailer"


func _skip_blocks(b: PackedByteArray, start: int) -> int:
	var pos: int = start
	while b[pos] != 0:
		pos += b[pos] + 1
	return pos + 1


func _colors(b: PackedByteArray, start: int, count: int) -> PackedColorArray:
	var colors: PackedColorArray = PackedColorArray()
	for i: int in count:
		colors.append(Color8(b[start + i * 3], b[start + i * 3 + 1], b[start + i * 3 + 2]))
	return colors


## Reference GIF LZW decoder (GIF89a appendix F).
static func decode_lzw(data: PackedByteArray, min_code_size: int) -> PackedByteArray:
	var clear_code: int = 1 << min_code_size
	var eoi_code: int = clear_code + 1
	var code_size: int = min_code_size + 1
	var table: Array[PackedByteArray] = []
	var out: PackedByteArray = PackedByteArray()
	var prev: PackedByteArray = PackedByteArray()
	var has_prev: bool = false
	var bit_pos: int = 0
	var total_bits: int = data.size() * 8
	while bit_pos + code_size <= total_bits:
		var code: int = 0
		for bit_index: int in code_size:
			code |= ((data[(bit_pos + bit_index) >> 3] >> ((bit_pos + bit_index) & 7)) & 1) << bit_index
		bit_pos += code_size
		if code == clear_code:
			table.clear()
			for i: int in clear_code + 2:
				table.append(PackedByteArray([i & 0xff]))
			code_size = min_code_size + 1
			has_prev = false
			continue
		if code == eoi_code:
			break
		var entry: PackedByteArray
		if code < table.size():
			entry = table[code]
		else:
			entry = prev.duplicate()
			entry.append(prev[0])
		out.append_array(entry)
		if has_prev and table.size() < 4096:
			var added: PackedByteArray = prev.duplicate()
			added.append(entry[0])
			table.append(added)
			if table.size() == (1 << code_size) and code_size < 12:
				code_size += 1
		prev = entry
		has_prev = true
	return out
