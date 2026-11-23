@tool
class_name CharacterLook
extends Resource
## Items and their selected appearances on a [CharacterVisual].

signal item_added(item: LookItem)
signal item_removed(item: LookItem)

## Attached items with an optional selected swatch.
##
## A null value uses the item's default appearance.
## Entries should be mutated only through methods or via editor inspector.
@export var items: Dictionary[LookItem, LookSwatch]:
	set = _set_items


## Adds the item, removing the items it conflicts with.
func add(new_item: LookItem) -> void:
	assert(new_item)

	if items.has(new_item):
		return

	var conflicts: Array[LookItem]
	for item in items:
		if new_item.conflicts_with(item):
			conflicts.append(item)

	for item in conflicts:
		Log.trace("Removing conflicting %s", item)
		items.erase(item)
		item_removed.emit(item)

	Log.trace("Adding %s", new_item)
	items[new_item] = null
	item_added.emit(new_item)


## Removes the item if present.
func remove(item: LookItem) -> void:
	if not items.erase(item):
		return

	Log.trace("Removing %s", item)
	item_removed.emit(item)


## Changes an attached item's swatch without detaching it.
##
## Null swatch restores the default appearance.
func set_swatch(item: LookItem, swatch: LookSwatch) -> void:
	if not items.has(item):
		Log.warn("Unable to set %s because %s is not attached", swatch, item)
		return

	if items[item] == swatch:
		return

	if swatch and not item.swatches.has(swatch):
		Log.warn("'%s' does not belong to %s", swatch, item)
		return

	items[item] = swatch


## Returns the selected swatch, or null if the item is not attached or uses its default appearance.
func get_swatch(item: LookItem) -> LookSwatch:
	return items.get(item)


## Returns the attached item in the given slot.
##
## Returns `null` if the slot is empty.
func get_item(slot: LookSlot) -> LookItem:
	for item in items:
		if item and item.slot == slot:
			return item

	return null


func _set_items(new_items: Dictionary[LookItem, LookSwatch]) -> void:
	var removed: Array[LookItem]
	for item in items:
		if not new_items.has(item):
			removed.append(item)

	# Accumulate to avoid iterating and removing at the same time.
	for item in removed:
		remove(item)

	for new_item in new_items:
		if not new_item or not new_item.slot:
			Log.warn("Ignoring an invalid %s", new_item)
			continue

		if not items.has(new_item):
			add(new_item)

		set_swatch(new_item, new_items[new_item])
