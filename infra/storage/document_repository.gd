## Where documents are stored (GDD §9.2 rule 4). The app talks to this interface so tests can
## use MemoryDocumentRepository instead of the file system.
@abstract
class_name DocumentRepository
extends RefCounted


## Saves `doc` to `path`; returns "" or an error message.
@abstract func save_document(doc: PrismDocument, path: String) -> String
@abstract func load_document(path: String) -> DocumentResult
@abstract func exists(path: String) -> bool
## Deletes `path` if present (autosave cleanup).
@abstract func remove(path: String) -> void
## Writes a small text file (the autosave session lock); returns "" or an error message.
@abstract func write_text(path: String, text: String) -> String
