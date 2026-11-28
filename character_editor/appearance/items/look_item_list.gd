class_name LookItemList
extends ItemList

signal look_item_applied(item: LookItem, swatch: LookSwatch)
signal look_item_deselected(item: LookItem)
signal thumbnail_requested(item: LookItem, swatch: LookSwatch, texture: ImageTexture)

var _items: Array[LookItem]
var _item_indices: Dictionary[LookItem, int]

## Previews for items.
##
## The inner dictionary maps swatches to their textures.
## A null swatch uses the item's default appearance.
## An entry may still be waiting to render.
var _thumbnails: Dictionary[LookItem, Dictionary]

## The selected swatch for each item.
##
## An absent entry uses the item's default appearance.
var _item_swatches: Dictionary[LookItem, LookSwatch]

var _hovered_rect: Rect2
var _hovered_item: LookItem

@onready var _swatch_button: Button = $SwatchButton
@onready var _swatch_popup: SwatchPopup = $SwatchPopup

## Placeholder icon for unrendered items.
@onready var _placeholder: ImageTexture = _create_item_texture()


func _ready() -> void:
	get_v_scroll_bar().value_changed.connect(_update_visible_icons.unbind(1))
	get_v_scroll_bar().value_changed.connect(_update_hovered_item.unbind(1))
	# The parent populates the list just after adding it to the tree.
	_update_visible_icons.call_deferred()


func add_look_item(item: LookItem) -> void:
	_items.append(item)
	var index := add_item("", _placeholder)
	set_item_tooltip(index, _build_tooltip(item))
	_item_indices[item] = index


## Builds the item's tooltip, appending author and license credits when set.
static func _build_tooltip(item: LookItem) -> String:
	var tooltip := item.name
	if not item.author.is_empty():
		tooltip += "\nAuthor: %s" % item.author
	if not item.license.is_empty():
		tooltip += "\nLicense: %s" % item.license
	return tooltip


func select_item(item: LookItem, swatch: LookSwatch = null) -> void:
	var index := _item_indices[item]
	select(index)

	if _item_swatches.get(item) == swatch:
		return

	if swatch:
		_item_swatches[item] = swatch
	else:
		_item_swatches.erase(item)

	if _is_item_visible(index):
		var icon := _get_or_request_thumbnail(item, swatch)
		set_item_icon(index, icon)
	else:
		# Will be updated later in _update_visible_icons
		set_item_icon(index, _placeholder)


func _is_item_visible(index: int) -> bool:
	if not is_visible_in_tree():
		return false

	var item_range := _get_visible_item_range()
	return index >= item_range.x and index < item_range.y


func deselect_item(item: LookItem) -> void:
	deselect(_item_indices[item])


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_update_hovered_item()


func _on_multi_selected(index: int, selected: bool) -> void:
	var item := _items[index]
	if selected:
		look_item_applied.emit(item, _item_swatches.get(item))
	elif item.slot.permanent:
		# Undo the deselection.
		select(index)
	else:
		look_item_deselected.emit(item)


func _update_visible_icons() -> void:
	if not is_visible_in_tree():
		return

	var item_range := _get_visible_item_range()
	for index in range(item_range[0], item_range[1]):
		if get_item_icon(index) == _placeholder:
			var item := _items[index]
			var icon := _get_or_request_thumbnail(item, _item_swatches.get(item))
			set_item_icon(index, icon)


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

	var swatches: Dictionary[LookSwatch, ImageTexture]
	swatches[null] = _get_or_request_thumbnail(_hovered_item)
	for swatch in _hovered_item.swatches:
		swatches[swatch] = _get_or_request_thumbnail(_hovered_item, swatch)

	_swatch_popup.display(icon_rect, swatches)


## Applies swatch selection from the popup.
##
## The popup's item indices mirror the order of the dictionary passed to it:
## item 0 is the default appearance, the rest are the [member LookItem.swatches].
func _apply_popup_swatch(index: int) -> void:
	var swatch: LookSwatch
	if index > 0:
		swatch = _hovered_item.swatches[index - 1]
	select_item(_hovered_item, swatch)
	look_item_applied.emit(_hovered_item, swatch)


func _get_or_request_thumbnail(item: LookItem, swatch: LookSwatch = null) -> ImageTexture:
	var variants: Dictionary = _thumbnails.get_or_add(item, { })
	var texture: ImageTexture = variants.get(swatch)
	if texture:
		return texture

	# We create a new icon instead of duplicating the old placeholder
	# because it causes GPU -> CPU readback.
	texture = _create_item_texture()
	variants[swatch] = texture

	# The preview renderer fills the texture once the item is rendered.
	thumbnail_requested.emit(item, swatch, texture)

	return texture


## Creates a placeholder texture for an item icon.
func _create_item_texture() -> ImageTexture:
	const PLACEHOLDER_COLOR := Color(1, 1, 1, 0.15)
	var icon_size := get_fixed_icon_size()
	var image := Image.create_empty(icon_size.x, icon_size.y, false, Image.FORMAT_RGBA8)
	image.fill(PLACEHOLDER_COLOR)
	return ImageTexture.create_from_image(image)
