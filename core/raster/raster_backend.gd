## Hot-path raster operations behind an interface so they can move to
## GDExtension (C++) without touching callers (GDD §9.2 rule 5).
@abstract
class_name RasterBackend
extends RefCounted


@abstract func flood_fill(image: IndexedImage, start: Vector2i, value: int, stencil: Stencil) -> Rect2i
@abstract func replace_index(image: IndexedImage, from_value: int, to_value: int, stencil: Stencil) -> Rect2i
