class_name LookItemList
extends ItemList

signal look_item_selected(item: LookItem)
signal look_item_deselected(item: LookItem)
signal preview_requested(item: LookItem)

var slot: LookSlot
var _items: Array[LookItem]
var _item_indices: Dictionary[LookItem, int]

## Items whose previews were already requested.
var _previewed: Dictionary[LookItem, bool]

var _hovered_rect: Rect2
var _hovered_item: LookItem

@onready var _swatch_button: Button = $SwatchButton
@onready var _swatch_popup: SwatchPopup = $SwatchPopup

static var _placeholder: Texture2D = _create_placeholder()


static func _create_placeholder() -> Texture2D:
	var image := Image.create_empty(150, 200, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0.15))
	return ImageTexture.create_from_image(image)


func _ready() -> void:
	get_v_scroll_bar().value_changed.connect(_check_visible_previews.unbind(1))
	get_v_scroll_bar().value_changed.connect(_update_hovered_item)


func add_look_item(item: LookItem) -> void:
	_items.append(item)
	var index := add_item("", _placeholder)
	set_item_tooltip(index, _build_tooltip(item))
	_item_indices[item] = index
	_check_visible_previews()


## Builds the item's tooltip, appending author and license credits when set.
static func _build_tooltip(item: LookItem) -> String:
	var tooltip := item.name
	if not item.author.is_empty():
		tooltip += "\nAuthor: %s" % item.author
	if not item.license.is_empty():
		tooltip += "\nLicense: %s" % item.license
	return tooltip


func select_item(item: LookItem) -> void:
	select(_item_indices[item])


func deselect_item(item: LookItem) -> void:
	deselect(_item_indices[item])


## Sets the rendered preview as the item's icon.
func set_item_preview(item: LookItem, texture: ImageTexture) -> void:
	set_item_icon(_item_indices[item], texture)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_update_hovered_item()


func _on_multi_selected(index: int, selected: bool) -> void:
	# Undo the selection and only emit signals.
	# The state will be updated via signals from CharacterVisual.
	if selected:
		deselect(index)
		look_item_selected.emit(_items[index])
	else:
		select(index)
		# Ignore deselection if the slot is required.
		if not slot.permanent:
			look_item_deselected.emit(_items[index])


func _check_visible_previews() -> void:
	if not is_visible_in_tree() or _previewed.size() == _items.size():
		return

	var item_range := _get_visible_item_range()
	for index in range(item_range[0], item_range[1]):
		var item := _items[index]
		if not _previewed.has(item):
			_previewed[item] = true
			preview_requested.emit(item)


## Returns the visible items as a `[first, end)` index range.
func _get_visible_item_range() -> Vector2i:
	var items_count := _items.size()
	if items_count == 0:
		return Vector2i(0, 0)

	var icon_size := get_fixed_icon_size()
	assert(icon_size != Vector2i.ZERO)
	var panel := get_theme_stylebox("panel")
	var content_height := size.y - (panel.get_margin(SIDE_TOP) + panel.get_margin(SIDE_BOTTOM))
	var row_height := icon_size.y + get_theme_constant("v_separation")

	var scroll_bar := get_v_scroll_bar()
	var first_row := int(scroll_bar.value / row_height)
	var last_row := int((scroll_bar.value + content_height) / row_height)
	if float(last_row) * row_height >= scroll_bar.value + content_height:
		# The window's bottom edge landed exactly on a row boundary.
		last_row -= 1

	var columns := get_max_columns()
	assert(columns > 0)
	@warning_ignore("integer_division")
	var rows := (items_count + columns - 1) / columns

	last_row = mini(last_row, rows - 1)

	var start := first_row * columns
	var end := mini(last_row * columns + columns, items_count)

	return Vector2i(start, end)


func _update_hovered_item() -> void:
	var index := get_item_at_position(get_local_mouse_position(), true)
	var item: LookItem
	var icon_rect: Rect2
	if index >= 0:
		item = _items[index]
		icon_rect = _get_item_icon_rect(index)

	if item == _hovered_item and icon_rect == _hovered_rect:
		return

	_hovered_item = item
	_hovered_rect = icon_rect

	_swatch_button.visible = _hovered_item and not _hovered_item.swatches.is_empty()
	if _swatch_button.visible:
		# Inset of the swatch button from the item icon's bottom-right corner.
		const MARGIN := 4.0

		# Anchor the button to the icon's bottom-right corner.
		_swatch_button.position = Vector2(
			_hovered_rect.end.x - MARGIN - _swatch_button.size.x,
			_hovered_rect.end.y - MARGIN - _swatch_button.size.y,
		)


func _get_item_icon_rect(index: int) -> Rect2:
	var icon_size := Vector2(get_fixed_icon_size())
	var cell := get_item_rect(index, false)
	var origin := cell.position + ((cell.size - icon_size) / 2.0).floor()
	origin.y -= roundf(get_v_scroll_bar().value)
	return Rect2(origin, icon_size)


## Shows the swatch popup for the hovered item, below its icon.
func _show_swatch_popup() -> void:
	var icon_rect := Rect2(get_screen_position() + _hovered_rect.position, _hovered_rect.size)
	_swatch_popup.display(_hovered_item, icon_rect)
