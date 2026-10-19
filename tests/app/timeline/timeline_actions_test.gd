extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func _fx() -> AppFixture:
	return AppFixture.new(4, 4)


func _doc(fx: AppFixture) -> PrismDocument:
	return fx.bus.document


func _valid(fx: AppFixture) -> void:
	assert_array(DocumentValidator.validate(_doc(fx))).is_empty()
	for layer: int in _doc(fx).layers.size():
		for frame: int in _doc(fx).frames.size():
			assert_bool(_doc(fx).has_cel(layer, frame)).override_failure_message("missing cel %d,%d" % [layer, frame]).is_true()


func _undo_restores(fx: AppFixture, before: String) -> void:
	fx.bus.undo()
	assert_str(DocFingerprint.of(_doc(fx))).is_equal(before)
	_valid(fx)


# --- layers ------------------------------------------------------------------

func test_add_layer_above_current_and_undo() -> void:
	var fx: AppFixture = _fx()
	var before: String = DocFingerprint.of(_doc(fx))
	fx.timeline.add_layer()
	assert_int(_doc(fx).layers.size()).is_equal(2)
	assert_int(fx.state.layer_index).is_equal(1)
	assert_str(_doc(fx).layers[1].layer_name).is_equal("Layer 2")
	assert_str(fx.bus.history.undo_label()).is_equal("New Layer")
	_valid(fx)
	_undo_restores(fx, before)
	assert_int(fx.state.layer_index).is_equal(0)


func test_delete_layer_keeps_at_least_one() -> void:
	var fx: AppFixture = _fx()
	assert_bool(fx.timeline.delete_layer(0)).is_false()
	fx.timeline.add_layer()
	var before: String = DocFingerprint.of(_doc(fx))
	assert_bool(fx.timeline.delete_layer(1)).is_true()
	assert_int(_doc(fx).images.size()).is_equal(1)
	_valid(fx)
	_undo_restores(fx, before)


func test_duplicate_layer_copies_pixels_and_keeps_links() -> void:
	var fx: AppFixture = _fx()
	fx.timeline.duplicate_frame(0, true)
	fx.image().set_index(1, 1, 7)
	fx.timeline.duplicate_layer(0)
	var doc: PrismDocument = _doc(fx)
	assert_str(doc.layers[1].layer_name).is_equal("Layer 1 copy")
	assert_int(doc.get_cel_image(1, 0).get_index(1, 1)).is_equal(7)
	assert_str(String(doc.get_cel(1, 0).image_id)).is_not_equal(String(doc.get_cel(0, 0).image_id))
	assert_str(String(doc.get_cel(1, 0).image_id)).is_equal(String(doc.get_cel(1, 1).image_id))
	doc.get_cel_image(1, 0).set_index(0, 0, 3)
	assert_int(doc.get_cel_image(0, 0).get_index(0, 0)).is_equal(0)
	_valid(fx)


func test_layer_properties_and_move() -> void:
	var fx: AppFixture = _fx()
	fx.timeline.add_layer()
	fx.timeline.rename_layer(1, "  Ink  ")
	fx.timeline.rename_layer(1, "")
	fx.timeline.set_layer_visible(1, false)
	fx.timeline.set_layer_locked(1, true)
	fx.timeline.set_layer_opacity(1, 300)
	var layer: Layer = _doc(fx).layers[1]
	assert_str(layer.layer_name).is_equal("Ink")
	assert_bool(layer.visible).is_false()
	assert_bool(layer.locked).is_true()
	assert_int(layer.opacity).is_equal(255)
	fx.timeline.set_layer_opacity(1, 128)
	assert_int(_doc(fx).layers[1].opacity).is_equal(128)
	var before: String = DocFingerprint.of(_doc(fx))
	fx.timeline.move_layer(1, 0)
	assert_str(_doc(fx).layers[0].layer_name).is_equal("Ink")
	assert_int(fx.state.layer_index).is_equal(0)
	_valid(fx)
	_undo_restores(fx, before)
	fx.timeline.set_layer_visible(1, false)
	fx.timeline.move_layer(0, 0)
	fx.timeline.move_layer(0, 9)
	assert_str(fx.bus.history.undo_label()).is_equal("Layer Opacity")


# --- frames ------------------------------------------------------------------

func test_insert_frame_and_undo() -> void:
	var fx: AppFixture = _fx()
	fx.timeline.add_layer()
	var before: String = DocFingerprint.of(_doc(fx))
	fx.timeline.insert_frame(1)
	assert_int(_doc(fx).frames.size()).is_equal(2)
	assert_int(fx.state.frame_index).is_equal(1)
	assert_bool(_doc(fx).is_image_empty(_doc(fx).get_cel(1, 1).image_id)).is_true()
	_valid(fx)
	_undo_restores(fx, before)
	assert_int(fx.state.frame_index).is_equal(0)


func test_duplicate_frame_deep_and_linked() -> void:
	var fx: AppFixture = _fx()
	fx.image().set_index(2, 2, 9)
	fx.timeline.duplicate_frame(0, false)
	var doc: PrismDocument = _doc(fx)
	assert_int(doc.get_cel_image(0, 1).get_index(2, 2)).is_equal(9)
	assert_bool(fx.timeline.is_linked(0, 1)).is_false()
	fx.timeline.duplicate_frame(1, true)
	assert_bool(fx.timeline.is_linked(0, 2)).is_true()
	doc.get_cel_image(0, 2).set_index(0, 0, 5)
	assert_int(doc.get_cel_image(0, 1).get_index(0, 0)).is_equal(5)
	assert_int(doc.get_cel_image(0, 0).get_index(0, 0)).is_equal(0)
	assert_str(fx.bus.history.undo_label()).is_equal("Duplicate Frame (Linked)")
	_valid(fx)


func test_delete_and_move_frame() -> void:
	var fx: AppFixture = _fx()
	assert_bool(fx.timeline.delete_frame(0)).is_false()
	fx.timeline.insert_frame(1)
	fx.timeline.insert_frame(2)
	var ids: Array[StringName] = [_doc(fx).frames[0].id, _doc(fx).frames[1].id, _doc(fx).frames[2].id]
	var before: String = DocFingerprint.of(_doc(fx))
	fx.timeline.move_frame(0, 2)
	assert_array([_doc(fx).frames[0].id, _doc(fx).frames[1].id, _doc(fx).frames[2].id]).is_equal([ids[1], ids[2], ids[0]])
	assert_int(fx.state.frame_index).is_equal(2)
	_valid(fx)
	_undo_restores(fx, before)
	assert_bool(fx.timeline.delete_frame(1)).is_true()
	assert_int(_doc(fx).frames.size()).is_equal(2)
	_valid(fx)


func test_set_duration_for_a_range() -> void:
	var fx: AppFixture = _fx()
	fx.timeline.insert_frame(1)
	fx.timeline.insert_frame(2)
	fx.timeline.set_duration(Vector2i(1, 2), 250)
	assert_array([_doc(fx).frames[0].duration_ms, _doc(fx).frames[1].duration_ms, _doc(fx).frames[2].duration_ms]).is_equal([100, 250, 250])
	fx.timeline.set_duration(Vector2i(1, 2), 250)
	fx.timeline.set_duration(Vector2i(0, 0), 0)
	assert_int(_doc(fx).frames[0].duration_ms).is_equal(TimelineActions.MIN_DURATION_MS)
	assert_int(fx.bus.history.undo_count()).is_equal(4)


func test_navigation_wraps() -> void:
	var fx: AppFixture = _fx()
	fx.timeline.insert_frame(1)
	fx.state.set_frame(1)
	fx.timeline.next_frame()
	assert_int(fx.state.frame_index).is_equal(0)
	fx.timeline.previous_frame()
	assert_int(fx.state.frame_index).is_equal(1)


func test_new_frames_inherit_duration() -> void:
	var fx: AppFixture = _fx()
	fx.timeline.set_duration(Vector2i(0, 0), 80)
	fx.timeline.insert_frame(1)
	assert_int(_doc(fx).frames[1].duration_ms).is_equal(80)


# --- tags --------------------------------------------------------------------

func test_tags_follow_frame_inserts_and_deletes() -> void:
	var fx: AppFixture = _fx()
	for i: int in 4:
		fx.timeline.insert_frame(i + 1)
	var idle: int = fx.timeline.add_tag(Vector2i(0, 1), "idle")
	var walk: int = fx.timeline.add_tag(Vector2i(3, 4))
	assert_str(_doc(fx).tags[walk].tag_name).is_equal("tag2")
	assert_that(_doc(fx).tags[idle].color).is_not_equal(_doc(fx).tags[walk].color)
	fx.timeline.insert_frame(1)
	assert_array([_doc(fx).tags[0].from_frame, _doc(fx).tags[0].to_frame, _doc(fx).tags[1].from_frame, _doc(fx).tags[1].to_frame]).is_equal([0, 2, 4, 5])
	fx.timeline.delete_frame(0)
	fx.timeline.delete_frame(0)
	fx.timeline.delete_frame(0)
	assert_int(_doc(fx).tags.size()).is_equal(1)
	assert_array([_doc(fx).tags[0].from_frame, _doc(fx).tags[0].to_frame]).is_equal([1, 2])
	_valid(fx)


func test_update_and_delete_tag() -> void:
	var fx: AppFixture = _fx()
	fx.timeline.insert_frame(1)
	var index: int = fx.timeline.add_tag(Vector2i(0, 0), "a")
	fx.timeline.update_tag(index, "hop", Vector2i(9, 0), PrismEnums.TagDirection.PING_PONG, Color.RED)
	var tag: Tag = _doc(fx).tags[0]
	assert_str(tag.tag_name).is_equal("hop")
	assert_array([tag.from_frame, tag.to_frame]).is_equal([0, 1])
	assert_int(tag.direction).is_equal(PrismEnums.TagDirection.PING_PONG)
	fx.timeline.update_tag(index, "  ", Vector2i(0, 0), PrismEnums.TagDirection.FORWARD, Color.RED)
	assert_str(_doc(fx).tags[0].tag_name).is_equal("hop")
	fx.timeline.update_tag(7, "x", Vector2i.ZERO, PrismEnums.TagDirection.FORWARD, Color.RED)
	fx.timeline.delete_tag(0)
	fx.timeline.delete_tag(0)
	assert_bool(_doc(fx).tags.is_empty()).is_true()


# --- cels --------------------------------------------------------------------

func test_link_and_unlink() -> void:
	var fx: AppFixture = _fx()
	fx.timeline.insert_frame(1)
	fx.timeline.insert_frame(2)
	assert_bool(fx.timeline.link_cels(0, Vector2i(0, 0))).is_false()
	var before: String = DocFingerprint.of(_doc(fx))
	assert_bool(fx.timeline.link_cels(0, Vector2i(0, 2))).is_true()
	assert_bool(fx.timeline.link_cels(0, Vector2i(0, 2))).is_false()
	assert_int(_doc(fx).images.size()).is_equal(1)
	_doc(fx).get_cel_image(0, 2).set_index(3, 3, 4)
	assert_int(_doc(fx).get_cel_image(0, 0).get_index(3, 3)).is_equal(4)
	assert_bool(fx.timeline.unlink_cel(0, 1)).is_true()
	assert_bool(fx.timeline.is_linked(0, 1)).is_false()
	assert_int(_doc(fx).get_cel_image(0, 1).get_index(3, 3)).is_equal(4)
	_doc(fx).get_cel_image(0, 1).set_index(0, 0, 6)
	assert_int(_doc(fx).get_cel_image(0, 0).get_index(0, 0)).is_equal(0)
	assert_bool(fx.timeline.unlink_cel(0, 1)).is_false()
	_valid(fx)
	fx.bus.undo()
	_doc(fx).get_cel_image(0, 0).set_index(3, 3, 0)
	_doc(fx).get_cel_image(0, 1).set_index(0, 0, 0)
	_undo_restores(fx, before)


func test_clear_copy_paste_cel() -> void:
	var fx: AppFixture = _fx()
	fx.timeline.insert_frame(1)
	fx.image().set_index(1, 2, 8)
	assert_bool(fx.timeline.paste_cel(0, 1)).is_false()
	assert_bool(fx.timeline.copy_cel(0, 0)).is_true()
	assert_bool(fx.timeline.paste_cel(0, 1)).is_true()
	assert_int(fx.image_at(0, 1).get_index(1, 2)).is_equal(8)
	assert_bool(fx.timeline.clear_cel(0, 0)).is_true()
	assert_bool(_doc(fx).is_image_empty(_doc(fx).get_cel(0, 0).image_id)).is_true()
	assert_bool(fx.timeline.clear_cel(0, 0)).is_false()
	assert_str(fx.bus.history.undo_label()).is_equal("Clear Cel")
	fx.bus.undo()
	assert_int(fx.image().get_index(1, 2)).is_equal(8)
	assert_bool(fx.timeline.copy_cel(5, 0)).is_false()


func test_painting_targets_the_current_frame_and_layer() -> void:
	var fx: AppFixture = _fx()
	fx.timeline.insert_frame(1)
	fx.timeline.add_layer()
	fx.state.set_fg(5)
	fx.click(&"pencil", Vector2i(1, 1))
	assert_int(fx.image_at(1, 1).get_index(1, 1)).is_equal(5)
	assert_int(fx.image_at(0, 1).get_index(1, 1)).is_equal(0)
	assert_int(fx.image_at(1, 0).get_index(1, 1)).is_equal(0)


func test_undo_clamps_the_selection() -> void:
	var fx: AppFixture = _fx()
	fx.timeline.insert_frame(1)
	fx.timeline.add_layer()
	assert_int(fx.state.frame_index).is_equal(1)
	fx.bus.undo()
	fx.bus.undo()
	assert_int(fx.state.frame_index).is_equal(0)
	assert_int(fx.state.layer_index).is_equal(0)
	assert_that(fx.state.frame_range).is_equal(Vector2i.ZERO)


func test_random_timeline_ops_undo_and_redo_all() -> void:
	for s: int in 15:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 900 + s
		var fx: AppFixture = AppFixture.new(6, 6)
		var original: String = DocFingerprint.of(_doc(fx))
		for i: int in 40:
			var layers: int = _doc(fx).layers.size()
			var frames: int = _doc(fx).frames.size()
			var layer: int = rng.randi_range(0, layers - 1)
			var frame: int = rng.randi_range(0, frames - 1)
			fx.state.set_layer(layer)
			fx.state.set_frame(frame)
			match rng.randi_range(0, 13):
				0: fx.timeline.add_layer()
				1: fx.timeline.delete_layer(layer)
				2: fx.timeline.duplicate_layer(layer)
				3: fx.timeline.move_layer(layer, rng.randi_range(0, layers - 1))
				4: fx.timeline.insert_frame(rng.randi_range(0, frames))
				5: fx.timeline.duplicate_frame(frame, rng.randf() < 0.5)
				6: fx.timeline.delete_frame(frame)
				7: fx.timeline.move_frame(frame, rng.randi_range(0, frames - 1))
				8: fx.timeline.link_cels(layer, Vector2i(0, frames - 1))
				9: fx.timeline.unlink_cel(layer, frame)
				10: fx.timeline.add_tag(Vector2i(0, frame))
				11: fx.timeline.set_duration(Vector2i(0, frame), rng.randi_range(10, 300))
				12: fx.timeline.clear_cel(layer, frame)
				_:
					fx.state.set_fg(rng.randi_range(1, 31))
					fx.stroke(&"pencil", [Vector2i(rng.randi_range(0, 5), rng.randi_range(0, 5)), Vector2i(rng.randi_range(0, 5), rng.randi_range(0, 5))])
			assert_array(DocumentValidator.validate(_doc(fx))).override_failure_message("seed %d step %d" % [s, i]).is_empty()
		var final: String = DocFingerprint.of(_doc(fx))
		while fx.bus.undo():
			pass
		assert_str(DocFingerprint.of(_doc(fx))).override_failure_message("seed %d undo-all" % s).is_equal(original)
		while fx.bus.redo():
			pass
		assert_str(DocFingerprint.of(_doc(fx))).override_failure_message("seed %d redo-all" % s).is_equal(final)
