extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


## Reference GIF LZW decoder (GIF89a appendix F), written independently of the encoder.
func _decode(data: PackedByteArray, min_code_size: int) -> PackedByteArray:
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
		for b: int in code_size:
			var bit: int = (data[(bit_pos + b) >> 3] >> ((bit_pos + b) & 7)) & 1
			code |= bit << b
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
		if has_prev and table.size() < GifLzw.MAX_CODE:
			var added: PackedByteArray = prev.duplicate()
			added.append(entry[0])
			table.append(added)
			if table.size() == (1 << code_size) and code_size < 12:
				code_size += 1
		prev = entry
		has_prev = true
	return out


func _round_trip(indices: PackedByteArray, colors: int) -> void:
	var mcs: int = GifLzw.min_code_size_for(colors)
	var decoded: PackedByteArray = _decode(GifLzw.encode(indices, mcs), mcs)
	assert_int(decoded.size()).is_equal(indices.size())
	assert_bool(decoded == indices).override_failure_message("round trip mismatch (%d colors, %d px)" % [colors, indices.size()]).is_true()


func test_min_code_size() -> void:
	assert_int(GifLzw.min_code_size_for(2)).is_equal(2)
	assert_int(GifLzw.min_code_size_for(4)).is_equal(2)
	assert_int(GifLzw.min_code_size_for(5)).is_equal(3)
	assert_int(GifLzw.min_code_size_for(32)).is_equal(5)
	assert_int(GifLzw.min_code_size_for(256)).is_equal(8)


func test_tiny_inputs() -> void:
	_round_trip(PackedByteArray([3]), 4)
	_round_trip(PackedByteArray([1, 1]), 4)
	_round_trip(PackedByteArray([0, 1, 0, 1, 0, 1, 0]), 2)


func test_uniform_image_compresses_well() -> void:
	var indices: PackedByteArray = PackedByteArray()
	indices.resize(256 * 256)
	indices.fill(7)
	var encoded: PackedByteArray = GifLzw.encode(indices, 5)
	assert_int(encoded.size()).is_less(2000)
	_round_trip(indices, 32)


func test_random_data_including_table_resets() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for colors: int in [2, 4, 16, 32, 256]:
		rng.seed = colors
		var indices: PackedByteArray = PackedByteArray()
		indices.resize(40000)
		for i: int in indices.size():
			indices[i] = rng.randi_range(0, colors - 1)
		_round_trip(indices, colors)


func test_sub_blocks() -> void:
	var data: PackedByteArray = PackedByteArray()
	data.resize(600)
	var blocks: PackedByteArray = GifLzw.to_sub_blocks(data)
	assert_int(blocks.size()).is_equal(600 + 3 + 1)
	assert_int(blocks[0]).is_equal(255)
	assert_int(blocks[256]).is_equal(255)
	assert_int(blocks[512]).is_equal(90)
	assert_int(blocks[blocks.size() - 1]).is_equal(0)
