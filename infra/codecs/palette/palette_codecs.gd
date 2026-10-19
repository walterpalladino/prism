## Palette file formats (GDD §7.4): GIMP .gpl, Lospec-style .hex and PNG strips.
## Decoders never crash on bad input; they return a PaletteResult with an error.
class_name PaletteCodecs
extends RefCounted

const GPL_HEADER: String = "GIMP Palette"


# --- GIMP .gpl ---------------------------------------------------------------

## Parses a GIMP palette: header line, optional "Name:"/"Columns:" lines, '#' comments,
## then one "R G B [name]" entry per line (0-255 each).
static func decode_gpl(text: String) -> PaletteResult:
	var lines: PackedStringArray = text.replace("\r", "").split("\n")
	if lines.is_empty() or lines[0].strip_edges() != GPL_HEADER:
		return PaletteResult.fail("not a GIMP palette (missing '%s' header)" % GPL_HEADER)
	var colors: PackedColorArray = PackedColorArray()
	for line_number: int in range(1, lines.size()):
		var line: String = lines[line_number].strip_edges()
		if line == "" or line.begins_with("#") or line.begins_with("Name:") or line.begins_with("Columns:"):
			continue
		var fields: PackedStringArray = line.split(" ", false)
		var parts: PackedStringArray = PackedStringArray()
		for field: String in fields:
			parts.append_array(field.split("\t", false))
		if parts.size() < 3:
			return PaletteResult.fail("line %d: expected 'R G B', got '%s'" % [line_number + 1, line])
		var channels: PackedInt32Array = PackedInt32Array()
		for c: int in 3:
			if not parts[c].is_valid_int() or parts[c].to_int() < 0 or parts[c].to_int() > 255:
				return PaletteResult.fail("line %d: '%s' is not a 0-255 channel value" % [line_number + 1, parts[c]])
			@warning_ignore("return_value_discarded")
			channels.append(parts[c].to_int())
		@warning_ignore("return_value_discarded")
		colors.append(Color8(channels[0], channels[1], channels[2]))
	return _finish(colors)


static func encode_gpl(palette: Palette, palette_name: String) -> String:
	var lines: PackedStringArray = [GPL_HEADER, "Name: %s" % palette_name, "Columns: 8", "#"]
	for i: int in palette.size():
		var c: Color = palette.get_color(i)
		lines.append_array(["%3d %3d %3d\tIndex %d" % [c.r8, c.g8, c.b8, i]])
	return "\n".join(lines) + "\n"


# --- .hex --------------------------------------------------------------------

## Parses one RRGGBB (optionally '#'-prefixed) color per line; blank lines are ignored.
static func decode_hex(text: String) -> PaletteResult:
	var colors: PackedColorArray = PackedColorArray()
	var lines: PackedStringArray = text.replace("\r", "").split("\n")
	for line_number: int in lines.size():
		var line: String = lines[line_number].strip_edges().trim_prefix("#")
		if line == "":
			continue
		if line.length() != 6 or not line.is_valid_hex_number():
			return PaletteResult.fail("line %d: '%s' is not an RRGGBB color" % [line_number + 1, lines[line_number].strip_edges()])
		@warning_ignore("return_value_discarded")
		colors.append(Color.html(line))
	return _finish(colors)


static func encode_hex(palette: Palette) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for i: int in palette.size():
		lines.append_array([palette.get_color(i).to_html(false)])
	return "\n".join(lines) + "\n"


# --- PNG strip ---------------------------------------------------------------

## Reads colors from an image in row-major order, skipping fully transparent pixels and
## repeated colors (so both 1-px strips and enlarged swatch images work).
static func decode_png_image(image: Image) -> PaletteResult:
	if image == null or image.is_empty():
		return PaletteResult.fail("empty image")
	var seen: Dictionary[int, bool] = {}
	var colors: PackedColorArray = PackedColorArray()
	for y: int in image.get_height():
		for x: int in image.get_width():
			var c: Color = image.get_pixel(x, y)
			if c.a8 == 0:
				continue
			var opaque: Color = Color8(c.r8, c.g8, c.b8)
			var key: int = opaque.to_rgba32()
			if seen.has(key):
				continue
			seen[key] = true
			if colors.size() == Palette.MAX_COLORS:
				return PaletteResult.fail("image has more than %d colors" % Palette.MAX_COLORS)
			@warning_ignore("return_value_discarded")
			colors.append(opaque)
	return _finish(colors)


static func decode_png(bytes: PackedByteArray) -> PaletteResult:
	var image: Image = Image.new()
	if bytes.is_empty() or image.load_png_from_buffer(bytes) != OK:
		return PaletteResult.fail("not a readable PNG")
	return decode_png_image(image)


## One pixel per color, in a single row.
static func encode_png_image(palette: Palette) -> Image:
	var image: Image = Image.create_empty(palette.size(), 1, false, Image.FORMAT_RGBA8)
	for i: int in palette.size():
		image.set_pixel(i, 0, palette.get_color(i))
	return image


static func _finish(colors: PackedColorArray) -> PaletteResult:
	if colors.is_empty():
		return PaletteResult.fail("palette has no colors")
	if colors.size() > Palette.MAX_COLORS:
		return PaletteResult.fail("palette has %d colors (max %d)" % [colors.size(), Palette.MAX_COLORS])
	return PaletteResult.ok(Palette.new(colors))
