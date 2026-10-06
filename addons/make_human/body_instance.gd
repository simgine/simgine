@tool
class_name MHBodyInstance
extends MeshInstance3D

const MODIFIERS_PREFIX := "modifiers/"

@export var body: MHBody:
	set = set_body

@export var proxy: MHProxy:
	set = set_proxy

@export var skeleton_node: MHSkeleton:
	set = set_skeleton_node

## Body shape modifier values.
@export_storage var _modifiers: Dictionary[StringName, float]

## Body vertices after applying all modifiers, scaled and moved to ground level.
##
## Stored to fit [member MHProxy.geometry] to the morphed body.
var morphed_vertices: PackedVector3Array

## Body vertices hidden by [MHProxyInstance] children.
var _mask: PackedByteArray

## Delete mask transferred from [member _mask] to [member proxy] geometry.
var _proxy_mask: PackedByteArray

## Triangle indices for the current surface with masked faces removed.
##
## Derived from [member _mask] (or [member _proxy_mask] when [member proxy] is
## set) and rebuilt only when the mask changes, so vertex-only updates reuse it
## instead of re-filtering every quad on each slider drag.
var _filtered_indices: PackedInt32Array

## Base vertices with macro modifiers applied, before target modifiers and scaling.
##
## The macro step is expensive, so caching it lets us skip reapplying
## macro modifiers when only regular target modifiers change.
## See [member morphed_vertices] for the scaled vertices with all modifiers applied.
var _macro_vertices: PackedVector3Array

enum Dirty {
	NONE = 0,
	MACROS = 1 << 0,
	TARGETS = 1 << 1,
	VERTEX_GROUPS = 1 << 2,
	MASK = 1 << 3,
	RIG = 1 << 4,
	WEIGHTS = 1 << 5,
	SKELETON = 1 << 6,
	PROXY = 1 << 7,
	MORPHS = MACROS | TARGETS,
	VERTICES = MORPHS | VERTEX_GROUPS,
	CHILD_PROXIES = VERTICES | RIG | WEIGHTS | SKELETON,
	SURFACE = VERTICES | MASK | RIG | WEIGHTS | PROXY,
	ALL = SURFACE | SKELETON,
}

var _dirty: int = Dirty.NONE


func _init() -> void:
	child_entered_tree.connect(_on_child_entered_tree)
	child_exiting_tree.connect(_on_child_exiting_tree)


func _validate_property(property: Dictionary) -> void:
	match property.name:
		"mesh", "skin":
			# Constructed dynamically from the body geometry.
			property.usage &= ~PROPERTY_USAGE_STORAGE
			property.usage |= PROPERTY_USAGE_READ_ONLY
		"skeleton":
			# Replaced by `skeleton_node`.
			property.usage &= ~PROPERTY_USAGE_EDITOR
		_:
			pass


func _get_property_list() -> Array[Dictionary]:
	if not body or not body.is_complete():
		return []

	var properties: Array[Dictionary] = []

	for macro_name in body.macro_registry.macrotargets:
		properties.append(_slider(macro_name, MHMacroRegistry.RANGE))

	for race in MHMacroRegistry.RACES:
		properties.append(_slider("race/" + race, MHMacroRegistry.RANGE))

	for section in body.target_registry.sections:
		for category in section.categories:
			_add_category(properties, section, category)

	return properties


func _add_category(
	properties: Array[Dictionary],
	section: MHTargetSection,
	category: MHTargetCategory,
) -> void:
	var path := "%s/%s" % [section.label, category.label]

	if category.opposites:
		const RANGE := MHTargetRegistry.OPPOSITE_RANGE
		if category.has_left_and_right:
			properties.append(_slider(path + "/left", RANGE))
			properties.append(_slider(path + "/right", RANGE))
		else:
			properties.append(_slider(path, RANGE))
	else:
		properties.append(_slider(path, MHTargetRegistry.RANGE))


func _slider(path: String, modifier_range: Vector2) -> Dictionary:
	return {
		"name": MODIFIERS_PREFIX + path,
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "%f,%f,0.01" % [modifier_range.x, modifier_range.y],
		"usage": PROPERTY_USAGE_EDITOR,
	}


func _get(property: StringName) -> Variant:
	if property.begins_with(MODIFIERS_PREFIX):
		var modifier_name := _property_to_modifier_name(property)
		return get_modifier(modifier_name)

	return null


func _set(property: StringName, value: Variant) -> bool:
	if property.begins_with(MODIFIERS_PREFIX):
		var modifier_name := _property_to_modifier_name(property)
		set_modifier(modifier_name, value)
		return true

	return false


func _property_to_modifier_name(property: String) -> StringName:
	# Strips prefix and inspector group.
	var separator := property.find("/", MODIFIERS_PREFIX.length())
	if separator == -1:
		# Macro modifiers don't have an inspector group.
		return property.substr(MODIFIERS_PREFIX.length())
	return property.substr(separator + 1)


func set_body(value: MHBody) -> void:
	if body == value:
		return

	if body:
		body.body_changed.disconnect(_queue_rebuild)

	body = value

	if body:
		body.body_changed.connect(_queue_rebuild)

	_queue_rebuild(Dirty.ALL)


func set_proxy(value: MHProxy) -> void:
	if proxy == value:
		return

	proxy = value
	_queue_rebuild(Dirty.PROXY)


func set_skeleton_node(value: MHSkeleton) -> void:
	if skeleton_node == value:
		return

	skeleton_node = value
	skin = null
	if skeleton_node:
		skeleton = get_path_to(skeleton_node)
	else:
		skeleton = NodePath()

	_queue_rebuild(Dirty.SKELETON)


## Returns the current value of a modifier, or its default if unset.
func get_modifier(modifier_name: StringName) -> float:
	if not body or not body.is_complete():
		push_error("modifiers can only be read on instances with fully configured bodies")
		return 0.0

	var info := body.get_modifier_info(modifier_name)
	return _modifiers.get(modifier_name, info.default_value)


func set_modifier(modifier_name: StringName, value: float) -> void:
	if not body or not body.is_complete():
		push_error("modifiers can only be set on instances with fully configured bodies")
		return

	var info := body.get_modifier_info(modifier_name)
	if is_equal_approx(value, info.default_value):
		_modifiers.erase(modifier_name)
	else:
		_modifiers[modifier_name] = value

	_queue_rebuild(Dirty.MACROS if info.is_macro else Dirty.TARGETS)


func _on_child_entered_tree(child: Node) -> void:
	var instance := child as MHProxyInstance
	if not instance:
		return

	instance.proxy_changed.connect(_on_child_proxy_changed.bind(instance))
	_on_child_proxy_changed(instance)


func _on_child_exiting_tree(child: Node) -> void:
	var instance := child as MHProxyInstance
	if not instance:
		return

	instance.proxy_changed.disconnect(_on_child_proxy_changed)
	_queue_rebuild(Dirty.MASK)


func _on_child_proxy_changed(instance: MHProxyInstance) -> void:
	_queue_rebuild(Dirty.MASK)

	if _dirty & Dirty.CHILD_PROXIES:
		return

	if body and body.is_complete():
		_rebuild_child_proxy(instance)


## Schedules a deferred rebuild, combining multiple changes into a single update.
func _queue_rebuild(dirty: Dirty) -> void:
	if _dirty == Dirty.NONE:
		# Rebuild only if it wasn't queued.
		_rebuild.call_deferred()

	_dirty |= dirty


func _rebuild() -> void:
	if not body or not body.is_complete():
		if skeleton_node:
			skeleton_node.clear_bones()
		_dirty = Dirty.NONE
		mesh = null
		skin = null
		_rebuild_child_proxies()
		return

	if not mesh:
		# Rebuild all derived state after an incomplete body becomes complete.
		_dirty |= Dirty.ALL

	if _dirty & Dirty.MACROS:
		_rebuild_macro_vertices()

	if _dirty & Dirty.MORPHS:
		_rebuild_morphed_vertices()

	if _dirty & Dirty.VERTICES:
		_move_to_ground()

	if _dirty & (Dirty.VERTICES | Dirty.RIG | Dirty.SKELETON):
		_rebuild_skeleton()

	if _dirty & Dirty.MASK:
		_rebuild_mask()

	if _dirty & (Dirty.PROXY | Dirty.MASK):
		_rebuild_proxy_mask()
		_rebuild_filtered_indices()

	if _dirty & Dirty.SURFACE:
		_rebuild_surface()

	if _dirty & Dirty.CHILD_PROXIES:
		_rebuild_child_proxies()

	_dirty = Dirty.NONE


func _rebuild_macro_vertices() -> void:
	_macro_vertices.clear()
	_macro_vertices.append_array(body.geometry.vertices)
	body.macro_registry.apply(_macro_vertices, _modifiers)


func _rebuild_morphed_vertices() -> void:
	morphed_vertices.clear()
	morphed_vertices.append_array(_macro_vertices)
	body.target_registry.apply(morphed_vertices, _modifiers)

	# MakeHuman base mesh coordinates are in decimeters (1 unit = 0.1 m).
	const SCALE_TO_METERS := 0.1
	for vertex_index in range(morphed_vertices.size()):
		morphed_vertices[vertex_index] *= SCALE_TO_METERS


func _move_to_ground() -> void:
	var lowest_y := INF

	# Exclude helper geometry when calculating the lowest point.
	var body_vertices := body.vertex_groups.ranges["body"]
	assert(body_vertices.size() == 2, "body should have a single continuous range")
	for vertex_index in range(body_vertices[0], body_vertices[1] + 1):
		lowest_y = minf(lowest_y, morphed_vertices[vertex_index].y)

	# Move all geometry, including helpers since they affect proxies.
	for vertex_index in morphed_vertices.size():
		morphed_vertices[vertex_index].y -= lowest_y


func _rebuild_skeleton() -> void:
	if not skeleton_node:
		return

	skeleton_node.rebuild(body.rig, body.vertex_groups, morphed_vertices)
	skin = skeleton_node.create_skin_from_rest_transforms()


func _rebuild_mask() -> void:
	_mask.clear()
	_mask.resize(body.geometry.vertices.size())

	for child in get_children():
		var instance := child as MHProxyInstance
		if instance and instance.proxy:
			instance.proxy.apply_delete_verts(_mask)

	body.geometry.make_mask_conservative(_mask)


func _rebuild_proxy_mask() -> void:
	_proxy_mask.clear()
	if proxy:
		proxy.transfer_delete_mask(_mask, _proxy_mask)


func _rebuild_filtered_indices() -> void:
	if proxy and proxy.geometry:
		_filtered_indices = proxy.geometry.filter_indices(_proxy_mask)
	else:
		_filtered_indices = body.geometry.filter_indices(_mask)


func _rebuild_surface() -> void:
	var array_mesh := mesh as ArrayMesh
	if not array_mesh:
		array_mesh = ArrayMesh.new()
		mesh = array_mesh

	var arrays: Array
	if proxy:
		var proxy_skinning := body.get_proxy_skinning(proxy)
		arrays = proxy.build_fitted_surface(
			morphed_vertices,
			proxy_skinning,
			_proxy_mask,
			_filtered_indices,
		)
	else:
		arrays = body.geometry.build_surface(
			morphed_vertices,
			body.skinning,
			_mask,
			_filtered_indices,
		)

	array_mesh.clear_surfaces()
	array_mesh.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES,
		arrays,
		[],
		{ },
		Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS,
	)
	array_mesh.surface_set_name(0, "Body")


func _rebuild_child_proxies() -> void:
	for child in get_children():
		var instance := child as MHProxyInstance
		if instance:
			_rebuild_child_proxy(instance)


func _rebuild_child_proxy(instance: MHProxyInstance) -> void:
	var skinning: MHSkinning
	if instance.proxy and instance.proxy.geometry:
		skinning = body.get_proxy_skinning(instance.proxy)
	instance.rebuild_fitted(morphed_vertices, skinning, skin, skeleton_node)
