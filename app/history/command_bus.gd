## Single entry point for document mutations. Owns the document and its history and
## tells listeners (views) what changed.
class_name CommandBus
extends RefCounted

## Something in the document changed. An empty rect means "refresh everything".
signal document_changed(dirty: Rect2i)
## Pixels of one image changed inside `dirty` (image space).
signal image_changed(image_id: StringName, dirty: Rect2i)
signal history_changed()
## Palette colors, order, ramps or stencil changed.
signal palette_changed()
## Pixels at `offsets` (row-major indices into image `image_id`) were left alone because their
## index is stencil-locked. Views may flash them (GDD §8.4).
signal stencil_blocked(image_id: StringName, offsets: PackedInt32Array)
## A different document was loaded or created; everything must rebuild.
signal document_replaced()

var document: PrismDocument
var history: History
## Increases on every recorded, undone or redone change; compared to detect unsaved work.
var revision: int = 0


func _init(p_document: PrismDocument, p_history: History) -> void:
	document = p_document
	history = p_history


## Applies a command and records it.
func execute(command: Command) -> void:
	command.apply(document)
	history.push(command)
	_notify(command)


## Records a command whose effect is already in the document (strokes paint live).
func record(command: Command) -> void:
	history.push(command)
	_notify(command)


func undo() -> bool:
	var command: Command = history.undo(document)
	if command == null:
		return false
	_notify(command)
	return true


func redo() -> bool:
	var command: Command = history.redo(document)
	if command == null:
		return false
	_notify(command)
	return true


## Live preview while a tool is mid-stroke; nothing is recorded.
func notify_image_changed(image_id: StringName, dirty: Rect2i) -> void:
	image_changed.emit(image_id, dirty)


## Live preview of a structural change (e.g. dragging a cel); nothing is recorded.
func notify_document_changed() -> void:
	document_changed.emit(Rect2i())


## Live preview of a palette edit (e.g. dragging a color slider); nothing is recorded.
func notify_palette_changed() -> void:
	palette_changed.emit()



func notify_stencil_blocked(image_id: StringName, offsets: PackedInt32Array) -> void:
	if not offsets.is_empty():
		stencil_blocked.emit(image_id, offsets)


func replace_document(p_document: PrismDocument) -> void:
	document = p_document
	revision += 1
	history.clear()
	document_replaced.emit()
	history_changed.emit()


func _notify(command: Command) -> void:
	revision += 1
	var image_id: StringName = command.get_image_id()
	var dirty: Rect2i = command.get_dirty_rect()
	if image_id != &"":
		image_changed.emit(image_id, dirty)
	if command.changes_palette():
		palette_changed.emit()
	document_changed.emit(dirty)
	history_changed.emit()
