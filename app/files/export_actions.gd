## Export and import commands for the UI (GDD §7.12). Formats live in infra/; this class picks
## the frames, applies options and writes through a FileSink.
class_name ExportActions
extends RefCounted

var bus: CommandBus
var state: EditorState
var sink: FileSink


func _init(p_bus: CommandBus, p_state: EditorState, p_sink: FileSink) -> void:
	bus = p_bus
	state = p_state
	sink = p_sink


func doc() -> PrismDocument:
	return bus.document


## Choices for "which frames": index 0 = all frames, i + 1 = tag i.
func scope_names() -> PackedStringArray:
	var names: PackedStringArray = ["All frames (%d)" % doc().frames.size()]
	for tag: Tag in doc().tags:
		names.append_array(["Tag: %s (%d–%d)" % [tag.tag_name, tag.from_frame + 1, tag.to_frame + 1]])
	return names


func options_for(scope: int) -> ExportOptions:
	if scope >= 1 and scope <= doc().tags.size():
		return ExportOptions.for_tag(doc(), scope - 1)
	return ExportOptions.whole(doc())


## How many frames an export would write before capping (cycling bake can explode, risk 5).
func predicted_frames(options: ExportOptions) -> int:
	return FrameSchedule.predicted_count(doc(), options.order(), options.bake_cycles)


func export_frame_png(path: String, scale: int) -> String:
	return sink.write_png(_with_extension(path, "png"), PngExport.frame_image(doc(), state.frame_index, scale))


func export_png_sequence(path: String, options: ExportOptions) -> String:
	return PngExport.write_sequence(doc(), options, sink, path)


func export_sprite_sheet(path: String, options: ExportOptions) -> String:
	return SpriteSheet.write(doc(), options, sink, path)


func export_sprite_frames(path: String, scale: int) -> String:
	return SpriteFramesWriter.write(doc(), scale, sink, path)


func export_gif(path: String, options: ExportOptions) -> String:
	return GifWriter.write(doc(), options, sink, path)


## Imports a PNG into the current cel (colors mapped to the palette). One undo step.
func import_png_into_cel(path: String) -> String:
	var image: Image = PngImport.load_image(sink.read_bytes(path))
	if image == null:
		return "%s is not a readable PNG" % path.get_file()
	var target: IndexedImage = state.editable_image()
	if target == null:
		return "the current layer is locked or hidden"
	var imported: IndexedImage = PngImport.to_indexed(image, doc().palette, doc().transparent_index)
	var session: StrokeSession = StrokeSession.new(target)
	var cel: Cel = state.current_cel()
	var dirty: Rect2i = RasterOps.blit(target, imported, -cel.offset, doc().transparent_index, doc().stencil)
	session.add_dirty(dirty)
	var patch: PixelPatch = session.commit("Import PNG")
	if patch != null:
		bus.record(patch)
	return ""


## A new document made from a PNG (its own palette when it has few enough colors).
func document_from_png(path: String) -> DocumentResult:
	var image: Image = PngImport.load_image(sink.read_bytes(path))
	if image == null:
		return DocumentResult.fail("%s is not a readable PNG" % path.get_file())
	return PngImport.to_document(image, PalettePresets.default_32())


static func _with_extension(path: String, extension: String) -> String:
	return path if path.get_extension().to_lower() == extension else path + "." + extension
