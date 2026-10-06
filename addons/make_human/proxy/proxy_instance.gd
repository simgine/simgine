@tool
class_name MHProxyInstance
extends MeshInstance3D
## Runtime mesh instance generated from an [MHProxy].

signal proxy_changed

@export var proxy: MHProxy:
	set = set_proxy


func _ready() -> void:
	if get_parent() is not MHBodyInstance:
		rebuild_standalone()


func _validate_property(property: Dictionary) -> void:
	match property.name:
		"mesh", "skin", "skeleton":
			# Constructed dynamically from the proxy geometry or derived from the body.
			property.usage &= ~PROPERTY_USAGE_STORAGE
			property.usage |= PROPERTY_USAGE_READ_ONLY


func set_proxy(value: MHProxy) -> void:
	if proxy == value:
		return

	proxy = value

	if is_node_ready() and get_parent() is not MHBodyInstance:
		rebuild_standalone()

	proxy_changed.emit()


func rebuild_standalone() -> void:
	if not proxy or not proxy.geometry:
		clear()
		return

	_set_surface(proxy.geometry.build_surface())
	skin = null
	skeleton = NodePath()


func rebuild_fitted(
	body_vertices: PackedVector3Array,
	skinning: MHSkinning,
	body_skin: Skin,
	skeleton_node: Skeleton3D,
) -> void:
	if not proxy or not proxy.geometry:
		clear()
		return

	_set_surface(proxy.build_fitted_surface(body_vertices, skinning))
	skin = body_skin
	skeleton = get_path_to(skeleton_node)


## Clears generated geometry and skeleton bindings without changing [member proxy].
func clear() -> void:
	mesh = null
	skin = null
	skeleton = NodePath()


func _set_surface(arrays: Array) -> void:
	var array_mesh := mesh as ArrayMesh
	if not array_mesh:
		array_mesh = ArrayMesh.new()
		mesh = array_mesh

	array_mesh.clear_surfaces()
	array_mesh.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES,
		arrays,
		[],
		{ },
		Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS,
	)
	array_mesh.surface_set_name(0, "Proxy mesh")

	if proxy.material:
		array_mesh.surface_set_material(0, proxy.material)
