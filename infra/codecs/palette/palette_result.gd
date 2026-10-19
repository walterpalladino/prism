## Outcome of decoding a palette file: a palette, or an error message (never both).
class_name PaletteResult
extends RefCounted

var palette: Palette
var error: String = ""


static func ok(p_palette: Palette) -> PaletteResult:
	var result: PaletteResult = PaletteResult.new()
	result.palette = p_palette
	return result


static func fail(message: String) -> PaletteResult:
	var result: PaletteResult = PaletteResult.new()
	result.error = message
	return result


func is_ok() -> bool:
	return error == ""
