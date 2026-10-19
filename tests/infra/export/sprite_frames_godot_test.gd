## M6 exit: a generated SpriteFrames opens in Godot 4.7 and every tag plays correctly on an
## AnimatedSprite2D. Exports into a throwaway Godot project, imports it with a second Godot
## process, then plays each animation there at a fixed 60 fps and compares the frames shown
## with the PRISM durations.
extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self
@warning_ignore_start("unsafe_cast", "unsafe_call_argument", "unsafe_method_access")  # parses untyped JSON from the child process

const TICKS: int = 180
const TICK_MS: float = 1000.0 / 60.0

const CHECK_SCRIPT: String = """extends SceneTree

var sprite: AnimatedSprite2D
var frames: SpriteFrames
var names: PackedStringArray
var current: int = -1
var tick: int = 0
var result: Dictionary = {}

func _initialize() -> void:
	frames = load("res://anim/hero.tres") as SpriteFrames
	if frames == null:
		print("RESULT:" + JSON.stringify({"error": "could not load"}))
		quit()
		return
	names = frames.get_animation_names()
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	root.add_child(sprite)
	for animation_name in names:
		var durations: Array = []
		var regions: Array = []
		for i in frames.get_frame_count(animation_name):
			durations.append(frames.get_frame_duration(animation_name, i))
			var texture: AtlasTexture = frames.get_frame_texture(animation_name, i) as AtlasTexture
			regions.append([texture.region.position.x, texture.region.position.y, texture.region.size.x, texture.region.size.y] if texture else null)
		result[animation_name] = {"speed": frames.get_animation_speed(animation_name), "loop": frames.get_animation_loop(animation_name), "durations": durations, "regions": regions, "shown": []}
	_next()

func _next() -> void:
	current += 1
	tick = 0
	if current >= names.size():
		print("RESULT:" + JSON.stringify(result))
		quit()
		return
	sprite.play(names[current])

func _process(_delta: float) -> bool:
	if current < names.size() and current >= 0:
		result[names[current]]["shown"].append(sprite.frame)
		tick += 1
		if tick >= %d:
			_next()
	return false
""" % TICKS


func _run(godot: String, args: PackedStringArray) -> String:
	var output: Array = []
	var code: int = OS.execute(godot, args, output, true)
	assert_int(code).override_failure_message("godot %s failed:\\n%s" % [" ".join(args), "\\n".join(output)]).is_equal(0)
	return "\\n".join(output)


func test_sprite_frames_play_in_godot() -> void:
	var doc: PrismDocument = SampleDocuments.rich()
	var project: String = OS.get_user_data_dir().path_join("sprite_frames_e2e_%d" % Time.get_ticks_usec())
	var sink: DiskFileSink = DiskFileSink.new()
	sink.write_text(project.path_join("project.godot"), "config_version=5\n\n[application]\n\nconfig/name=\"e2e\"\nconfig/features=PackedStringArray(\"4.7\", \"GL Compatibility\")\n\n[rendering]\n\nrenderer/rendering_method=\"gl_compatibility\"\n")
	sink.write_text(project.path_join("check.gd"), CHECK_SCRIPT)
	assert_str(SpriteFramesWriter.write(doc, 1, sink, project.path_join("anim/hero.tres"))).is_empty()

	var godot: String = OS.get_executable_path()
	_run(godot, ["--headless", "--path", project, "--import"])
	var output: String = _run(godot, ["--headless", "--path", project, "--fixed-fps", "60", "-s", "res://check.gd"])
	var line_start: int = output.find("RESULT:")
	assert_int(line_start).override_failure_message("no result from Godot:\\n" + output).is_not_equal(-1)
	var json_text: String = output.substr(line_start + 7).split("\\n")[0]
	var result: Dictionary = JSON.parse_string(json_text)
	assert_bool(result.has("error")).override_failure_message(str(result.get("error", ""))).is_false()
	assert_array(result.keys()).contains_exactly_in_any_order(["walk", "hop"])

	for tag: Tag in doc.tags:
		var animation: Dictionary = result[tag.tag_name]
		var order: PackedInt32Array = FrameSchedule.play_order(Vector2i(tag.from_frame, tag.to_frame), tag.direction)
		assert_bool(animation["loop"]).is_true()
		var durations: Array = animation["durations"]
		assert_int(durations.size()).is_equal(order.size())
		# Each frame lasts duration / speed seconds in Godot: must equal the PRISM duration.
		for i: int in order.size():
			var godot_ms: float = float(durations[i]) / float(animation["speed"]) * 1000.0
			assert_float(godot_ms).is_equal_approx(doc.frames[order[i]].duration_ms, 0.5)
			assert_array(animation["regions"][i]).is_not_empty()
		# Frame shown on each 60 fps tick vs the ideal timeline (one tick of slack at boundaries).
		var shown: Array = animation["shown"]
		var loop_ms: int = FrameSchedule.loop_ms(doc, order)
		var mismatches: int = 0
		for t: int in shown.size():
			var ms: float = fmod(t * TICK_MS, loop_ms)
			var expected: int = _position_at(doc, order, ms)
			var near_boundary: bool = _position_at(doc, order, fmod(ms + TICK_MS * 1.5, loop_ms)) != expected or _position_at(doc, order, fmod(ms - TICK_MS * 1.5 + loop_ms, loop_ms)) != expected
			if int(shown[t]) != expected and not near_boundary:
				mismatches += 1
		assert_int(mismatches).override_failure_message("tag %s: %d ticks showed the wrong frame: %s" % [tag.tag_name, mismatches, shown]).is_equal(0)
		var distinct: Dictionary = {}
		for value: Variant in shown:
			distinct[int(value)] = true
		assert_int(distinct.size()).is_equal(order.size())
	_remove_tree(project)


## Deletes a folder tree, including hidden folders such as the child project's .godot/.
func _remove_tree(dir: String) -> void:
	var access: DirAccess = DirAccess.open(dir)
	if access == null:
		return
	access.include_hidden = true
	for sub: String in access.get_directories():
		_remove_tree(dir.path_join(sub))
	for file: String in access.get_files():
		DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)


## Position in `order` (not the frame index) showing at `ms`.
func _position_at(doc: PrismDocument, order: PackedInt32Array, ms: float) -> int:
	var t: float = 0.0
	for i: int in order.size():
		t += doc.frames[order[i]].duration_ms
		if ms < t:
			return i
	return order.size() - 1
