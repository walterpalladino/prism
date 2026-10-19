## Default RasterBackend implemented in GDScript via RasterOps.
class_name GDScriptRasterBackend
extends RasterBackend


func flood_fill(image: IndexedImage, start: Vector2i, value: int, stencil: Stencil) -> Rect2i:
	return RasterOps.flood_fill(image, start, value, stencil)


func replace_index(image: IndexedImage, from_value: int, to_value: int, stencil: Stencil) -> Rect2i:
	return RasterOps.replace_index(image, from_value, to_value, stencil)
