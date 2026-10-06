@tool
class_name MHBody
extends Resource
## Basemesh configuration.

signal body_changed(dirty: MHBodyInstance.Dirty)

@export var geometry: MHBodyGeometry:
	set = set_geometry

@export var vertex_groups: MHVertexGroups:
	set = set_vertex_groups

@export var target_registry: MHTargetRegistry:
	set = set_target_registry

@export var macro_registry: MHMacroRegistry:
	set = set_macro_registry

@export var rig: MHRig:
	set = set_rig

@export var rig_weights: MHRigWeights:
	set = set_rig_weights

## Lazy-initialized skinning shared across all instances with this resource.
var skinning: MHSkinning:
	get = get_skinning

var _proxy_skinnings: Dictionary[int, MHSkinning]


func set_geometry(value: MHBodyGeometry) -> void:
	if geometry == value:
		return

	geometry = value
	skinning = null
	_proxy_skinnings.clear()
	body_changed.emit(MHBodyInstance.Dirty.ALL)


func set_vertex_groups(value: MHVertexGroups) -> void:
	if vertex_groups == value:
		return

	vertex_groups = value
	body_changed.emit(MHBodyInstance.Dirty.VERTEX_GROUPS)


func set_target_registry(value: MHTargetRegistry) -> void:
	if target_registry == value:
		return

	target_registry = value
	body_changed.emit(MHBodyInstance.Dirty.TARGETS)


func set_macro_registry(value: MHMacroRegistry) -> void:
	if macro_registry == value:
		return

	macro_registry = value
	body_changed.emit(MHBodyInstance.Dirty.MACROS)


func set_rig(value: MHRig) -> void:
	if rig == value:
		return

	rig = value
	skinning = null
	_proxy_skinnings.clear()
	body_changed.emit(MHBodyInstance.Dirty.RIG)


func set_rig_weights(value: MHRigWeights) -> void:
	if rig_weights == value:
		return

	rig_weights = value
	skinning = null
	_proxy_skinnings.clear()
	body_changed.emit(MHBodyInstance.Dirty.WEIGHTS)


func get_skinning() -> MHSkinning:
	if not skinning and rig and rig_weights and geometry:
		skinning = MHSkinning.new()
		skinning.build_from_rig(geometry, rig, rig_weights)

	return skinning


## Returns if all required resources are set.
func is_complete() -> bool:
	return geometry and vertex_groups and target_registry and macro_registry and rig and rig_weights


func get_modifier_info(modifier_name: StringName) -> ModifierInfo:
	var info := ModifierInfo.new()
	if macro_registry.macrotargets.has(modifier_name):
		info.default_value = MHMacroRegistry.DEFAULT_VALUE
		info.is_macro = true
	elif modifier_name in MHMacroRegistry.RACES:
		info.default_value = MHMacroRegistry.DEFAULT_RACE_VALUE
		info.is_macro = true
	else:
		info.default_value = MHTargetRegistry.DEFAULT_VALUE
		info.is_macro = false

	return info


func get_proxy_skinning(proxy: MHProxy) -> MHSkinning:
	var id := proxy.get_instance_id()
	var proxy_skinning: MHSkinning = _proxy_skinnings.get(id)
	if not proxy_skinning:
		proxy_skinning = MHSkinning.new()
		proxy_skinning.build_from_proxy(skinning, proxy)
		_proxy_skinnings[id] = proxy_skinning
		# TODO: Add cleanup after this fix is merged:
		# https://github.com/godotengine/godot/pull/122655

	return proxy_skinning


class ModifierInfo:
	var default_value: float
	var is_macro: bool
