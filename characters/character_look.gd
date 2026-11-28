@tool
class_name CharacterLook
extends Resource
## Items and their selected appearances on a [CharacterVisual].

## Emitted after an item is added to the look or its swatch changes.
##
## Null swatch means the default appearance.
signal item_applied(item: LookItem, swatch: LookSwatch)

## Emitted after an item is removed.
signal item_removed(item: LookItem)

## Attached items with an optional selected swatch.
##
## A null value uses the item's default appearance.
## Entries should be mutated only through methods or via editor inspector.
@export var items: Dictionary[LookItem, LookSwatch]:
	set = _set_items


func _init() -> void:
	# Each instantiated scene should have independent look.
	set_local_to_scene(true)


## Attaches the item if missing, otherwise changes its swatch.
##
## A null swatch uses the item's default appearance.
## Attaching removes the items it conflicts with.
func apply(new_item: LookItem, swatch: LookSwatch = null) -> void:
	assert(new_item)

	if items.has(new_item):
		if items[new_item] == swatch:
			return

		if swatch and not new_item.swatches.has(swatch):
			Log.warn("'%s' does not belong to %s", swatch, new_item)
			return

		items[new_item] = swatch
		item_applied.emit(new_item, swatch)
		return

	Log.trace("Adding %s", new_item)
	var conflicts: Array[LookItem]
	for item in items:
		if new_item.conflicts_with(item):
			conflicts.append(item)

	for item in conflicts:
		Log.trace("Removing conflicting %s", item)
		items.erase(item)
		item_removed.emit(item)

	if swatch and not new_item.swatches.has(swatch):
		Log.warn("Skipping '%s' which does not belong to adding %s", swatch, new_item)
		swatch = null

	items[new_item] = swatch
	item_applied.emit(new_item, swatch)


## Removes the item if present.
func remove(item: LookItem) -> void:
	if not items.erase(item):
		return

	Log.trace("Removing %s", item)
	item_removed.emit(item)


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

		apply(new_item, new_items[new_item])
