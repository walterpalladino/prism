extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")  # gdUnit4 fluent asserts return self


func test_new_stencil_locks_nothing() -> void:
	var stencil: Stencil = Stencil.new()
	assert_bool(stencil.has_any()).is_false()
	assert_int(stencil.locked.size()).is_equal(256)


func test_set_toggle_and_clear() -> void:
	var stencil: Stencil = Stencil.new()
	stencil.set_locked(3, true)
	stencil.toggle(4)
	assert_bool(stencil.is_locked(3)).is_true()
	assert_bool(stencil.is_locked(4)).is_true()
	stencil.toggle(4)
	assert_bool(stencil.is_locked(4)).is_false()
	assert_that(stencil.locked_indices()).is_equal(PackedInt32Array([3]))
	stencil.clear()
	assert_bool(stencil.has_any()).is_false()


func test_invert() -> void:
	var stencil: Stencil = Stencil.new()
	stencil.set_locked(1, true)
	stencil.invert()
	assert_bool(stencil.is_locked(1)).is_false()
	assert_int(stencil.locked_indices().size()).is_equal(255)


func test_lock_all_except() -> void:
	var stencil: Stencil = Stencil.new()
	stencil.lock_all_except(9)
	assert_bool(stencil.is_locked(9)).is_false()
	assert_bool(stencil.is_locked(0)).is_true()
	assert_bool(stencil.is_locked(255)).is_true()


func test_duplicate_is_independent() -> void:
	var stencil: Stencil = Stencil.new()
	var copy: Stencil = stencil.duplicate_stencil()
	copy.set_locked(2, true)
	assert_bool(stencil.is_locked(2)).is_false()
