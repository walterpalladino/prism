extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func _round_trip(indices: PackedByteArray, colors: int) -> void:
	var mcs: int = GifLzw.min_code_size_for(colors)
	var decoded: PackedByteArray = GifReader.decode_lzw(GifLzw.encode(indices, mcs), mcs)
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
