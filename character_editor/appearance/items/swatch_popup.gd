class_name SwatchPopup
extends PopupPanel
## A popup that shows the swatches of a [LookItem].

@onready var _list: ItemList = $ItemList

## Catches clicks outside the popup so they don't reach any other controls.
var _click_catcher: Control

static var _placeholder: Texture2D = _create_placeholder()


static func _create_placeholder() -> Texture2D:
	var image := Image.create_empty(60, 80, false, Image.FORMAT_RGBA8)
	return ImageTexture.create_from_image(image)


## Shows the popup with [param item]'s swatches.
##
## Centers horizontally below [param icon_rect],
## which is defined in screen coordinates.
func display(item: LookItem, icon_rect: Rect2) -> void:
	_populate(item)

	# The popup is its own window, so position it in screen coordinates.
	var popup_size := _calculate_size(item.swatches.size())
	var popup_pos := Vector2i(
		int(icon_rect.get_center().x - popup_size.x / 2.0),
		int(icon_rect.end.y),
	)
	_show_click_catcher()

	popup(Rect2i(popup_pos, popup_size))


func _populate(item: LookItem) -> void:
	_list.clear()
	for swatch in item.swatches:
		var index := _list.add_item("", _placeholder)
		_list.set_item_tooltip(index, swatch.name)


func _calculate_size(item_count: int) -> Vector2i:
	const ROWS := 2 # Number of rows before the list scrolls.

	var icon_size := _list.get_fixed_icon_size()
	var h_separation := _list.get_theme_constant("h_separation")
	var v_separation := _list.get_theme_constant("v_separation")
	var col_width := _list.get_fixed_column_width()
	var cell := Vector2(col_width + h_separation, icon_size.y + v_separation)

	var columns := _list.get_max_columns()
	var list_size := cell * Vector2(columns, ROWS)
	if item_count > columns * ROWS:
		const SCROLL_GAP := 4
		list_size.x += _list.get_v_scroll_bar().get_minimum_size().x + SCROLL_GAP

	var list_padding := _list.get_theme_stylebox("panel").get_minimum_size()
	var popup_padding := get_theme_stylebox("panel").get_minimum_size()
	return Vector2i(list_size + list_padding + popup_padding)


## Adds a click catcher over the root window, so the click dismissing
## the popup is not passed to the controls underneath it.
func _show_click_catcher() -> void:
	assert(
		not _click_catcher,
		"The click catcher blocks outside clicks, so you can't open another popup while the current one is still open",
	)

	_click_catcher = Control.new()
	_click_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_click_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(_click_catcher)


func _remove_click_catcher() -> void:
	_click_catcher.queue_free()
