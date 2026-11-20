@tool
class_name Pose
extends Resource
## A predefined character pose applied by [CharacterVisual].
##
## Holds only metadata and a path to the pose asset, which is loaded on demand.

## Display name.
@export var name: String

## License under which the asset is released.
@export var license: String

## Author of the asset.
@export var author: String

## Pose asset to load.
##
## Supported resource types depend on the [CharacterVisual] implementation.
@export_file var asset_path: String


## Loads all poses in the given directory recursively, sorted by name.
static func load_from(dir: String) -> Array[Pose]:
	var poses: Array[Pose]
	_load_recursively(dir, poses)
	poses.sort_custom(_sort_by_name)
	return poses


static func _load_recursively(dir_path: String, poses: Array[Pose]) -> void:
	var entries := ResourceLoader.list_directory(dir_path)
	entries.sort()

	for entry in entries:
		var path := dir_path.path_join(entry)

		if entry.ends_with("/"):
			_load_recursively(path, poses)
			continue

		if entry.get_extension() not in ["tres", "res"]:
			continue

		var pose := ResourceLoader.load(path) as Pose
		if not pose:
			Log.warn("Loaded resource '%s' is not a Pose, skipping", path)
		elif not pose.asset_path:
			Log.warn("'%s' has no asset path, skipping", path)
		else:
			poses.append(pose)


static func _sort_by_name(a: Pose, b: Pose) -> bool:
	return a.name.naturalnocasecmp_to(b.name) < 0


func _to_string() -> String:
	return "Pose('%s', '%s')" % [name, asset_path]
