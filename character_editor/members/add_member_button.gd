class_name AddMemberButton
extends UpMenuButton

signal type_selected(character_type: CharacterType)

var _types: Array[CharacterType] = CharacterType.load_all()


func _ready() -> void:
	super()

	for type in _types:
		get_popup().add_item(type.name)
		Log.debug("Added '%s' to menu", type.name)

	get_popup().index_pressed.connect(_emit_type_selected)


func _emit_type_selected(index: int) -> void:
	var type := _types[index]
	Log.info("Selected '%s'", type.name)
	type_selected.emit(type)
