@tool
class_name LookItem
extends Resource
## An appearance item, such as clothing, hair, or eyes, displayed by
## [CharacterVisual].
##
## Holds only metadata and a path to the visual asset, so actual assets are
## loaded on instantiation.

## Directory with where to search for swatches.
const _SWATCHES_DIR := "swatches"

## Display name.
@export var name: String

## License under which the asset is released.
@export var license: String

## Author of the asset.
@export var author: String

## Descriptors such as `casual`, `curly`, `male`, or `female`.
##
## Unisex items omit both gender tags.
@export var tags: PackedStringArray

## Occupied slot.
##
## Items without a slot are skipped at load time.
@export var slot: LookSlot

## Visual asset to load.
##
## Supported resource types depend on the [CharacterVisual] implementation.
@export_file var asset_path: String

## Alternative asset variants.
##
## Loaded lazily on first access in from [constant _SWATCHES_DIR] relative
## to this resource path.
var swatches: Array[LookSwatch]:
	get = _get_swatches

var _swatches_loaded: bool


## Returns whether the items occupy conflicting slots.
func conflicts_with(other: LookItem) -> bool:
	if not other:
		return false

	return slot.conflicts_with(other.slot)


## Loads all items in the given directory recursively.
##
## [constant _SWATCHES_DIR] will be ignored.
## The result is sorted by slot, then item name.
static func load_from(dir: String) -> Array[LookItem]:
	var items: Array[LookItem]
	_load_recursively(dir, items)
	items.sort_custom(_sort_by_slot_and_name)
	return items


func _get_swatches() -> Array[LookSwatch]:
	if _swatches_loaded:
		return swatches

	_swatches_loaded = true
	if resource_path and not is_built_in():
		var dir := resource_path.get_base_dir().path_join(_SWATCHES_DIR)
		swatches = LookSwatch.load_from(dir)

	return swatches


static func _load_recursively(dir_path: String, items: Array[LookItem]) -> void:
	for entry in ResourceLoader.list_directory(dir_path):
		var path := dir_path.path_join(entry)

		if entry.ends_with("/"):
			if entry != _SWATCHES_DIR + "/":
				_load_recursively(path, items)
			continue

		if entry.get_extension() not in ["tres", "res"]:
			continue

		var item := ResourceLoader.load(path) as LookItem
		if not item:
			Log.warn("Loaded resource '%s' is not a LookItem, skipping", path)
		elif not item.slot:
			Log.warn("'%s' has no slot, skipping", path)
		else:
			items.append(item)


static func _sort_by_slot_and_name(a: LookItem, b: LookItem) -> bool:
	if a.slot != b.slot:
		return a.slot.name.naturalnocasecmp_to(b.slot.name) < 0

	return a.name.naturalnocasecmp_to(b.name) < 0


func _to_string() -> String:
	return "LookItem('%s', '%s')" % [name, asset_path]
