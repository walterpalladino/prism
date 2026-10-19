## File access for import/export (GDD §9.2 rule 4). DiskFileSink uses the file system;
## MemoryFileSink keeps files in memory for tests.
@abstract
class_name FileSink
extends RefCounted


## Writes `bytes` to `path` (creating folders); returns "" or an error message.
@abstract func write_bytes(path: String, bytes: PackedByteArray) -> String
## The file's bytes, or an empty array if it cannot be read.
@abstract func read_bytes(path: String) -> PackedByteArray
## The nearest folder at or above `directory` that contains `file_name`, or "".
@abstract func find_upwards(directory: String, file_name: String) -> String


func write_text(path: String, text: String) -> String:
	return write_bytes(path, text.to_utf8_buffer())


func write_png(path: String, image: Image) -> String:
	return write_bytes(path, image.save_png_to_buffer())
