class_name ModifierBox
extends VBoxContainer

signal modifier_changed(key: StringName, value: float)

@onready var _label: Label = %Label
@onready var _link: Button = %Link

@onready var _slider_box: HBoxContainer = $SliderBox
@onready var _slider: HSlider = %Slider
@onready var _spin_box: SpinBox = %SpinBox

@onready var _left_slider_box: HBoxContainer = $LeftSliderBox
@onready var _left_slider: HSlider = %LeftSlider
@onready var _left_spin_box: SpinBox = %LeftSpinBox

@onready var _right_slider_box: HBoxContainer = $RightSliderBox
@onready var _right_slider: HSlider = %RightSlider
@onready var _right_spin_box: SpinBox = %RightSpinBox

var _params: BodyModifierParams
var _left_key: StringName
var _right_key: StringName


## Stores modifier parameters.
##
## Called once before `_ready`.
func setup(params: BodyModifierParams, left_suffix: StringName, right_suffix: StringName) -> void:
	_params = params
	_left_key = params.modifier.key + left_suffix
	_right_key = params.modifier.key + right_suffix


func _ready() -> void:
	_label.text = _params.modifier.name
	if not _params.modifier.min_label.is_empty() and not _params.modifier.max_label.is_empty():
		_label.tooltip_text = "%s / %s" % [_params.modifier.min_label, _params.modifier.max_label]

	_setup_slider(_slider, _spin_box)

	if _params.has_left_and_right:
		_setup_slider(_left_slider, _left_spin_box)
		_setup_slider(_right_slider, _right_spin_box)
		_link.visible = true


func _setup_slider(slider: HSlider, spin_box: SpinBox) -> void:
	slider.min_value = _params.value_range.x
	slider.max_value = _params.value_range.y
	slider.set_value_no_signal(_params.default_value)

	spin_box.set_block_signals(true)
	slider.share(spin_box)
	spin_box.set_block_signals(false)


func _emit_modifier_changed(value: float) -> void:
	if _params.has_left_and_right:
		modifier_changed.emit(_right_key, value)
		modifier_changed.emit(_left_key, value)
	else:
		modifier_changed.emit(_params.modifier.key, value)


func _emit_left_modifier_changed(value: float) -> void:
	modifier_changed.emit(_left_key, value)


func _emit_right_modifier_changed(value: float) -> void:
	modifier_changed.emit(_right_key, value)


func _set_linked(linked: bool) -> void:
	if linked:
		Log.debug("Linking modifier '%s'", _params.modifier.key)
		# The left side wins when linking unequal values.
		_slider.set_value_no_signal(_left_slider.value)

		if not is_equal_approx(_slider.value, _right_slider.value):
			modifier_changed.emit(_right_key, _slider.value)
	else:
		Log.debug("Unlinking modifier '%s'", _params.modifier.key)
		_left_slider.set_value_no_signal(_slider.value)
		_right_slider.set_value_no_signal(_slider.value)

	_apply_link_visibility(linked)


## Loads the shown values without emitting [signal modifier_changed].
func load_value(visual: CharacterVisual) -> void:
	if _params.has_left_and_right:
		var left_value := visual.get_modifier(_left_key)
		var right_value := visual.get_modifier(_right_key)
		var linked := is_equal_approx(left_value, right_value)

		_link.set_pressed_no_signal(linked)
		if linked:
			_slider.set_value_no_signal(left_value)
		else:
			_left_slider.set_value_no_signal(left_value)
			_right_slider.set_value_no_signal(right_value)
		_apply_link_visibility(linked)
	else:
		_slider.set_value_no_signal(visual.get_modifier(_params.modifier.key))


func _apply_link_visibility(linked: bool) -> void:
	_slider_box.visible = linked
	_left_slider_box.visible = not linked
	_right_slider_box.visible = not linked
