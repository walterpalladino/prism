## Composition root and the project's only autoload.
##
## Builds the application services and infrastructure, and injects their
## dependencies through _init(). Services must never look this node up
## themselves; only UI scenes read from it.
extends Node


func _ready() -> void:
	pass
