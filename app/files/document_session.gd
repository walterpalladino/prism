## The open document's file: path, unsaved-changes tracking, open / save / save as
## (GDD §5.1, §7.12). File access goes through a DocumentRepository.
class_name DocumentSession
extends RefCounted

## The document's path or dirty state changed (window title, menus).
signal changed()

const EXTENSION: String = "prism"
const UNTITLED: String = "Untitled"

var bus: CommandBus
var repository: DocumentRepository
## "" until the document has been saved or was opened from a file.
var path: String = ""

var _saved_revision: int = 0


func _init(p_bus: CommandBus, p_repository: DocumentRepository) -> void:
	bus = p_bus
	repository = p_repository
	_saved_revision = bus.revision
	Signals.on(bus.history_changed, _on_history_changed)


func has_unsaved_changes() -> bool:
	return bus.revision != _saved_revision


func display_name() -> String:
	return UNTITLED if path == "" else path.get_file()


## "name.prism*" when there are unsaved changes.
func title() -> String:
	return display_name() + ("*" if has_unsaved_changes() else "")


## Replaces the document with a new unsaved one (caller asks about unsaved changes first).
func start_new(doc: PrismDocument) -> void:
	bus.replace_document(doc)
	path = ""
	_saved_revision = bus.revision
	changed.emit()


## Opens a document. Returns "" or an error message (the current document is kept on error).
func open(p_path: String) -> String:
	var result: DocumentResult = repository.load_document(p_path)
	if not result.is_ok():
		return result.error
	bus.replace_document(result.document)
	path = p_path
	_saved_revision = bus.revision
	changed.emit()
	return ""


## Opens a recovered document as unsaved work (it has no path).
func open_recovered(doc: PrismDocument) -> void:
	bus.replace_document(doc)
	path = ""
	_saved_revision = bus.revision - 1
	changed.emit()


## Saves to the current path. Returns "" or an error; fails if there is no path yet.
func save() -> String:
	if path == "":
		return "choose where to save first"
	return save_as(path)


func save_as(p_path: String) -> String:
	var target: String = with_extension(p_path)
	var error: String = repository.save_document(bus.document, target)
	if error != "":
		return error
	path = target
	_saved_revision = bus.revision
	changed.emit()
	return ""


static func with_extension(p_path: String) -> String:
	return p_path if p_path.get_extension().to_lower() == EXTENSION else p_path + "." + EXTENSION


func _on_history_changed() -> void:
	changed.emit()
