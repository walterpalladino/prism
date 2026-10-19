## Golden-file helpers. Goldens are text files under res://tests/golden/, one hex digit per pixel.
## Run tests with PRISM_UPDATE_GOLDEN=1 to (re)write missing or changed goldens, then review the diff.
class_name Golden
extends RefCounted

const ROOT: String = "res://tests/golden/"


## Returns the golden text for `name`, writing `actual` first when updating is enabled.
static func expect(name: String, actual: String) -> String:
	var path: String = ROOT + name + ".txt"
	if OS.get_environment("PRISM_UPDATE_GOLDEN") == "1":
		var dir_error: int = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		assert(dir_error == OK)
		var out: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		var stored: bool = out.store_string(actual)
		assert(stored)
		out.close()
	if not FileAccess.file_exists(path):
		return "<missing golden %s>" % path
	return FileAccess.get_file_as_string(path)


static func image_text(image: IndexedImage) -> String:
	return "\n".join(image.to_rows()) + "\n"


## Plots `points` with index 1 on a blank w x h image.
static func points_text(points: Array[Vector2i], w: int, h: int) -> String:
	var image: IndexedImage = IndexedImage.new(&"golden", w, h)
	for p: Vector2i in points:
		image.set_index(p.x, p.y, 1)
	return image_text(image)


## Returns the golden PNG for `name` (null if missing), writing `actual` first when updating.
static func expect_png(name: String, actual: Image) -> Image:
	var path: String = ROOT + name + ".png"
	if OS.get_environment("PRISM_UPDATE_GOLDEN") == "1":
		var dir_error: int = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		assert(dir_error == OK)
		var save_error: int = actual.save_png(path)
		assert(save_error == OK)
	if not FileAccess.file_exists(path):
		return null
	var expected: Image = Image.new()
	if expected.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		return null
	expected.convert(Image.FORMAT_RGBA8)
	return expected


## Number of pixels whose channels differ by more than `tolerance` (0-255); -1 on size mismatch.
static func pixel_differences(a: Image, b: Image, tolerance: int = 2) -> int:
	if a == null or b == null or a.get_size() != b.get_size():
		return -1
	var differences: int = 0
	var da: PackedByteArray = a.get_data()
	var db: PackedByteArray = b.get_data()
	for i: int in range(0, da.size(), 4):
		for c: int in 4:
			if absi(da[i + c] - db[i + c]) > tolerance:
				differences += 1
				break
	return differences
