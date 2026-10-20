## Palette, ramp and stencil operations for the UI (GDD §7.4, §7.5). Every change is an
## undoable command. Color edits can be previewed live and committed as one undo step.
class_name PaletteActions
extends RefCounted

var bus: CommandBus
var state: EditorState

## Color edit being previewed: index and the color it had before the preview started.
var _pending_index: int = -1
var _pending_before: Color


func _init(p_bus: CommandBus, p_state: EditorState) -> void:
	bus = p_bus
	state = p_state


func palette() -> Palette:
	return bus.document.palette


# --- colors ------------------------------------------------------------------

## Shows `color` at `index` immediately without recording it; commit_color() records it.
func preview_color(index: int, color: Color) -> void:
	if _pending_index != index:
		commit_color()
		_pending_index = index
		_pending_before = palette().get_color(index)
	palette().set_color(index, color)
	bus.notify_palette_changed()


## Records the previewed edit (if any) as one undo step.
func commit_color() -> void:
	if _pending_index == -1:
		return
	var index: int = _pending_index
	_pending_index = -1
	var after: Color = palette().get_color(index)
	if after != _pending_before:
		bus.record(SetPaletteColorCommand.new(index, _pending_before, after))


## Abandons the previewed edit (if any), restoring the original color. Records nothing.
func cancel_preview() -> void:
	if _pending_index == -1:
		return
	palette().set_color(_pending_index, _pending_before)
	_pending_index = -1
	bus.notify_palette_changed()


func has_pending_edit() -> bool:
	return _pending_index != -1


func set_color(index: int, color: Color) -> void:
	commit_color()
	var quantized: Color = Palette.quantize(color)
	if palette().get_color(index) != quantized:
		bus.execute(SetPaletteColorCommand.new(index, palette().get_color(index), quantized))


## Moves entry `from` to `to`. With remap the picture is unchanged and FG/BG follow their colors.
func reorder(from: int, to: int, remap: bool) -> void:
	commit_color()
	var size: int = palette().size()
	if from == to or from < 0 or to < 0 or from >= size or to >= size:
		return
	var new_index_of: PackedByteArray = ReorderPaletteCommand.permutation(size, from, to)
	bus.execute(ReorderPaletteCommand.new(from, to, remap))
	if remap:
		state.fg = new_index_of[state.fg]
		state.bg = new_index_of[state.bg]
	state.changed.emit()


# --- adding and removing entries ---------------------------------------------

## Inserts `color` at position `index` (0..size). FG and BG follow their colors.
## Returns "" or why it was refused.
func insert_color(index: int, color: Color) -> String:
	commit_color()
	if palette().size() >= Palette.MAX_COLORS:
		return "The palette is full (%d colors)." % Palette.MAX_COLORS
	if index < 0 or index > palette().size():
		return "There is no palette position %d." % index
	bus.execute(InsertPaletteColorCommand.new(index, color))
	if state.fg >= index:
		state.fg += 1
	if state.bg >= index:
		state.bg += 1
	state.changed.emit()
	return ""


## "+": inserts a copy of the FG color right after it and makes the copy the FG.
func add_color_after_fg() -> String:
	var at: int = state.fg + 1
	var error: String = insert_color(at, palette().get_color(state.fg))
	if error == "":
		state.set_fg(at)
	return error


## Pixels (in every image) that use entry `index`.
func usage_count(index: int) -> int:
	var count: int = 0
	for image: IndexedImage in bus.document.images.values():
		count += image.pixels.count(index)
	return count


## Why entry `index` can never be removed, or "" (pixels using it can still be remapped).
func removal_blocker(index: int) -> String:
	if not palette().has_index(index):
		return "There is no palette entry %d." % index
	if palette().size() <= 1:
		return "A palette needs at least one color."
	if index == bus.document.transparent_index:
		return "Entry %d is the transparent color and cannot be removed." % index
	return ""


## Removes entry `index`. Pixels using it are repainted with `remap_to` (an index in the
## current palette), which is required when any pixel uses it, so the picture never changes
## silently. FG and BG follow their colors. Returns "" or why it was refused.
func remove_color(index: int, remap_to: int = -1) -> String:
	commit_color()
	var blocker: String = removal_blocker(index)
	if blocker != "":
		return blocker
	var target: int = remap_to if remap_to != index and palette().has_index(remap_to) else -1
	if target == -1 and usage_count(index) > 0:
		return "%d pixels use entry %d; choose a color to repaint them with." % [usage_count(index), index]
	bus.execute(RemovePaletteColorCommand.new(index, target))
	state.fg = _index_after_removal(state.fg, index, target)
	state.bg = _index_after_removal(state.bg, index, target)
	state.changed.emit()
	return ""


func _index_after_removal(value: int, removed: int, target: int) -> int:
	if value == removed and target != -1:
		value = target
	if value > removed:
		value -= 1
	return clampi(value, 0, palette().size() - 1)


## Replaces the palette (file load or preset). If the new palette is shorter than the highest
## index in use (pixels or color cycles), it is padded with the old colors so nothing points
## outside the palette. Returns the number of padded entries.
func load_palette(source: Palette, label: String = "Load Palette") -> int:
	commit_color()
	var replacement: Palette = source.duplicate_palette()
	var needed: int = highest_used_index() + 1
	for cycle: CycleRange in bus.document.cycles:
		needed = maxi(needed, cycle.end_index + 1)
	var padded: int = 0
	while replacement.size() < needed:
		@warning_ignore("return_value_discarded")
		replacement.colors.append(palette().get_color(replacement.size()))
		padded += 1
	bus.execute(ReplacePaletteCommand.new(palette(), replacement, label))
	state.set_fg(state.fg)
	state.set_bg(state.bg)
	return padded


func highest_used_index() -> int:
	var doc: PrismDocument = bus.document
	var highest: int = doc.transparent_index
	for image: IndexedImage in doc.images.values():
		for value: int in range(highest + 1, Palette.MAX_COLORS):
			if image.pixels.has(value):
				highest = value
	return highest


# --- ramps -------------------------------------------------------------------

## Makes the span between FG and BG (inclusive, either order) a shading ramp.
## Returns false if the span is a single entry or overlaps an existing ramp.
func add_ramp_between_fg_and_bg() -> bool:
	return add_ramp(mini(state.fg, state.bg), maxi(state.fg, state.bg))


func add_ramp(start: int, end: int) -> bool:
	commit_color()
	var edited: Palette = palette().duplicate_palette()
	if not edited.add_ramp(start, end):
		return false
	bus.execute(ReplacePaletteCommand.new(palette(), edited, "Add Ramp"))
	return true


## Removes the ramp containing `index`. Returns false if there is none.
func remove_ramp_at(index: int) -> bool:
	commit_color()
	var ramp: Vector2i = palette().find_ramp(index)
	if ramp == Palette.NO_RAMP:
		return false
	var edited: Palette = palette().duplicate_palette()
	var removed: bool = edited.remove_ramp(ramp.x)
	assert(removed)
	bus.execute(ReplacePaletteCommand.new(palette(), edited, "Remove Ramp"))
	return true


# --- color cycling -----------------------------------------------------------

const DEFAULT_CYCLE_RATE_HZ: float = 8.0

## Adds a cycle over the FG..BG span. Returns "" or a reason it was refused.
func add_cycle_between_fg_and_bg() -> String:
	return add_cycle(mini(state.fg, state.bg), maxi(state.fg, state.bg), DEFAULT_CYCLE_RATE_HZ, 1)


func add_cycle(start: int, end: int, rate_hz: float, step: int) -> String:
	var edited: Array[CycleRange] = _cycles_copy()
	edited.append(CycleRange.new(start, end, rate_hz, step))
	return _set_cycles(edited, "Add Cycle")


## Changes cycle `index`. Returns "" or a reason it was refused (overlap, bad range...).
func update_cycle(index: int, start: int, end: int, rate_hz: float, step: int, active: bool) -> String:
	if index < 0 or index >= bus.document.cycles.size():
		return "no such cycle"
	var edited: Array[CycleRange] = _cycles_copy()
	var cycle: CycleRange = CycleRange.new(mini(start, end), maxi(start, end), rate_hz, step)
	cycle.active = active
	edited[index] = cycle
	return _set_cycles(edited, "Edit Cycle")


func delete_cycle(index: int) -> void:
	if index < 0 or index >= bus.document.cycles.size():
		return
	var edited: Array[CycleRange] = _cycles_copy()
	edited.remove_at(index)
	var _error: String = _set_cycles(edited, "Delete Cycle")


func _cycles_copy() -> Array[CycleRange]:
	var copies: Array[CycleRange] = []
	for cycle: CycleRange in bus.document.cycles:
		copies.append(cycle.duplicate_cycle())
	return copies


func _set_cycles(cycles: Array[CycleRange], label: String) -> String:
	commit_color()
	var errors: PackedStringArray = DocumentValidator.validate_cycles(cycles, palette().size())
	if not errors.is_empty():
		return errors[0]
	bus.execute(SetCyclesCommand.new(bus.document.cycles, cycles, label))
	return ""


# --- stencil -----------------------------------------------------------------

func toggle_lock(index: int) -> void:
	_edit_stencil("Toggle Stencil", func(stencil: Stencil) -> void: stencil.toggle(index))


func invert_stencil() -> void:
	_edit_stencil("Invert Stencil", func(stencil: Stencil) -> void: stencil.invert())


func lock_all_except_fg() -> void:
	var fg: int = state.fg
	_edit_stencil("Lock All Except FG", func(stencil: Stencil) -> void: stencil.lock_all_except(fg))


func clear_stencil() -> void:
	_edit_stencil("Clear Stencil", func(stencil: Stencil) -> void: stencil.clear())


func _edit_stencil(label: String, edit: Callable) -> void:
	var stencil: Stencil = bus.document.stencil
	var edited: Stencil = stencil.duplicate_stencil()
	edit.call(edited)
	if edited.locked != stencil.locked:
		bus.execute(SetStencilCommand.new(stencil.locked, edited.locked, label))
