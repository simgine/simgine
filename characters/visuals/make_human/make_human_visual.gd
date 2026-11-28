@tool
class_name MakeHumanVisual
extends CharacterVisual

const SKIN_SLOT := preload("res://characters/look_slots/skin.tres")

@onready var body_instance: MHBodyInstance = %Body

## Runtime attachments for items that add a proxy mesh.
var _proxy_attachments: Dictionary[LookItem, ProxyAttachment]


func _apply_item(item: LookItem, swatch: LookSwatch) -> void:
	if item.slot == SKIN_SLOT:
		_apply_skin(item, swatch)
	else:
		_apply_proxy(item, swatch)


func _apply_skin(item: LookItem, swatch: LookSwatch) -> void:
	var material := ResourceLoader.load(item.asset_path) as Material
	if not material:
		Log.error("Skin asset '%s' must be a Material", item.asset_path)
		return

	_apply_swatch(body_instance, material, swatch)


func _apply_proxy(item: LookItem, swatch: LookSwatch) -> void:
	var attachment: ProxyAttachment = _proxy_attachments.get(item)
	if not attachment:
		var asset := ResourceLoader.load(item.asset_path)
		if not asset:
			Log.error("Unable to load '%s'", item.asset_path)
			return

		attachment = ProxyAttachment.from_asset(asset)
		if not attachment:
			return

		body_instance.add_child(attachment.instance)
		_proxy_attachments[item] = attachment

	_apply_swatch(attachment.instance, attachment.default_material, swatch)


## Applies a swatch material to the mesh, or uses the default material if the swatch is null.
##
## For skin materials, the mesh is the body. For proxy materials, it's the proxy instance.
static func _apply_swatch(
	mesh: MeshInstance3D,
	default_material: Material,
	swatch: LookSwatch,
) -> void:
	if not swatch:
		mesh.material_override = default_material
		return

	var material := ResourceLoader.load(swatch.asset_path) as Material
	if not material:
		Log.error("Swatch asset '%s' must be a Material", swatch.asset_path)
		return

	mesh.material_override = material


func _detach_item(item: LookItem) -> void:
	if item.slot == SKIN_SLOT:
		body_instance.material_override = null
		return

	var attachment: ProxyAttachment = _proxy_attachments.get(item)
	if attachment:
		attachment.instance.queue_free()
		_proxy_attachments.erase(item)


func get_item_mesh(item: LookItem) -> MeshInstance3D:
	var attachment: ProxyAttachment = _proxy_attachments.get(item)
	return attachment.instance if attachment else null


func get_item_dir() -> String:
	return "res://characters/visuals/make_human/items/"


func get_pose_dir() -> String:
	return "res://characters/visuals/make_human/data/poses/"


func get_modifiers_dir() -> String:
	return "res://characters/visuals/make_human/modifiers/"


func get_thumbnail_scene_path() -> String:
	return "res://characters/visuals/make_human/make_human_thumbnail_scene.tscn"


func get_skeleton_profile() -> StringName:
	return "SkeletonProfileHumanoid"


func resolve_modifier_params(
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


func get_bone_position(bone_name: String) -> Vector3:
	var skeleton := body_instance.skeleton_node
	if not skeleton:
		return Vector3.ZERO

	var bone_idx := skeleton.find_bone(bone_name)
	if bone_idx < 0:
		return Vector3.ZERO

	var bone_transform := skeleton.get_bone_global_pose(bone_idx)
	return skeleton.global_transform * bone_transform.origin


func get_modifier(key: StringName) -> float:
	return body_instance.get_modifier(key)


func get_gender_modifier_name() -> StringName:
	return "gender"


func _apply_modifier(key: StringName, value: float) -> void:
	body_instance.set_modifier(key, value)


func set_pose(pose: Pose) -> void:
	var skeleton := body_instance.skeleton_node
	if not skeleton:
		return

	if not pose:
		skeleton.pose = null
		return

	var res := ResourceLoader.load(pose.asset_path)
	if not res:
		Log.warn("Unable to load '%s'", pose.asset_path)
		return

	var mh_pose := res as MHPose
	if not mh_pose:
		Log.warn("'%s' must be an MHPose", pose.asset_path)
		return

	skeleton.pose = mh_pose


class ProxyAttachment:
	var instance: MHProxyInstance

	## The [member GeometryInstance3D.material_override] on [member instance] before any swatch is applied.
	##
	## Restored when the swatch is cleared.
	var default_material: Material


	func _init(p_instance: MHProxyInstance) -> void:
		instance = p_instance
		default_material = instance.material_override


	static func from_asset(asset: Resource) -> ProxyAttachment:
		var proxy := asset as MHProxy
		if proxy:
			# Allow paths to a proxy for simple items.
			var proxy_instance := MHProxyInstance.new()
			proxy_instance.proxy = proxy
			return ProxyAttachment.new(proxy_instance)

		var scene := asset as PackedScene
		if scene:
			var node := scene.instantiate()
			if not node:
				Log.error("Unable to instantiate '%s'", asset.resource_path)
				return null

			var proxy_instance := node as MHProxyInstance
			if not proxy_instance:
				Log.error("PackedScene '%s' root is not an MHProxyInstance", asset.resource_path)
				node.free()
				return null

			return ProxyAttachment.new(proxy_instance)

		Log.error(
			"'%s' must be an MHProxy or a PackedScene with an MHProxyInstance root",
			asset.resource_path,
		)
		return null
