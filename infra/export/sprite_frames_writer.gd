## Godot `SpriteFrames` export (GDD §1.1, §7.12): a sheet PNG plus a text `.tres` with one
## animation per tag (or "default" for all frames), AtlasTexture regions into the sheet and
## per-frame durations. Art goes from PRISM into a Godot game with no importer plugin.
##
## Godot plays a SpriteFrames frame for duration / speed seconds, so speed is set to
## 1000 / (the tag's shortest frame in ms) and each duration is frame_ms / shortest_ms.
class_name SpriteFramesWriter
extends RefCounted


## The .tres text. `sheet_res_path` is the sheet's res:// path inside the target project.
static func build_tres(doc: PrismDocument, sheet: SpriteSheet, sheet_res_path: String) -> String:
	var cell_of_frame: Dictionary[int, int] = {}
	for i: int in sheet.frame_indices.size():
		cell_of_frame[sheet.frame_indices[i]] = i
	var animations: Array[Dictionary] = []
	if doc.tags.is_empty():
		animations.append({"name": "default", "order": FrameSchedule.play_order(Vector2i(0, doc.frames.size() - 1), PrismEnums.TagDirection.FORWARD)})
	for tag: Tag in doc.tags:
		animations.append({"name": tag.tag_name, "order": FrameSchedule.play_order(Vector2i(tag.from_frame, tag.to_frame), tag.direction)})

	var lines: PackedStringArray = PackedStringArray()
	var sub_resources: PackedStringArray = PackedStringArray()
	for i: int in sheet.rects.size():
		var rect: Rect2i = sheet.rects[i]
		sub_resources.append_array([
			"[sub_resource type=\"AtlasTexture\" id=\"AtlasTexture_%d\"]" % i,
			"atlas = ExtResource(\"1_sheet\")",
			"region = Rect2(%d, %d, %d, %d)" % [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
			"",
		])
	lines.append_array([
		"[gd_resource type=\"SpriteFrames\" load_steps=%d format=3]" % (sheet.rects.size() + 2),
		"",
		"[ext_resource type=\"Texture2D\" path=\"%s\" id=\"1_sheet\"]" % sheet_res_path,
		"",
	])
	lines.append_array(sub_resources)
	var animation_texts: PackedStringArray = PackedStringArray()
	for animation: Dictionary in animations:
		var order: PackedInt32Array = animation["order"]
		var shortest: int = 1 << 30
		for index: int in order:
			shortest = mini(shortest, doc.frames[index].duration_ms)
		var frame_texts: PackedStringArray = PackedStringArray()
		for index: int in order:
			frame_texts.append_array(["{\n\"duration\": %s,\n\"texture\": SubResource(\"AtlasTexture_%d\")\n}" % [_number(doc.frames[index].duration_ms / float(shortest)), cell_of_frame[index]]])
		var animation_name: String = animation["name"]
		animation_texts.append_array(["{\n\"frames\": [%s],\n\"loop\": true,\n\"name\": &\"%s\",\n\"speed\": %s\n}" % [", ".join(frame_texts), animation_name.c_escape(), _number(1000.0 / shortest)]])
	lines.append_array(["[resource]", "animations = [%s]" % ", ".join(animation_texts)])
	return "\n".join(lines) + "\n"


## Writes `<path>.tres` and `<path>.png` (grid sheet). The path must be inside a Godot
## project (a folder with project.godot above it) so the texture gets a res:// path.
## Returns "" or an error.
static func write(doc: PrismDocument, scale: int, sink: FileSink, path: String) -> String:
	var tres_path: String = path.get_basename() + ".tres"
	var png_path: String = path.get_basename() + ".png"
	var project_root: String = sink.find_upwards(tres_path.get_base_dir(), "project.godot")
	if project_root == "":
		return "save the SpriteFrames inside a Godot project (a folder that contains project.godot) so the sheet gets a res:// path"
	var options: ExportOptions = ExportOptions.whole(doc)
	options.scale = scale
	options.layout = ExportOptions.Layout.GRID
	var sheet: SpriteSheet = SpriteSheet.pack(doc, options)
	var res_path: String = "res://" + png_path.simplify_path().trim_prefix(project_root.simplify_path()).trim_prefix("/")
	var error: String = sink.write_png(png_path, sheet.image)
	if error != "":
		return error
	return sink.write_text(tres_path, build_tres(doc, sheet, res_path))


## Godot's text format writes whole numbers as "1.0".
static func _number(value: float) -> String:
	var text: String = String.num(value, 6)
	return text if text.contains(".") else text + ".0"
