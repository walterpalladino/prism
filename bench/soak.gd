## Soak test (GDD §10 M7, §13 criterion 2): random editing + autosave + save/reload for a long
## time, checking for data loss. Defaults to 120 minutes; set PRISM_SOAK_MINUTES to change.
##   PRISM_SOAK_MINUTES=120 godot --headless --path . -s res://bench/soak.gd
## Exits with code 1 on the first problem and prints how to reproduce it (the seed).
extends SceneTree

const DIR: String = "user://soak/"
const SAVE_EVERY: int = 150
const UNDO_CHECK_EVERY: int = 400

var _fx: AppFixture
var _repo: ZipDocumentRepository
var _session: DocumentSession
var _autosave: Autosave
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _deadline_ms: int
var _ops: int = 0
var _saves: int = 0
var _autosaves: int = 0
var _undo_checks: int = 0
var _autosave_expected: String = ""
var _seed: int
## Debugging: stop after this many ops and run the undo/redo check (0 = run by time).
var _max_ops: int = 0
var _trace: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	var minutes: float = float(OS.get_environment("PRISM_SOAK_MINUTES")) if OS.get_environment("PRISM_SOAK_MINUTES") != "" else 120.0
	_seed = int(OS.get_environment("PRISM_SOAK_SEED")) if OS.get_environment("PRISM_SOAK_SEED") != "" else int(Time.get_unix_time_from_system())
	_rng.seed = _seed
	_max_ops = int(OS.get_environment("PRISM_SOAK_OPS")) if OS.get_environment("PRISM_SOAK_OPS") != "" else 0
	_deadline_ms = Time.get_ticks_msec() + roundi(minutes * 60000.0)
	_fx = AppFixture.new(32, 32)
	_repo = ZipDocumentRepository.new()
	_session = DocumentSession.new(_fx.bus, _repo)
	_autosave = Autosave.new(_session, _repo, DIR + "autosave")
	_autosave.interval_s = 0.5
	var _crashed: bool = _autosave.begin_session()
	print("PRISM soak test: %.1f min, seed %d" % [minutes, _seed])


func _process(delta: float) -> bool:
	for i: int in 25:
		if _max_ops > 0 and _ops >= _max_ops:
			var ok: bool = _check_undo_redo()
			print("OPS %d: %s; last ops: %s" % [_ops, "undo/redo OK" if ok else "UNDO/REDO MISMATCH", ", ".join(_trace.slice(maxi(0, _trace.size() - 12)))])
			quit(0 if ok else 1)
			return true
		_random_op()
		_ops += 1
		var invalid: PackedStringArray = DocumentValidator.validate(_fx.bus.document)
		if not invalid.is_empty():
			return _fail("invalid document after op %d: %s" % [_ops, invalid[0]])
		if _max_ops == 0 and _ops % SAVE_EVERY == 0 and not _check_save_reload():
			return true
		if _max_ops == 0 and _ops % UNDO_CHECK_EVERY == 0 and not _check_undo_redo():
			return true
	if _max_ops == 0 and not _check_autosave(delta):
		return true
	if Time.get_ticks_msec() >= _deadline_ms:
		_autosave.end_session()
		print("SOAK PASSED: %d ops, %d save/reload checks, %d autosaves verified, %d undo/redo-all checks" % [_ops, _saves, _autosaves, _undo_checks])
		return true
	if _ops % 5000 < 25:
		print("  %d ops, %d saves, %d autosaves, %d undo checks, %.1f min left" % [_ops, _saves, _autosaves, _undo_checks, (_deadline_ms - Time.get_ticks_msec()) / 60000.0])
	return false


func _random_op() -> void:
	var doc: PrismDocument = _fx.bus.document
	var layers: int = doc.layers.size()
	var frames: int = doc.frames.size()
	var layer: int = _rng.randi_range(0, layers - 1)
	var frame: int = _rng.randi_range(0, frames - 1)
	_fx.state.set_layer(layer)
	_fx.state.set_frame(frame)
	var p: Vector2i = Vector2i(_rng.randi_range(-2, 33), _rng.randi_range(-2, 33))
	var q: Vector2i = Vector2i(_rng.randi_range(-2, 33), _rng.randi_range(-2, 33))
	var op: int = _rng.randi_range(0, 19)
	_trace.append_array([str(op)])
	match op:
		0:
			if layers < 6:
				_fx.timeline.add_layer()
		1:
			var _deleted: bool = _fx.timeline.delete_layer(layer)
		2:
			if frames < 12:
				_fx.timeline.duplicate_frame(frame, _rng.randf() < 0.5)
		3:
			var _deleted: bool = _fx.timeline.delete_frame(frame)
		4:
			_fx.timeline.move_frame(frame, _rng.randi_range(0, frames - 1))
		5:
			var _linked: bool = _fx.timeline.link_cels(layer, Vector2i(0, frames - 1))
		6:
			var _unlinked: bool = _fx.timeline.unlink_cel(layer, frame)
		7:
			var _tag: int = _fx.timeline.add_tag(Vector2i(0, frame)) if doc.tags.size() < 4 else -1
		8:
			_fx.timeline.set_duration(Vector2i(0, frame), _rng.randi_range(20, 400))
		9:
			_fx.palette.set_color(_rng.randi_range(0, 31), Color(_rng.randf(), _rng.randf(), _rng.randf()))
		10:
			_fx.palette.reorder(_rng.randi_range(0, 31), _rng.randi_range(0, 31), _rng.randf() < 0.5)
		11:
			_fx.palette.toggle_lock(_rng.randi_range(1, 31))
		12:
			var _error: String = _fx.palette.add_cycle(_rng.randi_range(0, 28), _rng.randi_range(0, 31), 8.0, 1)
		13:
			var _undone: bool = _fx.bus.undo()
		14:
			var _redone: bool = _fx.bus.redo()
		15:
			_fx.state.filled_shapes = _rng.randf() < 0.5
			var shapes: Array[StringName] = [&"line", &"rect", &"ellipse"]
			_fx.stroke(shapes[_rng.randi_range(0, 2)], [p, q])
		16:
			_fx.click(&"fill", p)
		_:
			_fx.state.set_fg(_rng.randi_range(1, 31))
			_fx.state.set_draw_mode(PrismEnums.DrawMode.SHADE if _rng.randf() < 0.2 else PrismEnums.DrawMode.COLOR)
			_fx.state.set_builtin_brush(Brush.Shape.ROUND, _rng.randi_range(1, 4))
			_fx.stroke(&"pencil", [p, q, Vector2i(_rng.randi_range(0, 31), _rng.randi_range(0, 31))])


func _check_save_reload() -> bool:
	var path: String = DIR + "soak.prism"
	var expected: String = DocFingerprint.of(_fx.bus.document)
	var error: String = _session.save_as(path)
	if error != "":
		return not _fail("save failed: " + error)
	var loaded: DocumentResult = _repo.load_document(path)
	if not loaded.is_ok():
		return not _fail("reload failed: " + loaded.error)
	var got: String = DocFingerprint.of(loaded.document)
	if got != expected:
		return not _fail("saved document differs from the one in memory after %d ops\n%s" % [_ops, _diff(expected, got)])
	_saves += 1
	return true


func _check_autosave(delta: float) -> bool:
	if _autosave_expected != "" and not _autosave.is_saving():
		var recovered: DocumentResult = _autosave.load_recovered()
		if not recovered.is_ok():
			return not _fail("autosave unreadable: " + recovered.error)
		var got: String = DocFingerprint.of(recovered.document)
		if got != _autosave_expected:
			return not _fail("autosave does not match the document at the time it was taken\n" + _diff(_autosave_expected, got))
		if _autosave.last_error() != "":
			return not _fail("autosave error: " + _autosave.last_error())
		_autosaves += 1
		_autosave_expected = ""
	if _autosave_expected == "" and _session.has_unsaved_changes():
		var snapshot_fingerprint: String = DocFingerprint.of(_fx.bus.document)
		_autosave.tick(delta + _autosave.interval_s)
		if _autosave.is_saving():
			_autosave_expected = snapshot_fingerprint
	return true


func _check_undo_redo() -> bool:
	var final: String = DocFingerprint.of(_fx.bus.document)
	var steps: int = 0
	while _fx.bus.undo():
		steps += 1
	# Redo exactly what was undone: entries already on the redo stack must stay undone.
	for i: int in steps:
		var _redone: bool = _fx.bus.redo()
	var got: String = DocFingerprint.of(_fx.bus.document)
	if got != final:
		return not _fail("undo-all/redo-all over %d steps changed the document\n%s" % [steps, _diff(final, got)])
	_undo_checks += 1
	return true


## The first few lines that differ between two fingerprints.
func _diff(expected: String, got: String) -> String:
	var a: PackedStringArray = expected.split("\n")
	var b: PackedStringArray = got.split("\n")
	var lines: PackedStringArray = PackedStringArray()
	for i: int in maxi(a.size(), b.size()):
		var left: String = a[i] if i < a.size() else "<none>"
		var right: String = b[i] if i < b.size() else "<none>"
		if left != right and lines.size() < 6:
			lines.append_array(["  expected: " + left, "  got:      " + right])
	return "\n".join(lines)


func _fail(message: String) -> bool:
	_autosave.wait()
	push_error("SOAK FAILED after %d ops: %s (reproduce with PRISM_SOAK_SEED=%d)" % [_ops, message, _seed])
	print("SOAK FAILED after %d ops: %s (reproduce with PRISM_SOAK_SEED=%d)" % [_ops, message, _seed])
	quit(1)
	return true
