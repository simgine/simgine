@tool
class_name MHSkinning
## Skinning data for geometry and render vertices.
##
## Geometry skinning follows the original [MHGeometry] vertex order and is used
## when deriving proxy skinning. Render skinning follows the expanded render
## topology and can be passed directly to [ArrayMesh].

## Maximum number of bone influences per vertex in Godot.
const MAX_INFLUENCES := 8

## Bone indices for geometry vertices.
##
## Each geometry vertex occupies [constant MAX_INFLUENCES] consecutive entries.
var bones: PackedInt32Array

## Bone weights for geometry vertices.
##
## Each geometry vertex occupies [constant MAX_INFLUENCES] consecutive entries.
var weights: PackedFloat32Array

## Bone indices for [constant Mesh.ARRAY_BONES].
##
## Expanded from [member bone_indices] based on [MHGeometry.RenderTopology].
var render_bones: PackedInt32Array

## Bone weights for [constant Mesh.ARRAY_WEIGHTS].
##
## Expanded from [member bone_indices] based on [MHGeometry.RenderTopology].
var render_weights: PackedFloat32Array


## Builds skinning for the body from rig weights.
##
## Sparse bone-to-vertex weight assignments are converted into
## [constant MAX_INFLUENCES] influences per geometry vertex.
func build_from_rig(geometry: MHGeometry, rig: MHRig, rig_weights: MHRigWeights) -> void:
	_resize(geometry.vertices.size())

	var bone_index := 0
	for bone_name in rig.bones:
		var bone_weights: MHBoneWeights = rig_weights.bones.get(bone_name)
		if bone_weights:
			assert(bone_weights.vertices.size() == bone_weights.weights.size())
			for influence_index in bone_weights.vertices.size():
				var vertex_index := bone_weights.vertices[influence_index]
				var weight := bone_weights.weights[influence_index]

				_add_influence(vertex_index, bone_index, weight)
		bone_index += 1

	assert(_weights_are_normalized())
	_build_render_arrays(geometry)


## Builds skinning for proxy geometry from body skinning.
##
## Each proxy vertex inherits bone influences from its 3 referenced body
## vertices, scaled by the corresponding proxy fitting weights.
func build_from_proxy(body_skinning: MHSkinning, proxy: MHProxy) -> void:
	var vertex_count := proxy.get_vertex_count()
	_resize(vertex_count)

	for vertex_index in vertex_count:
		var fit_weight := proxy.weights[vertex_index]
		var a := proxy.ref_a[vertex_index]
		var b := proxy.ref_b[vertex_index]
		var c := proxy.ref_c[vertex_index]

		var influences: Dictionary[int, float]
		_accumulate_reference(influences, body_skinning, a, fit_weight.x)
		_accumulate_reference(influences, body_skinning, b, fit_weight.y)
		_accumulate_reference(influences, body_skinning, c, fit_weight.z)

		var factor_sum := fit_weight.x + fit_weight.y + fit_weight.z
		_finalize_influences(influences, vertex_index, factor_sum)

	assert(_weights_are_normalized())
	_build_render_arrays(proxy.geometry)


## Adds one referenced body vertex's bone influences to an accumulator,
## scaling each weight by [param factor].
func _accumulate_reference(
	influences: Dictionary[int, float],
	body_skinning: MHSkinning,
	body_index: int,
	factor: float,
) -> void:
	if factor == 0.0:
		return

	var offset := body_index * MAX_INFLUENCES
	for index in range(offset, offset + MAX_INFLUENCES):
		var weight := body_skinning.weights[index]
		if weight == 0.0:
			continue

		var bone_index := body_skinning.bones[index]
		var contribution := weight * factor
		influences[bone_index] = influences.get(bone_index, 0.0) + contribution


## Normalizes and adds up to [constant MAX_INFLUENCES] strongest bone influences to a vertex.
func _finalize_influences(
	influences: Dictionary[int, float],
	vertex_index: int,
	factor_sum: float,
) -> void:
	assert(factor_sum > 0.0)

	# Take top `MAX_INFLUENCES`.
	var sorted_bones := influences.keys()
	sorted_bones.sort_custom(
		func(bone_a: int, bone_b: int) -> bool:
			return influences[bone_a] > influences[bone_b],
	)
	if sorted_bones.size() > MAX_INFLUENCES:
		sorted_bones.resize(MAX_INFLUENCES)

	# Reject negative or small influences and calculate the
	# sum for normalization.
	const MIN_INFLUENCE_WEIGHT := 0.001
	var min_weight := MIN_INFLUENCE_WEIGHT * factor_sum
	var total := 0.0
	var retained_count := 0
	for bone_index: int in sorted_bones:
		var weight := influences[bone_index]
		if weight <= min_weight:
			# Since the array is sorted, discard the rest.
			sorted_bones.resize(retained_count)
			break

		total += weight
		retained_count += 1

	assert(total > 0.0)
	for bone_index: int in sorted_bones:
		_add_influence(vertex_index, bone_index, influences[bone_index] / total)


func _resize(vertex_count: int) -> void:
	var size := vertex_count * MAX_INFLUENCES

	bones.clear()
	bones.resize(size)

	weights.clear()
	weights.resize(size)


## Adds a bone influence to a vertex.
##
## Accumulates the weight if the same bone is already present.
func _add_influence(vertex_index: int, bone_index: int, weight: float) -> void:
	assert(weight > 0.0)

	var offset := vertex_index * MAX_INFLUENCES
	for index in range(offset, offset + MAX_INFLUENCES):
		if weights[index] > 0.0:
			if bones[index] == bone_index:
				weights[index] += weight
				return

			continue

		bones[index] = bone_index
		weights[index] = weight
		return

	assert(false, "Vertex can't have more than %d bone influences" % MAX_INFLUENCES)


func _weights_are_normalized() -> bool:
	const TOLERANCE := 0.001 # MPFB2 weights can have a slightly larger error margin than epsilon.
	for vertex_index in get_vertex_count():
		var total := 0.0
		var offset := vertex_index * MAX_INFLUENCES
		for index in range(offset, offset + MAX_INFLUENCES):
			total += weights[index]

		if absf(total - 1.0) > TOLERANCE:
			return false

	return true


func _build_render_arrays(geometry: MHGeometry) -> void:
	assert(get_vertex_count() == geometry.vertices.size())
	var render_vertex_count := geometry.topology.geometry_indices.size()

	render_bones.clear()
	render_bones.resize(render_vertex_count * MHSkinning.MAX_INFLUENCES)

	render_weights.clear()
	render_weights.resize(render_vertex_count * MHSkinning.MAX_INFLUENCES)

	for render_index in render_vertex_count:
		var geometry_index := geometry.topology.geometry_indices[render_index]
		var geometry_offset := geometry_index * MHSkinning.MAX_INFLUENCES
		var render_offset := render_index * MHSkinning.MAX_INFLUENCES

		for slot in MHSkinning.MAX_INFLUENCES:
			render_bones[render_offset + slot] = bones[geometry_offset + slot]
			render_weights[render_offset + slot] = weights[geometry_offset + slot]


func get_vertex_count() -> int:
	assert(weights.size() == bones.size())
	assert(weights.size() % MAX_INFLUENCES == 0)

	@warning_ignore("integer_division")
	return weights.size() / MAX_INFLUENCES
