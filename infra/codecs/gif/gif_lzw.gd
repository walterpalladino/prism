## GIF variable-length LZW compression (GIF89a spec, appendix F).
##
## The string table is a flat PackedInt32Array indexed by (prefix << 8 | byte)
## instead of a Dictionary: ~1M slots (4 MB), cleared with a native fill().
## See docs/adr/0003-cpu-hot-paths.md for the measurements behind this choice.
class_name GifLzw
extends RefCounted

const MAX_CODE: int = 4096


## Minimum LZW code size for a palette of `color_count` entries (GIF requires >= 2).
static func min_code_size_for(color_count: int) -> int:
	var bits: int = 2
	while (1 << bits) < color_count:
		bits += 1
	return bits


## Compresses palette indices into a raw LZW code stream (not yet split into sub-blocks).
static func encode(indices: PackedByteArray, min_code_size: int) -> PackedByteArray:
	var clear_code: int = 1 << min_code_size
	var eoi_code: int = clear_code + 1
	var next_code: int = eoi_code + 1
	var code_size: int = min_code_size + 1
	var table: PackedInt32Array = PackedInt32Array()
	var resize_error: int = table.resize(MAX_CODE << 8)
	assert(resize_error == OK)

	var out: PackedByteArray = PackedByteArray()
	var bit_buffer: int = 0
	var bit_count: int = 0

	bit_buffer |= clear_code << bit_count
	bit_count += code_size
	if indices.is_empty():
		bit_buffer |= eoi_code << bit_count
		bit_count += code_size
		return _flush(out, bit_buffer, bit_count)

	var prefix: int = indices[0]
	var n: int = indices.size()
	for i: int in range(1, n):
		var k: int = indices[i]
		var key: int = (prefix << 8) | k
		var code: int = table[key]
		if code != 0:
			prefix = code
			continue
		bit_buffer |= prefix << bit_count
		bit_count += code_size
		while bit_count >= 8:
			@warning_ignore("return_value_discarded")
			out.append(bit_buffer & 0xff)
			bit_buffer >>= 8
			bit_count -= 8
		if next_code == MAX_CODE:
			bit_buffer |= clear_code << bit_count
			bit_count += code_size
			table.fill(0)
			next_code = eoi_code + 1
			code_size = min_code_size + 1
		else:
			if next_code >= (1 << code_size):
				code_size += 1
			table[key] = next_code
			next_code += 1
		prefix = k

	bit_buffer |= prefix << bit_count
	bit_count += code_size
	if next_code >= (1 << code_size) and code_size < 12:
		code_size += 1
	bit_buffer |= eoi_code << bit_count
	bit_count += code_size
	return _flush(out, bit_buffer, bit_count)


## Splits a code stream into GIF data sub-blocks (<= 255 bytes each) plus the 0 terminator.
static func to_sub_blocks(data: PackedByteArray) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	var offset: int = 0
	while offset < data.size():
		var length: int = mini(255, data.size() - offset)
		@warning_ignore("return_value_discarded")
		out.append(length)
		out.append_array(data.slice(offset, offset + length))
		offset += length
	@warning_ignore("return_value_discarded")
	out.append(0)
	return out


static func _flush(out: PackedByteArray, bit_buffer: int, bit_count: int) -> PackedByteArray:
	var buffer: int = bit_buffer
	var count: int = bit_count
	while count > 0:
		@warning_ignore("return_value_discarded")
		out.append(buffer & 0xff)
		buffer >>= 8
		count -= 8
	return out
