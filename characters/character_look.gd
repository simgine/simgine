class_name CharacterLook
extends Resource
## The set of [LookItem]s equipped on a [CharacterVisual].

signal item_added(item: LookItem)
signal item_removed(item: LookItem)

@export var items: Array[LookItem]


## Adds the item, removing the items it conflicts with.
func add(new_item: LookItem) -> void:
	# Iterate backwards since items might be removed.
	for index in range(items.size() - 1, -1, -1):
		var item := items[index]
		if item == new_item:
			return

		if new_item.conflicts_with(item):
			items.remove_at(index)
			item_removed.emit(item)

	Log.trace("Adding %s", new_item)
	items.append(new_item)
	item_added.emit(new_item)


## Removes items that are null, without a slot or conflict with a later item.
##
## Of two conflicting items, the later one wins.
func remove_invalid() -> void:
	# Iterate backwards since items might be removed.
	for index in range(items.size() - 1, -1, -1):
		var item := items[index]
		if not item or not item.slot:
			items.remove_at(index)
			if item:
				item_removed.emit(item)
			continue

		for later_index in range(index + 1, items.size()):
			if item.conflicts_with(items[later_index]):
				items.remove_at(index)
				item_removed.emit(item)
				break


## Removes the item.
##
## Returns whether it was equipped.
func remove(item: LookItem) -> bool:
	var idx := items.find(item)
	if idx == -1:
		return false

	Log.trace("Removing %s", item)
	items.remove_at(idx)
	item_removed.emit(item)
	return true


## Returns the equipped item of the given slot.
##
## Returns `null` if the slot is empty.
func get_item(slot: LookSlot) -> LookItem:
	for item in items:
		if item and item.slot == slot:
			return item

	return null
