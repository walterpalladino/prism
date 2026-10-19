extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func _setup() -> Array:
	var fx: AppFixture = AppFixture.new(8, 8)
	var repo: MemoryDocumentRepository = MemoryDocumentRepository.new()
	return [fx, repo, DocumentSession.new(fx.bus, repo)]


func test_new_session_is_clean_and_untitled() -> void:
	var parts: Array = _setup()
	var session: DocumentSession = parts[2]
	assert_bool(session.has_unsaved_changes()).is_false()
	assert_str(session.title()).is_equal("Untitled")
	assert_str(session.save()).contains("choose where")


func test_edits_make_it_dirty_and_save_cleans() -> void:
	var parts: Array = _setup()
	var fx: AppFixture = parts[0]
	var repo: MemoryDocumentRepository = parts[1]
	var session: DocumentSession = parts[2]
	var changes: Array[int] = [0]
	Signals.on(session.changed, func() -> void: changes[0] += 1)
	fx.click(&"pencil", Vector2i(1, 1))
	assert_bool(session.has_unsaved_changes()).is_true()
	assert_str(session.title()).is_equal("Untitled*")
	assert_str(session.save_as("/art/hero")).is_empty()
	assert_str(session.path).is_equal("/art/hero.prism")
	assert_bool(repo.exists("/art/hero.prism")).is_true()
	assert_str(session.title()).is_equal("hero.prism")
	fx.bus.undo()
	assert_bool(session.has_unsaved_changes()).is_true()
	assert_str(session.save()).is_empty()
	assert_bool(session.has_unsaved_changes()).is_false()
	assert_int(changes[0]).is_greater(2)


func test_open_replaces_document_and_errors_keep_it() -> void:
	var parts: Array = _setup()
	var fx: AppFixture = parts[0]
	var repo: MemoryDocumentRepository = parts[1]
	var session: DocumentSession = parts[2]
	repo.save_document(SampleDocuments.rich(), "/rich.prism")
	var before: PrismDocument = fx.bus.document
	assert_str(session.open("/missing.prism")).contains("not found")
	assert_object(fx.bus.document).is_same(before)
	assert_str(session.open("/rich.prism")).is_empty()
	assert_int(fx.bus.document.frames.size()).is_equal(3)
	assert_bool(session.has_unsaved_changes()).is_false()
	assert_bool(fx.bus.history.can_undo()).is_false()


func test_save_failure_keeps_dirty_state() -> void:
	var parts: Array = _setup()
	var fx: AppFixture = parts[0]
	var repo: MemoryDocumentRepository = parts[1]
	var session: DocumentSession = parts[2]
	fx.click(&"pencil", Vector2i(1, 1))
	repo.fail_saves_with = "disk full"
	assert_str(session.save_as("/x.prism")).is_equal("disk full")
	assert_str(session.path).is_empty()
	assert_bool(session.has_unsaved_changes()).is_true()


func test_start_new_and_recovered() -> void:
	var parts: Array = _setup()
	var session: DocumentSession = parts[2]
	session.save_as("/a.prism")
	session.start_new(PrismDocument.create(4, 4))
	assert_str(session.path).is_empty()
	assert_bool(session.has_unsaved_changes()).is_false()
	session.open_recovered(PrismDocument.create(4, 4))
	assert_bool(session.has_unsaved_changes()).is_true()
	assert_str(DocumentSession.with_extension("a.PRISM")).is_equal("a.PRISM")
	assert_str(DocumentSession.with_extension("a.png")).is_equal("a.png.prism")
