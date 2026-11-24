class_name SwatchButton
extends Button

## Inset of the button from the item icon's top-right corner.
@export var _margin := 4.0

var _item: LookItem


## Shows the button over the item icon if the item has swatches,
## hiding it otherwise.
func set_hovered_item(item: LookItem, icon_rect: Rect2) -> void:
	_item = item
	visible = item and not item.swatches.is_empty()
	if visible:
		# Anchor the button to the icon's top-right corner.
		position = Vector2(icon_rect.end.x - _margin - size.x, icon_rect.position.y + _margin)
