@tool
class_name MakeHumanVisual
extends CharacterVisual

@onready var body_instance: MHBodyInstance = %Body

var _attachments: Dictionary[LookItem, Object]


func _attach_item(item: LookItem) -> bool:
	if _attachments.has(item):
		return false

	var attachment := _create_attachment(item.asset_path)
	if not attachment:
		return false

	var material := attachment as StandardMaterial3D
	if material:
		body_instance.material_override = material
	else:
		body_instance.add_child(attachment)

	_attachments[item] = attachment
	return true


static func _create_attachment(asset_path: String) -> Object:
	var res := ResourceLoader.load(asset_path)
	if not res:
		Log.error("Unable to load '%s'", asset_path)
		return null

	var material := res as StandardMaterial3D
	if material:
		return material

	var proxy := res as MHProxy
	if proxy:
		# Allow paths to a proxy for simple items.
		var instance := MHProxyInstance.new()
		instance.proxy = proxy
		return instance

	var scene := res as PackedScene
	if scene:
		var node := scene.instantiate()
		if not node:
			Log.error("Unable to instantiate '%s'", asset_path)
			return null

		var instance := node as MHProxyInstance
		if not instance:
			Log.error("PackedScene '%s' root is not an MHProxyInstance", asset_path)
			node.free()
			return null

		return instance

	Log.error(
		"'%s' must be a StandardMaterial3D, MHProxy resource, or PackedScene with an MHProxyInstance root",
		asset_path,
	)
	return null


func _detach_item(item: LookItem) -> void:
	var attachment: Object = _attachments.get(item)
	if not attachment:
		return

	var material := attachment as StandardMaterial3D
	if material:
		# A conflicting material may already have replaced this one.
		if body_instance.material_override == material:
			body_instance.material_override = null
	else:
		var instance := attachment as MHProxyInstance
		instance.queue_free()

	_attachments.erase(item)


func get_item_dir() -> String:
	return "res://characters/visuals/make_human/items/"


func _get_modifiers_dir() -> String:
	return "res://characters/visuals/make_human/modifiers/"


func _resolve_modifier_params(
	modifiers: Dictionary[StringName, BodyModifier]
) -> Array[BodyModifierParams]:
	var params: Array[BodyModifierParams] = []

	var body := body_instance.body
	if not body or not body.target_registry or not body.macro_registry:
		return params

	for modifier_name in body.macro_registry.macrotargets:
		_add_modifier_params(
			params,
			modifiers,
			modifier_name,
			MHMacroRegistry.RANGE,
			MHMacroRegistry.DEFAULT_VALUE,
		)

	for race in MHMacroRegistry.RACES:
		_add_modifier_params(
			params,
			modifiers,
			race,
			MHMacroRegistry.RANGE,
			MHMacroRegistry.DEFAULT_RACE_VALUE,
		)

	for section in body.target_registry.sections:
		for category in section.categories:
			_add_category_params(params, modifiers, category)

	return params


static func _add_category_params(
	result: Array[BodyModifierParams],
	modifiers_by_name: Dictionary[StringName, BodyModifier],
	category: MHTargetCategory,
) -> void:
	if category.opposites:
		_add_modifier_params(
			result,
			modifiers_by_name,
			category.label,
			MHTargetRegistry.OPPOSITE_RANGE,
			MHTargetRegistry.DEFAULT_VALUE,
			category.has_left_and_right,
		)
		return

	for target_name in category.targets:
		_add_modifier_params(
			result,
			modifiers_by_name,
			target_name,
			MHTargetRegistry.RANGE,
			MHTargetRegistry.DEFAULT_VALUE,
		)


static func _add_modifier_params(
	result: Array[BodyModifierParams],
	modifiers: Dictionary[StringName, BodyModifier],
	modifier_name: StringName,
	value_range: Vector2,
	default_value: float,
	has_left_and_right := false,
) -> void:
	var modifier: BodyModifier = modifiers.get(modifier_name)
	if not modifier:
		return

	result.append(BodyModifierParams.new(modifier, value_range, default_value, has_left_and_right))
	modifiers.erase(modifier_name)


func get_left_modifier_suffix() -> StringName:
	return "/left"


func get_right_modifier_suffix() -> StringName:
	return "/right"


func get_modifier(key: StringName) -> float:
	return body_instance.get_modifier(key)


func set_modifier(key: StringName, value: float) -> void:
	body_instance.set_modifier(key, value)
