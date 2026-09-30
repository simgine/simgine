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


func _to_string() -> String:
	return "LookItem('%s', '%s')" % [name, asset_path]
