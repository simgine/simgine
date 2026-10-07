extends VBoxContainer

@onready var _body_tab: BodyTab = %Body


func _show_character(character: Character) -> void:
	Log.debug("Loading appearance for '%s'", character.name)
	_body_tab.show_character(character.visual)
