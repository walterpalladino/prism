## Upgrades older `.prism` document.json data to the current schema version (GDD §9.6).
##
## To change the schema: bump CURRENT_VERSION, then add a function migrating (N-1) -> N to
## STEPS. Each step receives the parsed document.json and returns it upgraded.
class_name PrismMigrations
extends RefCounted

const CURRENT_VERSION: int = 1

## STEPS[i] upgrades version i+1 to i+2. Empty while only v1 exists.
const STEPS: Array[StringName] = []


## Brings `data` to CURRENT_VERSION in place. Returns "" or an error message.
static func migrate(data: Dictionary) -> String:
	var version_value: Variant = data.get("version")
	if not (version_value is float or version_value is int):
		return "document.json has no version"
	var version_number: float = version_value
	var version: int = int(version_number)
	if version < 1:
		return "invalid document version %d" % version
	if version > CURRENT_VERSION:
		return "this file was saved by a newer PRISM (format v%d; this version reads up to v%d)" % [version, CURRENT_VERSION]
	while version < CURRENT_VERSION:
		var step: StringName = STEPS[version - 1]
		var migrated: Variant = PrismMigrations.new().call(step, data)
		if not (migrated is Dictionary):
			return "migration from v%d failed" % version
		var upgraded: Dictionary = migrated
		data.merge(upgraded, true)
		version += 1
		data["version"] = version
	return ""
