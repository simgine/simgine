extends VBoxContainer
## The appearance section of the family editor.
##
## Shows an [AppearanceView] per [CharacterVisual] type and
## loads the member's current state into it.

signal modifier_changed(key: StringName, value: float)
signal item_selected(item: LookItem)

var _current_view: AppearanceView

## Cached views for different [CharacterVisual] types.
var _views: Dictionary[GDScript, AppearanceView]


func _show_character(character: Character) -> void:
	Log.debug("Loading appearance for '%s'", character.name)

	var visual := character.visual
	var key: GDScript = visual.get_script()
	if not _views.has(key):
		_views[key] = _create_view(visual)

	var view := _views[key]
	if _current_view != view:
		if _current_view:
			_current_view.hide()

		_current_view = view
		view.show()

	view.load_state(visual)


func _create_view(visual: CharacterVisual) -> AppearanceView:
	const APPEARANCE_VIEW := preload("res://family_editor/appearance/appearance_view.tscn")
	var view: AppearanceView = APPEARANCE_VIEW.instantiate()

	# The view must be in the tree before populating,
	# since we access @onready members later.
	add_child(view)

	view.body_tab.modifier_changed.connect(modifier_changed.emit)
	view.body_tab.populate(visual)

	view.features_tab.item_selected.connect(item_selected.emit)
	view.features_tab.populate(LookItem.load_from(visual.get_item_dir()))

	return view
