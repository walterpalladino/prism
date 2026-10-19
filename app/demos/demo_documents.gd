## Built-in demo documents.
class_name DemoDocuments
extends RefCounted

const WATERFALL_START: int = 16
const WATERFALL_END: int = 21
const WATERFALL_RATE_HZ: float = 12.0


## Concept C3: a waterfall painted with palette entries 16-21, cycling at 12 steps/s.
## The pixels never change; only the palette rotates.
static func waterfall() -> PrismDocument:
	var doc: PrismDocument = PrismDocument.create(64, 64)
	var image: IndexedImage = doc.get_cel_image(0, 0)
	var length: int = WATERFALL_END - WATERFALL_START + 1
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for y: int in 64:
		var left_edge: int = 18 + roundi(3.0 * sin(y * 0.3))
		var right_edge: int = 45 - roundi(3.0 * sin(y * 0.25 + 1.0))
		for x: int in 64:
			if y >= 56:
				# Pool: two light blues.
				image.set_index(x, y, 19 + (x + y) % 2)
			elif x < left_edge or x > right_edge:
				# Rocks: dark browns with a little noise, darker toward the water.
				var near_water: bool = x == left_edge - 1 or x == right_edge + 1
				image.set_index(x, y, 31 if near_water else (22 if rng.randf() < 0.7 else 23))
			else:
				# Falling water: horizontal bands of the cycle range with a slight per-column
				# stagger. A forward cycle moves each color to the next index, i.e. one band down.
				image.set_index(x, y, WATERFALL_START + posmod(-(y + (x * 5) % 2), length))
	doc.cycles.append(CycleRange.new(WATERFALL_START, WATERFALL_END, WATERFALL_RATE_HZ))
	return doc
