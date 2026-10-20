extends VBoxContainer

signal animation_style_changed(style: Character.AnimationStyle)

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


func _ready() -> void:
	_gender_group.pressed.connect(_select_gender)
	_animation_group.pressed.connect(_select_animation)


## Fills the fields when the current member changes.
func _show_character(character: Character) -> void:
	_first_name_edit.text = character.first_name
	_last_name_edit.text = character.last_name

	# TODO: once more options are available and they don't
	# strictly match male or female, select the customize button.
	if character.animation_style == Character.AnimationStyle.MASCULINE:
		_male_button.button_pressed = true
	else:
		_female_button.button_pressed = true


func _select_gender(button: Button) -> void:
	match button:
		_male_button:
			_set_animation_style(Character.AnimationStyle.MASCULINE)
		_female_button:
			_set_animation_style(Character.AnimationStyle.FEMININE)

	_animations_row.visible = button == _customize_button


func _select_animation(button: Button) -> void:
	match button:
		_feminine_button:
			_set_animation_style(Character.AnimationStyle.FEMININE)
		_masculine_button:
			_set_animation_style(Character.AnimationStyle.MASCULINE)


func _set_animation_style(style: Character.AnimationStyle) -> void:
	var button := _get_animation_button(style)
	if button.button_pressed:
		return

	button.button_pressed = true
	animation_style_changed.emit(style)


func _get_animation_button(style: Character.AnimationStyle) -> Button:
	match style:
		Character.AnimationStyle.FEMININE:
			return _feminine_button
		Character.AnimationStyle.MASCULINE:
			return _masculine_button

	return null
