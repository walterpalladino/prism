extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func _setup() -> Array:
	var fx: AppFixture = AppFixture.new(8, 8)
	var repo: MemoryDocumentRepository = MemoryDocumentRepository.new()
	var session: DocumentSession = DocumentSession.new(fx.bus, repo)
	return [fx, repo, session, Autosave.new(session, repo, "mem://autosave")]


func test_clean_start_then_crash_detection() -> void:
	var parts: Array = _setup()
	var repo: MemoryDocumentRepository = parts[1]
	var autosave: Autosave = parts[3]
	assert_bool(autosave.begin_session()).is_false()
	assert_bool(repo.exists(autosave.lock_path())).is_true()
	repo.save_document(PrismDocument.create(2, 2), autosave.autosave_path())
	assert_bool(autosave.begin_session()).override_failure_message("lock + autosave left behind = crash").is_true()
	assert_bool(autosave.load_recovered().is_ok()).is_true()
	autosave.end_session()
	assert_bool(repo.exists(autosave.lock_path())).is_false()
	assert_bool(repo.exists(autosave.autosave_path())).is_false()
	assert_bool(autosave.begin_session()).is_false()


func test_saves_only_unsaved_changes_on_a_worker_thread() -> void:
	var parts: Array = _setup()
	var fx: AppFixture = parts[0]
	var repo: MemoryDocumentRepository = parts[1]
	var autosave: Autosave = parts[3]
	autosave.begin_session()
	assert_bool(autosave.save_now()).is_false()
	fx.click(&"pencil", Vector2i(2, 2))
	assert_bool(autosave.save_now()).is_true()
	assert_bool(autosave.save_now()).is_false()
	autosave.wait()
	assert_bool(autosave.is_saving()).is_false()
	assert_str(autosave.last_error()).is_empty()
	var recovered: DocumentResult = autosave.load_recovered()
	assert_int(recovered.document.get_cel_image(0, 0).get_index(2, 2)).is_equal(fx.state.fg)
	assert_bool(repo.exists(autosave.autosave_path())).is_true()


func test_snapshot_is_independent_of_later_edits() -> void:
	var parts: Array = _setup()
	var fx: AppFixture = parts[0]
	var autosave: Autosave = parts[3]
	fx.click(&"pencil", Vector2i(3, 3))
	autosave.save_now()
	fx.image().set_index(3, 3, 0)
	autosave.wait()
	assert_int(autosave.load_recovered().document.get_cel_image(0, 0).get_index(3, 3)).is_equal(fx.state.fg)


func test_interval_and_disabled() -> void:
	var parts: Array = _setup()
	var fx: AppFixture = parts[0]
	var repo: MemoryDocumentRepository = parts[1]
	var autosave: Autosave = parts[3]
	autosave.interval_s = 1.0
	fx.click(&"pencil", Vector2i(1, 1))
	autosave.tick(0.5)
	autosave.wait()
	assert_bool(repo.exists(autosave.autosave_path())).is_false()
	autosave.tick(0.6)
	autosave.wait()
	assert_bool(repo.exists(autosave.autosave_path())).is_true()
	autosave.discard()
	fx.click(&"pencil", Vector2i(2, 1))
	autosave.enabled = false
	autosave.tick(5.0)
	autosave.wait()
	assert_bool(repo.exists(autosave.autosave_path())).is_false()


func test_deep_copy_document() -> void:
	var doc: PrismDocument = SampleDocuments.rich()
	var copy: PrismDocument = doc.duplicate_document()
	assert_str(DocFingerprint.of(copy)).is_equal(DocFingerprint.of(doc))
	copy.get_cel_image(0, 0).set_index(0, 0, 3)
	copy.layers[0].layer_name = "x"
	copy.cycles[0].rate_hz = 1.0
	assert_int(doc.get_cel_image(0, 0).get_index(0, 0)).is_equal(0)
	assert_str(doc.layers[0].layer_name).is_not_equal("x")
	assert_float(doc.cycles[0].rate_hz).is_equal(12.0)
