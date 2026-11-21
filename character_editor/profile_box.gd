extends VBoxContainer

@onready var _first_name_edit: LineEdit = %FirstName
@onready var _last_name_edit: LineEdit = %LastName

@onready var _male_button: Button = %Male
@onready var _female_button: Button = %Female
@onready var _customize_button: Button = %Customize

@onready var _animations_row: HBoxContainer = $AnimationsRow
@onready var _feminine_button: Button = %Feminine
@onready var _masculine_button: Button = %Masculine

@export var _gender_group: ButtonGroup
@export var _animation_group: ButtonGroup


func _on_current_member_changed(previous: Character, current: Character) -> void:
	if previous:
		_disconnect_character()

	_load_state(current)
	_connect_character(current)


func _disconnect_character() -> void:
	_first_name_edit.text_changed.disconnect(_set_first_name)
	_last_name_edit.text_changed.disconnect(_set_last_name)
	_gender_group.pressed.disconnect(_set_gender)
	_animation_group.pressed.disconnect(_set_animation)


func _connect_character(character: Character) -> void:
	_first_name_edit.text_changed.connect(_set_first_name.bind(character))
	_last_name_edit.text_changed.connect(_set_last_name.bind(character))
	_gender_group.pressed.connect(_set_gender.bind(character))
	_animation_group.pressed.connect(_set_animation.bind(character))


func _load_state(character: Character) -> void:
	_first_name_edit.text = character.first_name
	_last_name_edit.text = character.last_name

	# TODO: once more options are available and they don't
	# strictly match male or female, select the customize button.
	if character.visual.anim_style == CharacterVisual.AnimationStyle.MASCULINE:
		_male_button.button_pressed = true
		_masculine_button.button_pressed = true
	else:
		_female_button.button_pressed = true
		_feminine_button.button_pressed = true
	_animations_row.visible = false


func _set_first_name(value: String, character: Character) -> void:
	character.first_name = value


func _set_last_name(value: String, character: Character) -> void:
	character.last_name = value


func _set_gender(button: Button, character: Character) -> void:
	match button:
		_male_button:
			_set_animation(_masculine_button, character)
		_female_button:
			_set_animation(_feminine_button, character)

	_animations_row.visible = button == _customize_button


func _set_animation(button: Button, character: Character) -> void:
	if button.button_pressed:
		return

	button.button_pressed = true
	character.visual.anim_style = _get_animation_style(button)


func _get_animation_style(button: Button) -> CharacterVisual.AnimationStyle:
	match button:
		_feminine_button:
			return CharacterVisual.AnimationStyle.FEMININE
		_masculine_button:
			return CharacterVisual.AnimationStyle.MASCULINE
		_:
			push_error("%s is not an animation button" % button)
			return CharacterVisual.AnimationStyle.FEMININE
