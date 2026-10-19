## Checked signal connection. Signal.connect() returns an error code, and the project
## treats discarded return values as errors, so connections go through here.
class_name Signals
extends RefCounted


static func on(sig: Signal, callable: Callable) -> void:
	var err: int = sig.connect(callable)
	assert(err == OK, "failed to connect %s" % sig.get_name())
