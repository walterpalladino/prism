## Small modal form (rename layer, frame duration, layer opacity, tag properties).
## Add fields, then popup; `submitted` fires on OK or Enter with the field values by name.
class_name FormDialog
extends ConfirmationDialog

signal submitted(values: Dictionary)

var _fields: Dictionary[String, Control] = {}
var _box: VBoxContainer


func _init() -> void:
	exclusive = true
	transient = true
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	add_child(_box)
	Signals.on(confirmed, _on_confirmed)
	Signals.on(canceled, queue_free)


func add_text(key: String, label: String, value: String) -> void:
	var edit: LineEdit = LineEdit.new()
	edit.text = value
	edit.select_all_on_focus = true
	register_text_enter(edit)
	_add_row(key, label, edit)


func add_number(key: String, label: String, value: int, min_value: int, max_value: int, suffix: String = "") -> void:
	var spin: SpinBox = SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.value = value
	spin.suffix = suffix
	register_text_enter(spin.get_line_edit())
	_add_row(key, label, spin)


func add_choice(key: String, label: String, options: PackedStringArray, selected: int) -> void:
	var option: OptionButton = OptionButton.new()
	for i: int in options.size():
		option.add_item(options[i], i)
	option.select(selected)
	_add_row(key, label, option)


func add_color(key: String, label: String, value: Color) -> void:
	var picker: ColorPickerButton = ColorPickerButton.new()
	picker.color = value
	picker.edit_alpha = false
	picker.custom_minimum_size = Vector2(60, 24)
	_add_row(key, label, picker)


## Shows the dialog centered and focuses the first field.
func open(parent: Node) -> void:
	parent.add_child(self)
	popup_centered(Vector2i(300, 0))
	if not _fields.is_empty():
		var first: Control = _fields.values()[0]
		var spin: SpinBox = first as SpinBox
		if spin != null:
			spin.get_line_edit().grab_focus()
		else:
			first.grab_focus()


func _add_row(key: String, label: String, field: Control) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	var caption: Label = Label.new()
	caption.text = label
	caption.custom_minimum_size = Vector2(90, 0)
	row.add_child(caption)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)
	_box.add_child(row)
	_fields[key] = field


## Field values by key: String for text, int for numbers and choices, Color for colors.
func values() -> Dictionary:
	var result: Dictionary = {}
	for key: String in _fields:
		var field: Control = _fields[key]
		if field is LineEdit:
			result[key] = (field as LineEdit).text
		elif field is SpinBox:
			(field as SpinBox).apply()
			result[key] = int((field as SpinBox).value)
		elif field is OptionButton:
			result[key] = (field as OptionButton).selected
		elif field is ColorPickerButton:
			result[key] = (field as ColorPickerButton).color
	return result


func _on_confirmed() -> void:
	submitted.emit(values())
	queue_free()
