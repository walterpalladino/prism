extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self

const DIR: String = "user://test_prism_files/"


func after() -> void:
	for file: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + file)
	DirAccess.remove_absolute(DIR)


func test_save_and_load_round_trip_on_disk() -> void:
	var repo: ZipDocumentRepository = ZipDocumentRepository.new()
	var doc: PrismDocument = SampleDocuments.rich()
	assert_str(repo.save_document(doc, DIR + "rich.prism")).is_empty()
	assert_bool(repo.exists(DIR + "rich.prism")).is_true()
	assert_bool(FileAccess.file_exists(DIR + "rich.prism" + ZipDocumentRepository.TEMP_SUFFIX)).is_false()
	var result: DocumentResult = repo.load_document(DIR + "rich.prism")
	assert_str(result.error).is_empty()
	assert_str(DocFingerprint.of(result.document)).is_equal(DocFingerprint.of(doc))
	var zip: ZIPReader = ZIPReader.new()
	zip.open(DIR + "rich.prism")
	assert_bool(zip.get_files().has("document.json")).is_true()
	assert_int(Array(zip.get_files()).filter(func(n: String) -> bool: return n.begins_with("images/") and n.ends_with(".bin")).size()).is_equal(doc.images.size())
	zip.close()


func test_overwrite_existing_file() -> void:
	var repo: ZipDocumentRepository = ZipDocumentRepository.new()
	assert_str(repo.save_document(PrismDocument.create(4, 4), DIR + "over.prism")).is_empty()
	assert_str(repo.save_document(PrismDocument.create(8, 2), DIR + "over.prism")).is_empty()
	assert_int(repo.load_document(DIR + "over.prism").document.width).is_equal(8)
	repo.remove(DIR + "over.prism")
	assert_bool(repo.exists(DIR + "over.prism")).is_false()


func test_corrupt_files() -> void:
	var repo: ZipDocumentRepository = ZipDocumentRepository.new()
	assert_str(repo.load_document(DIR + "missing.prism").error).contains("not found")
	var junk: FileAccess = FileAccess.open(DIR + "junk.prism", FileAccess.WRITE)
	junk.store_string("this is not a zip")
	junk.close()
	assert_str(repo.load_document(DIR + "junk.prism").error).contains("not a PRISM file")
	repo.save_document(SampleDocuments.rich(), DIR + "cut.prism")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(DIR + "cut.prism")
	var cut: FileAccess = FileAccess.open(DIR + "cut.prism", FileAccess.WRITE)
	cut.store_buffer(bytes.slice(0, bytes.size() / 2))
	cut.close()
	assert_bool(repo.load_document(DIR + "cut.prism").is_ok()).is_false()
	var empty_zip: ZIPPacker = ZIPPacker.new()
	empty_zip.open(DIR + "empty.prism")
	empty_zip.start_file("readme.txt")
	empty_zip.write_file("hi".to_utf8_buffer())
	empty_zip.close_file()
	empty_zip.close()
	assert_str(repo.load_document(DIR + "empty.prism").error).contains("no document.json")
	assert_str(repo.write_text(DIR + "note.txt", "x")).is_empty()


func test_memory_repository() -> void:
	var repo: MemoryDocumentRepository = MemoryDocumentRepository.new()
	assert_str(repo.save_document(SampleDocuments.rich(), "a.prism")).is_empty()
	assert_bool(repo.load_document("a.prism").is_ok()).is_true()
	assert_str(repo.load_document("b.prism").error).contains("not found")
	repo.write_text("lock", "1")
	assert_bool(repo.exists("lock")).is_true()
	repo.remove("lock")
	repo.remove("a.prism")
	assert_bool(repo.exists("a.prism")).is_false()
	repo.fail_saves_with = "disk full"
	assert_str(repo.save_document(PrismDocument.create(1, 1), "c.prism")).is_equal("disk full")


func test_result_helpers() -> void:
	assert_bool(DocumentResult.ok(PrismDocument.create(1, 1)).is_ok()).is_true()
	assert_bool(DocumentResult.fail("x").is_ok()).is_false()
