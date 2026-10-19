## Text summary of everything that defines a document, for "undo all == original" checks.
class_name DocFingerprint
extends RefCounted


static func of(doc: PrismDocument) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append_array(["size %dx%d transparent %d" % [doc.width, doc.height, doc.transparent_index]])
	for layer: Layer in doc.layers:
		lines.append_array(["layer %s '%s' v%s l%s o%d" % [layer.id, layer.layer_name, layer.visible, layer.locked, layer.opacity]])
	for frame: Frame in doc.frames:
		lines.append_array(["frame %s %d" % [frame.id, frame.duration_ms]])
	var keys: Array[Vector2i] = doc.cels.keys()
	keys.sort()
	for key: Vector2i in keys:
		var cel: Cel = doc.cels[key]
		lines.append_array(["cel %s %s/%s img %s off %s px %d" % [key, cel.layer_id, cel.frame_id, cel.image_id, cel.offset, hash(doc.images[cel.image_id].pixels)]])
	for tag: Tag in doc.tags:
		lines.append_array(["tag '%s' %d-%d dir %d %s" % [tag.tag_name, tag.from_frame, tag.to_frame, tag.direction, tag.color.to_html()]])
	lines.append_array(["palette %d" % hash(doc.palette.colors), "ramps %s" % [doc.palette.ramps], "stencil %d" % hash(doc.stencil.locked)])
	return "\n".join(lines)
