## Documents that exercise every saved feature, for round-trip and export tests.
class_name SampleDocuments
extends RefCounted


## 3 frames x 2 layers, linked cels, an offset cel, tags, cycles, stencil, ramps, durations,
## hidden + semi-transparent layer, renamed layer.
static func rich() -> PrismDocument:
	var fx: AppFixture = AppFixture.new(12, 8)
	fx.timeline.rename_layer(0, "Body \"main\"")
	fx.timeline.add_layer()
	fx.timeline.rename_layer(1, "Ink")
	fx.timeline.set_layer_opacity(1, 200)
	fx.timeline.insert_frame(1)
	fx.timeline.duplicate_frame(1, true)
	fx.timeline.set_duration(Vector2i(1, 1), 250)
	for f: int in 3:
		for layer: int in 2:
			var image: IndexedImage = fx.image_at(layer, f)
			image.set_index(1 + f * 3, 2 + layer * 3, 9 + layer)
			image.set_index(2 + f * 3, 3 + layer * 3, 27)
	fx.bus.document.get_cel(0, 0).offset = Vector2i(1, -1)
	var _walk: int = fx.timeline.add_tag(Vector2i(0, 1), "walk")
	var hop: int = fx.timeline.add_tag(Vector2i(2, 2), "hop")
	fx.timeline.update_tag(hop, "hop", Vector2i(1, 2), PrismEnums.TagDirection.PING_PONG, Color("#ff8a3d"))
	var _c: String = fx.palette.add_cycle(16, 21, 12.0, 1)
	var _d: String = fx.palette.add_cycle(8, 11, 4.0, -1)
	fx.palette.toggle_lock(1)
	fx.palette.toggle_lock(30)
	fx.timeline.set_layer_visible(1, true)
	return fx.bus.document
