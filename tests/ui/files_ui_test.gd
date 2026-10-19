## Windowed checks for file handling in the main window (skipped under --headless).
extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self

var _runner: GdUnitSceneRunner


func before_test() -> void:
	EditorContext.new_document(Vector2i(16, 16))
	_runner = scene_runner("res://ui/scenes/main.tscn")
	await _runner.simulate_frames(3)


func test_title_shows_name_and_unsaved_marker(do_skip: bool = DisplayServer.get_name() == "headless", skip_reason: String = "needs a window") -> void:
	var window: Window = (_runner.scene() as Control).get_window()
	assert_str(window.title).is_equal("PRISM — Untitled")
	EditorContext.tools.activate(&"pencil")
	EditorContext.tools.press(Vector2i(1, 1), PrismEnums.PaintButton.PRIMARY, 0)
	EditorContext.tools.release(Vector2i(1, 1), 0)
	await _runner.simulate_frames(1)
	assert_str(window.title).is_equal("PRISM — Untitled*")


func test_new_document_asks_before_discarding(do_skip: bool = DisplayServer.get_name() == "headless", skip_reason: String = "needs a window") -> void:
	EditorContext.tools.activate(&"pencil")
	EditorContext.tools.press(Vector2i(1, 1), PrismEnums.PaintButton.PRIMARY, 0)
	EditorContext.tools.release(Vector2i(1, 1), 0)
	var before: PrismDocument = EditorContext.bus.document
	_runner.scene().call("run_action", "new_32")
	await _runner.simulate_frames(2)
	var dialogs: Array[Node] = _runner.scene().find_children("*", "ConfirmationDialog", true, false)
	var prompt: ConfirmationDialog = null
	for node: Node in dialogs:
		var dialog: ConfirmationDialog = node as ConfirmationDialog
		if dialog.title == "Unsaved changes" and dialog.visible:
			prompt = dialog
	assert_object(prompt).is_not_null()
	assert_object(EditorContext.bus.document).is_same(before)
	prompt.get_ok_button().pressed.emit()
	await _runner.simulate_frames(2)
	assert_int(EditorContext.bus.document.width).is_equal(32)
