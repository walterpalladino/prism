## Typed, defensive access to parsed JSON. Every getter checks the type and range and records
## a readable error instead of crashing, so untrusted files can never break the loader.
class_name JsonReader
extends RefCounted

var errors: PackedStringArray = PackedStringArray()


func fail(message: String) -> void:
	errors.append_array([message])


func ok() -> bool:
	return errors.is_empty()


func get_dict(source: Dictionary, key: String, where: String) -> Dictionary:
	var value: Variant = source.get(key)
	if value is Dictionary:
		return value
	fail("%s: '%s' must be an object" % [where, key])
	return {}


func get_array(source: Dictionary, key: String, where: String) -> Array:
	var value: Variant = source.get(key)
	if value is Array:
		return value
	fail("%s: '%s' must be a list" % [where, key])
	return []


## JSON numbers arrive as floats; accepts whole numbers only.
func get_int(source: Dictionary, key: String, where: String, min_value: int, max_value: int, fallback: int = 0) -> int:
	var value: Variant = source.get(key)
	if not (value is float or value is int):
		fail("%s: '%s' must be a number" % [where, key])
		return fallback
	var number: float = value
	if number != floorf(number) or number < min_value or number > max_value:
		fail("%s: '%s' = %s is not a whole number in %d..%d" % [where, key, number, min_value, max_value])
		return fallback
	return int(number)


func get_float(source: Dictionary, key: String, where: String, min_value: float, max_value: float, fallback: float = 0.0) -> float:
	var value: Variant = source.get(key)
	if not (value is float or value is int):
		fail("%s: '%s' must be a number" % [where, key])
		return fallback
	var number: float = value
	if number < min_value or number > max_value:
		fail("%s: '%s' = %s is out of range %s..%s" % [where, key, number, min_value, max_value])
		return fallback
	return number


func get_bool(source: Dictionary, key: String, where: String, fallback: bool = false) -> bool:
	var value: Variant = source.get(key)
	if value is bool:
		return value
	fail("%s: '%s' must be true or false" % [where, key])
	return fallback


func get_string(source: Dictionary, key: String, where: String, fallback: String = "") -> String:
	var value: Variant = source.get(key)
	if value is String:
		return value
	fail("%s: '%s' must be text" % [where, key])
	return fallback


## "#rrggbb" or "#rrggbbaa".
func get_color(source: Dictionary, key: String, where: String) -> Color:
	return parse_color(get_string(source, key, where, "#000000"), "%s.%s" % [where, key])


func parse_color(text: String, where: String) -> Color:
	var hex: String = text.trim_prefix("#")
	if (hex.length() == 6 or hex.length() == 8) and hex.is_valid_hex_number():
		return Color.html(hex)
	fail("%s: '%s' is not a #rrggbb color" % [where, text])
	return Color.BLACK
