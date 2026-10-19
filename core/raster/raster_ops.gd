## Stateless raster primitives on IndexedImage (GDD §10 M1).
##
## Shape functions return pixel coordinates; painting them goes through
## Painter so brushes, inks and the stencil are applied in one place.
## Functions that write pixels respect the stencil: a destination pixel whose
## current index is locked is never overwritten. `stencil` may be null.
class_name RasterOps
extends RefCounted

## Directions Shift-constrained lines snap to: 0/45/90 degrees and the 1:2 / 2:1 pixel-art angles.
const CONSTRAINED_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(2, 1), Vector2i(1, 1), Vector2i(1, 2), Vector2i(0, 1),
	Vector2i(-1, 2), Vector2i(-1, 1), Vector2i(-2, 1), Vector2i(-1, 0), Vector2i(-2, -1),
	Vector2i(-1, -1), Vector2i(-1, -2), Vector2i(0, -1), Vector2i(1, -2), Vector2i(1, -1),
	Vector2i(2, -1),
]


## The single stencil-aware write used by every paint path. Returns true if the pixel changed.
static func write_pixel(image: IndexedImage, x: int, y: int, value: int, stencil: Stencil) -> bool:
	if not image.has_point(x, y):
		return false
	var i: int = y * image.width + x
	var current: int = image.pixels[i]
	if current == value or (stencil != null and stencil.is_locked(current)):
		return false
	image.pixels[i] = value
	return true


## Copies the pixels of `rect` (must lie inside the image) into a new row-major buffer.
static func read_rect(image: IndexedImage, rect: Rect2i) -> PackedByteArray:
	assert(image.get_rect().encloses(rect))
	var out: PackedByteArray = PackedByteArray()
	var resize_error: int = out.resize(rect.size.x * rect.size.y)
	assert(resize_error == OK)
	for row: int in rect.size.y:
		var src: int = (rect.position.y + row) * image.width + rect.position.x
		var line: PackedByteArray = image.pixels.slice(src, src + rect.size.x)
		for col: int in rect.size.x:
			out[row * rect.size.x + col] = line[col]
	return out


## Writes a row-major buffer produced by read_rect back into `rect`. Ignores the stencil (used by undo).
static func write_rect(image: IndexedImage, rect: Rect2i, data: PackedByteArray) -> void:
	assert(image.get_rect().encloses(rect))
	assert(data.size() == rect.size.x * rect.size.y)
	var px: PackedByteArray = image.pixels
	for row: int in rect.size.y:
		var dst: int = (rect.position.y + row) * image.width + rect.position.x
		var src: int = row * rect.size.x
		for col: int in rect.size.x:
			px[dst + col] = data[src + col]


## Bresenham line, endpoints included.
static func line_points(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var dx: int = absi(to.x - from.x)
	var dy: int = -absi(to.y - from.y)
	var sx: int = 1 if from.x < to.x else -1
	var sy: int = 1 if from.y < to.y else -1
	var err: int = dx + dy
	var x: int = from.x
	var y: int = from.y
	while true:
		points.append(Vector2i(x, y))
		if x == to.x and y == to.y:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
	return points


## Snaps `to` so the line from `from` follows the closest constrained direction.
static func constrain_line_end(from: Vector2i, to: Vector2i) -> Vector2i:
	var v: Vector2 = Vector2(to - from)
	if v == Vector2.ZERO:
		return from
	var best: Vector2i = CONSTRAINED_DIRECTIONS[0]
	var best_cos: float = -2.0
	for dir: Vector2i in CONSTRAINED_DIRECTIONS:
		var d: Vector2 = Vector2(dir)
		var c: float = v.dot(d) / (v.length() * d.length())
		if c > best_cos:
			best_cos = c
			best = dir
	var bd: Vector2 = Vector2(best)
	var steps: int = maxi(1, roundi(v.dot(bd) / bd.dot(bd)))
	return from + best * steps


static func rect_points(rect: Rect2i, filled: bool) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var x0: int = rect.position.x
	var y0: int = rect.position.y
	var x1: int = rect.end.x - 1
	var y1: int = rect.end.y - 1
	for y: int in range(y0, y1 + 1):
		for x: int in range(x0, x1 + 1):
			if filled or x == x0 or x == x1 or y == y0 or y == y1:
				points.append(Vector2i(x, y))
	return points


## Ellipse inscribed in `rect` (inclusive bounds). Mirror-symmetric on both axes
## and touches every side of the rect. Outline is the 8-connected boundary.
static func ellipse_points(rect: Rect2i, filled: bool) -> Array[Vector2i]:
	var w: int = rect.size.x
	var h: int = rect.size.y
	var points: Array[Vector2i] = []
	if w <= 0 or h <= 0:
		return points
	var mask: PackedByteArray = _ellipse_mask(w, h)
	for y: int in h:
		for x: int in w:
			if mask[y * w + x] == 0:
				continue
			if filled or _is_mask_edge(mask, w, h, x, y):
				points.append(rect.position + Vector2i(x, y))
	return points


## Removes L-shaped corner pixels from a freehand point sequence ("pixel-perfect").
static func pixel_perfect(points: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for p: Vector2i in points:
		if not result.is_empty() and result.back() == p:
			continue
		if result.size() >= 2:
			var a: Vector2i = result[result.size() - 2]
			var c: Vector2i = result[result.size() - 1]
			var c_touches_a: bool = a.x == c.x or a.y == c.y
			var c_touches_p: bool = p.x == c.x or p.y == c.y
			if c_touches_a and c_touches_p and a.x != p.x and a.y != p.y:
				result.pop_back()
		result.append(p)
	return result


## Scanline 4-way flood fill. Returns the dirty rect (empty if nothing changed).
## Hot path (ADR 0003): preallocated seed stack, no per-span allocations or helper calls.
## Skipping the parent span (classic optimization) was measured slower here: on noisy images
## the per-seed bookkeeping costs more than the comparisons it saves.
static func flood_fill(image: IndexedImage, start: Vector2i, value: int, stencil: Stencil) -> Rect2i:
	if not image.has_point(start.x, start.y):
		return Rect2i()
	var w: int = image.width
	var h: int = image.height
	var px: PackedByteArray = image.pixels
	var target: int = px[start.y * w + start.x]
	if target == value or (stencil != null and stencil.is_locked(target)):
		return Rect2i()
	var min_x: int = start.x
	var max_x: int = start.x
	var min_y: int = start.y
	var max_y: int = start.y
	# Seeds are pixel offsets (y * w + x); sp is the stack size.
	var stack: PackedInt32Array = PackedInt32Array()
	var resize_error: int = stack.resize(1024)
	assert(resize_error == OK)
	stack[0] = start.y * w + start.x
	var sp: int = 1
	while sp > 0:
		sp -= 1
		var seed_offset: int = stack[sp]
		if px[seed_offset] != target:
			continue
		@warning_ignore("integer_division")
		var y: int = seed_offset / w
		var row: int = y * w
		var lo: int = seed_offset
		while lo > row and px[lo - 1] == target:
			lo -= 1
		var hi: int = seed_offset
		var row_end: int = row + w - 1
		while hi < row_end and px[hi + 1] == target:
			hi += 1
		for i: int in range(lo, hi + 1):
			px[i] = value
		# Plain comparisons: mini()/maxi() calls cost more in this hot loop.
		if lo - row < min_x:
			min_x = lo - row
		if hi - row > max_x:
			max_x = hi - row
		if y < min_y:
			min_y = y
		elif y > max_y:
			max_y = y
		# Push one seed per run of target pixels in the rows above and below.
		# The two scans are written out twice on purpose: a helper call per run costs more.
		if y > 0:
			var in_run: bool = false
			for j: int in range(lo - w, hi - w + 1):
				if px[j] == target:
					if not in_run:
						if sp == stack.size():
							resize_error = stack.resize(sp * 2)
							assert(resize_error == OK)
						stack[sp] = j
						sp += 1
						in_run = true
				else:
					in_run = false
		if y < h - 1:
			var in_run: bool = false
			for j: int in range(lo + w, hi + w + 1):
				if px[j] == target:
					if not in_run:
						if sp == stack.size():
							resize_error = stack.resize(sp * 2)
							assert(resize_error == OK)
						stack[sp] = j
						sp += 1
						in_run = true
				else:
					in_run = false
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


## Replaces every `from_value` pixel with `to_value` (global fill). Returns the dirty rect.
static func replace_index(image: IndexedImage, from_value: int, to_value: int, stencil: Stencil) -> Rect2i:
	if from_value == to_value or (stencil != null and stencil.is_locked(from_value)):
		return Rect2i()
	var px: PackedByteArray = image.pixels
	var w: int = image.width
	var dirty: Rect2i = Rect2i()
	var any: bool = false
	var index: int = px.find(from_value)
	while index != -1:
		px[index] = to_value
		@warning_ignore("integer_division")
		var y: int = index / w
		var cell: Rect2i = Rect2i(index - y * w, y, 1, 1)
		dirty = cell if not any else dirty.merge(cell)
		any = true
		index = px.find(from_value, index + 1)
	return dirty


## Copies `src` onto `dst` with its top-left at `at`, skipping `transparent_index`
## source pixels and stencil-locked destination pixels. Returns the clipped target rect.
static func blit(dst: IndexedImage, src: IndexedImage, at: Vector2i, transparent_index: int, stencil: Stencil) -> Rect2i:
	var target: Rect2i = Rect2i(at, src.get_size()).intersection(dst.get_rect())
	if not target.has_area():
		return Rect2i()
	for y: int in range(target.position.y, target.end.y):
		for x: int in range(target.position.x, target.end.x):
			var value: int = src.get_index(x - at.x, y - at.y)
			if value != transparent_index:
				var _changed: bool = write_pixel(dst, x, y, value, stencil)
	return target


## Copies a region (clipped to the image) into a new image. Used by brush pickup.
static func copy_region(image: IndexedImage, rect: Rect2i, p_id: StringName) -> IndexedImage:
	var clipped: Rect2i = rect.intersection(image.get_rect())
	assert(clipped.has_area())
	var out: IndexedImage = IndexedImage.new(p_id, clipped.size.x, clipped.size.y)
	out.pixels = read_rect(image, clipped)
	return out


static func flipped_h(src: IndexedImage) -> IndexedImage:
	var out: IndexedImage = IndexedImage.new(src.id, src.width, src.height)
	for y: int in src.height:
		for x: int in src.width:
			out.set_index(src.width - 1 - x, y, src.get_index(x, y))
	return out


static func flipped_v(src: IndexedImage) -> IndexedImage:
	var out: IndexedImage = IndexedImage.new(src.id, src.width, src.height)
	for y: int in src.height:
		for x: int in src.width:
			out.set_index(x, src.height - 1 - y, src.get_index(x, y))
	return out


## Rotates 90 degrees clockwise; the result is height x width.
static func rotated_90_cw(src: IndexedImage) -> IndexedImage:
	var out: IndexedImage = IndexedImage.new(src.id, src.height, src.width)
	for y: int in src.height:
		for x: int in src.width:
			out.set_index(src.height - 1 - y, x, src.get_index(x, y))
	return out


## Filled ellipse mask: union of row spans and column spans, so thin ellipses
## still reach every side of their box. Sampled at pixel centers.
static func _ellipse_mask(w: int, h: int) -> PackedByteArray:
	var mask: PackedByteArray = PackedByteArray()
	var resize_error: int = mask.resize(w * h)
	assert(resize_error == OK)
	var rx: float = w / 2.0
	var ry: float = h / 2.0
	for y: int in h:
		var half: float = _half_span(y, h, ry, rx)
		for x: int in w:
			if absf(x + 0.5 - rx) <= half:
				mask[y * w + x] = 1
	for x: int in w:
		var half: float = _half_span(x, w, rx, ry)
		for y: int in h:
			if absf(y + 0.5 - ry) <= half:
				mask[y * w + x] = 1
	return mask


## Half-width of the ellipse span at row/column `i` of `n`, never less than the center pixel(s).
static func _half_span(i: int, n: int, r_along: float, r_across: float) -> float:
	var t: float = (i + 0.5 - r_along) / r_along
	var half: float = r_across * sqrt(maxf(0.0, 1.0 - t * t))
	return maxf(half, 0.5)


static func _is_mask_edge(mask: PackedByteArray, w: int, h: int, x: int, y: int) -> bool:
	if x == 0 or y == 0 or x == w - 1 or y == h - 1:
		return true
	var i: int = y * w + x
	return mask[i - 1] == 0 or mask[i + 1] == 0 or mask[i - w] == 0 or mask[i + w] == 0
