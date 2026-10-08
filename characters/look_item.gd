@tool
class_name LookItem
extends Resource
## An appearance item, such as clothing, hair, or eyes, displayed by
## [CharacterVisual].
##
## Holds only metadata and a path to the visual asset, so actual assets are
## loaded on instantiation.

## Display name.
@export var name: String

## Occupied slot.
##
## If unset, this item conflicts with nothing.
@export var slot: LookSlot

## Visual asset to load.
##
## Supported resource types depend on the [CharacterVisual] implementation.
@export_file var asset_path: String


## Returns whether the items occupy conflicting slots.
func conflicts_with(other: LookItem) -> bool:
	if not other or not slot:
		return false

	return slot.conflicts_with(other.slot)


## Loads all items in the given directory recursively.
##
## The result is sorted by slot, then item name.
## Items without a slot come last.
static func load_from(dir: String) -> Array[LookItem]:
	var items: Array[LookItem] = []
	_load_recursively(dir, items)
	items.sort_custom(_sort_by_slot_and_name)
	return items


static func _load_recursively(dir_path: String, items: Array[LookItem]) -> void:
	var entries := ResourceLoader.list_directory(dir_path)
	entries.sort()

	for entry in entries:
		var path := dir_path.path_join(entry)

		if entry.ends_with("/"):
			_load_recursively(path, items)
			continue

		if entry.get_extension() not in ["tres", "res"]:
			continue

		var item := ResourceLoader.load(path) as LookItem
		if item:
			items.append(item)
		else:
			Log.warn("Loaded resource '%s' is not a LookItem, skipping", path)


static func _sort_by_slot_and_name(a: LookItem, b: LookItem) -> bool:
	# Items without a slot come last.
	if not a.slot and not b.slot:
		return a.name.naturalnocasecmp_to(b.name) < 0
	if not a.slot:
		return false
	if not b.slot:
		return true

	if a.slot != b.slot:
		return a.slot.name.naturalnocasecmp_to(b.slot.name) < 0

	return a.name.naturalnocasecmp_to(b.name) < 0


func _to_string() -> String:
	return "LookItem('%s', '%s')" % [name, asset_path]
