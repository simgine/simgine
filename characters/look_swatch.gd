@tool
class_name LookSwatch
extends Resource
## An alternative varint for a [LookItem].
##
## Holds only metadata and a path to the visual asset, so the asset itself is
## not loaded during swatch discovery.

## Display name.
@export var name: String

## License under which the asset is released.
@export var license: String

## Author of the asset.
@export var author: String

## Visual asset to load.
##
## Supported resource types depend on the [CharacterVisual] implementation.
@export_file var asset_path: String


## Loads all swatches in the given directory recursively.
##
## The result is sorted by name.
static func load_from(dir: String) -> Array[LookSwatch]:
	var swatches: Array[LookSwatch]
	_load_recursively(dir, swatches)
	swatches.sort_custom(
		func(a: LookSwatch, b: LookSwatch) -> bool:
			return a.name.naturalnocasecmp_to(b.name) < 0,
	)
	return swatches


static func _load_recursively(dir: String, swatches: Array[LookSwatch]) -> void:
	for entry in ResourceLoader.list_directory(dir):
		var path := dir.path_join(entry)

		if entry.ends_with("/"):
			_load_recursively(path, swatches)
			continue

		if entry.get_extension() not in ["tres", "res"]:
			continue

		var swatch := ResourceLoader.load(path) as LookSwatch
		if not swatch:
			Log.warn("Loaded resource '%s' is not a LookSwatch, skipping", path)
		else:
			swatches.append(swatch)


func _to_string() -> String:
	return "LookSwatch('%s', '%s')" % [name, asset_path]
