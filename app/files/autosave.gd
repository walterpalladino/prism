## Autosave and crash recovery (GDD §5.1, §9.6).
##
## Every `interval_s` seconds with unsaved changes, the document is copied on the main thread
## (a fast native buffer copy) and serialized + zipped on a WorkerThreadPool task, so painting
## never waits for the disk. A lock file marks a running session: if it is still there at the
## next start, PRISM did not exit cleanly and the autosave can be recovered.
## All file access goes through the DocumentRepository.
class_name Autosave
extends RefCounted

const DEFAULT_INTERVAL_S: float = 60.0

var session: DocumentSession
var repository: DocumentRepository
var directory: String
var interval_s: float = DEFAULT_INTERVAL_S
var enabled: bool = true

var _elapsed: float = 0.0
var _saved_revision: int = -1
var _task: int = -1
var _last_error: String = ""
var _mutex: Mutex = Mutex.new()


func _init(p_session: DocumentSession, p_repository: DocumentRepository, p_directory: String = "user://autosave/") -> void:
	session = p_session
	repository = p_repository
	directory = p_directory.trim_suffix("/") + "/"


func autosave_path() -> String:
	return directory + "autosave.prism"


func lock_path() -> String:
	return directory + "session.lock"


## Call at startup. Returns true if the previous session crashed and left an autosave.
func begin_session() -> bool:
	var crashed: bool = repository.exists(lock_path()) and repository.exists(autosave_path())
	var _error: String = repository.write_text(lock_path(), Time.get_datetime_string_from_system())
	return crashed


## Call on a clean exit: removes the lock and the autosave.
func end_session() -> void:
	wait()
	repository.remove(lock_path())
	discard()


func load_recovered() -> DocumentResult:
	return repository.load_document(autosave_path())


## Deletes the autosave (after a successful save, or when recovery is declined).
func discard() -> void:
	repository.remove(autosave_path())
	_saved_revision = session.bus.revision


func tick(delta_s: float) -> void:
	if not enabled:
		return
	_elapsed += delta_s
	if _elapsed < interval_s:
		return
	_elapsed = 0.0
	var _started: bool = save_now()


## Starts an autosave now if there is unsaved work and none is running. Returns true if started.
func save_now() -> bool:
	if is_saving() or not session.has_unsaved_changes() or session.bus.revision == _saved_revision:
		return false
	_saved_revision = session.bus.revision
	var snapshot: PrismDocument = session.bus.document.duplicate_document()
	_task = WorkerThreadPool.add_task(_write.bind(snapshot), false, "PRISM autosave")
	return true


func is_saving() -> bool:
	if _task == -1:
		return false
	if WorkerThreadPool.is_task_completed(_task):
		var _waited: int = WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		return false
	return true


## Blocks until a running autosave finishes.
func wait() -> void:
	if _task != -1:
		var _waited: int = WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func last_error() -> String:
	_mutex.lock()
	var error: String = _last_error
	_mutex.unlock()
	return error


## Runs on a worker thread: only touches the snapshot it was given.
func _write(snapshot: PrismDocument) -> void:
	var error: String = repository.save_document(snapshot, autosave_path())
	_mutex.lock()
	_last_error = error
	_mutex.unlock()

