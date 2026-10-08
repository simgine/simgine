extends VBoxContainer

@onready var _body_tab: BodyTab = %Body
@onready var _features_tab: FeaturesTab = %Features


func _show_character(character: Character) -> void:
	Log.debug("Loading appearance for '%s'", character.name)
	_body_tab.show_character(character.visual)
	_features_tab.show_character(character.visual)
