class_name AddCharacterButton
extends UpMenuButton

signal type_selected(character_type: CharacterType)

var _types: Array[CharacterType]


func _ready() -> void:
	super()

	_types = CharacterType.get_available()
	for index in _types.size():
		var type_name := _types[index].name
		get_popup().add_item(type_name, index)
		Log.debug("Added '%s' to menu", type_name)

	get_popup().id_pressed.connect(_emit_type_selected)


func _emit_type_selected(id: int) -> void:
	var type := _types[id]
	Log.info("Selected '%s'", type.name)
	type_selected.emit(type)
