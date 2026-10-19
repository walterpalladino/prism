## Spike C (CPU hot paths) and the CPU half of Spike B (per-event stroke cost).
## Run: godot --headless --path . -s res://bench/cpu_bench.gd
extends SceneTree

const RUNS: int = 7


func _init() -> void:
	print("PRISM CPU benchmarks — Godot %s, %s, median of %d runs" % [Engine.get_version_info()["string"], OS.get_processor_name(), RUNS])
	_bench_flood_fill()
	_bench_rect_patches()
	_bench_strokes()
	_bench_gif()
	quit()


func _bench_flood_fill() -> void:
	print("\n-- Flood fill (budget 50 ms @ 512x512, GDD §9.4)")
	for size: int in [256, 512]:
		var ms: float = BenchUtil.median_ms(func() -> void:
			var image: IndexedImage = IndexedImage.new(&"b", size, size)
			var _dirty: Rect2i = RasterOps.flood_fill(image, Vector2i(size >> 1, size >> 1), 5, null), RUNS)
		BenchUtil.report("flood fill blank %dx%d (whole canvas)" % [size, size], ms, 50.0 if size == 512 else -1.0)
	var noisy: IndexedImage = BenchUtil.noise_image(512, 2, 0.3, 7)
	var noisy_ms: float = BenchUtil.median_ms(func() -> void:
		var image: IndexedImage = noisy.duplicate_image(&"b")
		var _dirty: Rect2i = RasterOps.flood_fill(image, Vector2i(0, 0), 5, null), RUNS)
	BenchUtil.report("flood fill 512x512, 30% noise walls (many short runs)", noisy_ms, 50.0)
	var replace_ms: float = BenchUtil.median_ms(func() -> void:
		var image: IndexedImage = noisy.duplicate_image(&"b")
		var _dirty: Rect2i = RasterOps.replace_index(image, 1, 9, null), RUNS)
	BenchUtil.report("global replace 512x512 (~30% of pixels match)", replace_ms)


func _bench_rect_patches() -> void:
	print("\n-- Undo patches (budget 16 ms for a full-canvas undo, GDD §9.4)")
	var image: IndexedImage = BenchUtil.noise_image(512, 32, 0.5, 3)
	var full: Rect2i = image.get_rect()
	var data: PackedByteArray = RasterOps.read_rect(image, full)
	BenchUtil.report("read_rect 512x512", BenchUtil.median_ms(func() -> void:
		var _bytes: PackedByteArray = RasterOps.read_rect(image, full), RUNS))
	BenchUtil.report("write_rect 512x512 (= full-canvas undo)", BenchUtil.median_ms(func() -> void:
		RasterOps.write_rect(image, full, data), RUNS), 16.0)
	BenchUtil.report("duplicate() 512x512 buffer (native copy)", BenchUtil.median_ms(func() -> void:
		var _copy: PackedByteArray = image.pixels.duplicate(), RUNS))


func _bench_strokes() -> void:
	print("\n-- Stroke CPU cost per pointer event (Spike B; total latency budget 8 ms)")
	var image: IndexedImage = IndexedImage.new(&"b", 512, 512)
	var ctx: InkContext = InkContext.new(3, 0, PrismEnums.PaintButton.PRIMARY, PalettePresets.default_32())
	for size: int in [1, 4, 8]:
		var brush: Brush = Brush.builtin(Brush.Shape.ROUND, size)
		var ms: float = BenchUtil.median_ms(func() -> void:
			var painter: Painter = Painter.new(image, brush, ColorInk.new(), ctx, null)
			var _changed: bool = painter.stamp_points(RasterOps.line_points(Vector2i(100, 100), Vector2i(116, 108))), RUNS)
		BenchUtil.report("16 px segment, round %d brush, 512x512 (incl. Painter alloc)" % size, ms, 8.0)
	var painter_alloc: float = BenchUtil.median_ms(func() -> void:
		var _p: Painter = Painter.new(image, Brush.builtin(Brush.Shape.ROUND, 1), ColorInk.new(), ctx, null), RUNS)
	BenchUtil.report("Painter.new on 512x512 (once per stroke)", painter_alloc)
	BenchUtil.report("Image.create_from_data R8 512x512 (texture source)", BenchUtil.median_ms(func() -> void:
		var _img: Image = Image.create_from_data(512, 512, false, Image.FORMAT_R8, image.pixels), RUNS))


func _bench_gif() -> void:
	print("\n-- GIF LZW: 64 frames of 256x256")
	var frames: Array[IndexedImage] = []
	for i: int in 64:
		frames.append(BenchUtil.sprite_like_image(256, i))
	var bytes: int = 0
	var start: int = Time.get_ticks_usec()
	for frame: IndexedImage in frames:
		bytes += GifLzw.encode(frame.pixels, 5).size()
	BenchUtil.report("sprite-like content, 32 colors (%d KB out)" % (bytes >> 10), (Time.get_ticks_usec() - start) / 1000.0, 2000.0)
	var noise: Array[IndexedImage] = []
	for i: int in 64:
		noise.append(BenchUtil.noise_image(256, 32, 1.0, i))
	bytes = 0
	start = Time.get_ticks_usec()
	for frame: IndexedImage in noise:
		bytes += GifLzw.encode(frame.pixels, 5).size()
	BenchUtil.report("worst case: full noise, 32 colors (%d KB out)" % (bytes >> 10), (Time.get_ticks_usec() - start) / 1000.0, 2000.0)
