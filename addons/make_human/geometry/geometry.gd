@tool
class_name MHGeometry
extends Resource
## MakeHuman mesh data imported from OBJ.
##
## A renderable [ArrayMesh] is constructed at runtime because vertex
## positions may be modified by morph targets or reconstructed from
## another mesh using proxy fitting data.
##
## Original OBJ vertex indices are preserved because MHCLO files and
## morph targets refer to them rather than to render mesh vertices,
## which are different from render mesh vertices.

## UV coordinates.
@export_storage var uvs: PackedVector2Array:
	set(value):
		uvs = value
		topology = null

## Quad faces.
##
## In MakeHuman OBJ files all faces are represented as quads.
@export_storage var quads: Array[MHQuad]:
	set(value):
		quads = value
		topology = null


## Vertex positions.
##
## For proxy meshes, these are used only when the proxy is not
## attached to a body. When attached to a body, vertices are
## dynamically reconstructed from scratch using the body vertices
## and [MHProxy] fitting data after all morph targets are applied.
##
## For the body, these vertices are copied and morphed before
## constructing the surface. They include helper geometry to preserve
## the original OBJ vertex indices. Helper faces are excluded from
## [member quads] because they are not rendered. Since the render
## topology is built from the quads, helper vertices are
## automatically excluded from the resulting render mesh.
@export_storage var vertices: PackedVector3Array

## Cached topology used to construct render-mesh vertex arrays.
##
## Built lazily from [member quads] and [member uvs].
var topology: RenderTopology:
	get:
		if not topology:
			_build_render_topology()
		return topology


## Adjusts the delete mask so it doesn't hide partially masked quads.
##
## Since vertices are shared between quads, a masked vertex may also
## belong to a neighbor quad that shouldn't be hidden. Such boundary
## vertices should be removed from the mask. This matches the
## conservative masking in MPFB2.
func make_mask_conservative(mask: PackedByteArray) -> void:
	assert(vertices.size() == mask.size())

	# We can't zero vertices immediately because they may belong to
	# other quads that still need to be checked.
	# This special value marks them for zeroing later.
	const REMOVE := 2

	for quad in quads:
		var masked_count := 0

		for vertex_index in quad.vertex_indices:
			if mask[vertex_index] != 0:
				masked_count += 1

		if masked_count > 0 and masked_count < quad.vertex_indices.size():
			# Partially affected quad.
			for vertex_index in quad.vertex_indices:
				if mask[vertex_index] != 0:
					mask[vertex_index] = REMOVE

	for vertex_index in mask.size():
		if mask[vertex_index] == REMOVE:
			mask[vertex_index] = 0


## Builds arrays for an [ArrayMesh] surface.
##
## Uses [member vertices] when [param source_vertices] is empty.
##
## If [param mask] is provided, masked faces are excluded from the index array.
## This requires passing [param filtered_indices] produced by [method filter_indices],
## which can be cached across calls with the same mask.
func build_surface(
	source_vertices: PackedVector3Array = [],
	skinning: MHSkinning = null,
	mask: PackedByteArray = [],
	filtered_indices: PackedInt32Array = [],
) -> Array:
	if not source_vertices:
		source_vertices = vertices

	assert(source_vertices.size() == vertices.size())
	assert(not mask or vertices.size() == mask.size())

	var geometry_normals := _generate_smooth_normals(source_vertices)

	var vertex_count := topology.geometry_indices.size()

	var render_vertices: PackedVector3Array
	render_vertices.resize(vertex_count)

	var render_normals: PackedVector3Array
	render_normals.resize(vertex_count)

	for render_index in vertex_count:
		var geometry_index := topology.geometry_indices[render_index]

		render_vertices[render_index] = source_vertices[geometry_index]
		render_normals[render_index] = geometry_normals[geometry_index]

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)

	arrays[Mesh.ARRAY_VERTEX] = render_vertices
	arrays[Mesh.ARRAY_NORMAL] = render_normals
	arrays[Mesh.ARRAY_TEX_UV] = topology.uvs

	if mask:
		assert(filtered_indices)
		arrays[Mesh.ARRAY_INDEX] = filtered_indices
	else:
		arrays[Mesh.ARRAY_INDEX] = topology.indices

	if skinning:
		arrays[Mesh.ARRAY_BONES] = skinning.render_bones
		arrays[Mesh.ARRAY_WEIGHTS] = skinning.render_weights

	return arrays


func _generate_smooth_normals(source_vertices: PackedVector3Array) -> PackedVector3Array:
	var normals: PackedVector3Array
	normals.resize(source_vertices.size())

	for quad in quads:
		var i0 := quad.vertex_indices[0]
		var i1 := quad.vertex_indices[1]
		var i2 := quad.vertex_indices[2]
		var i3 := quad.vertex_indices[3]

		var v0 := source_vertices[i0]
		var v1 := source_vertices[i1]
		var v2 := source_vertices[i2]
		var v3 := source_vertices[i3]

		# Use the opposite winding from the render indices to produce
		# outward-facing normals.
		var edge_1 := v1 - v0
		var edge_2 := v2 - v0
		var edge_3 := v3 - v0

		# Triangle 1: 0, 1, 2.
		var normal_1 := edge_1.cross(edge_2)
		# Triangle 2: 0, 2, 3.
		var normal_2 := edge_2.cross(edge_3)

		normals[i0] += normal_1 + normal_2
		normals[i1] += normal_1
		normals[i2] += normal_1 + normal_2
		normals[i3] += normal_2

	for index in normals.size():
		normals[index] = normals[index].normalized()

	return normals


## Builds and stores a render topology from UV and quad data.
##
## MakeHuman geometry uses separate indices for vertex positions and UV
## coordinates. Godot's [ArrayMesh], however, uses a single index for all
## vertex attributes.
##
## A render vertex therefore represents an attribute combination:
## geometry vertex + UV coordinate.
##
## Adjacent faces can share the same render vertex when they use both the same
## geometry vertex and the same UV. If the geometry vertex lies on a UV seam,
## it is represented by multiple render vertices, one for each distinct UV.
##
## During construction, every quad corner is converted into a key with vertex and UV.
## Corners with an existing key reuse the previously created render vertex.
## Otherwise, a new render vertex is added. Quad corners are then converted
## into triangle indices referencing these compact render vertices.
##
## The topology depends only on face and UV structure, not on deformed vertex
## positions. It can therefore be built once and shared by every instance that
## uses the same [MHGeometry].
##
## Per-instance mesh rebuilding only needs to expand the current geometry
## positions and normals through [RenderTopology.geometry_indices]. UVs and triangle
## indices remain unchanged and are reused.
func _build_render_topology() -> void:
	topology = RenderTopology.new()
	var vertex_lookup: Dictionary[Vector2i, int]
	for quad in quads:
		var i0 := _get_or_create_vertex(vertex_lookup, quad.vertex_indices[0], quad.uv_indices[0])
		var i1 := _get_or_create_vertex(vertex_lookup, quad.vertex_indices[1], quad.uv_indices[1])
		var i2 := _get_or_create_vertex(vertex_lookup, quad.vertex_indices[2], quad.uv_indices[2])
		var i3 := _get_or_create_vertex(vertex_lookup, quad.vertex_indices[3], quad.uv_indices[3])

		# Convert the quad into two triangles.
		topology.indices.append(i0)
		topology.indices.append(i2)
		topology.indices.append(i1)

		topology.indices.append(i0)
		topology.indices.append(i3)
		topology.indices.append(i2)


func _get_or_create_vertex(
	vertex_lookup: Dictionary[Vector2i, int],
	geometry_index: int,
	uv_index: int,
) -> int:
	var key := Vector2i(geometry_index, uv_index)
	var existing_index: int = vertex_lookup.get(key, -1)

	if existing_index >= 0:
		return existing_index

	var render_index := topology.geometry_indices.size()
	vertex_lookup[key] = render_index

	topology.geometry_indices.append(geometry_index)
	topology.uvs.append(uvs[uv_index])

	return render_index


## Returns the [member topology] indices with masked faces removed.
func filter_indices(mask: PackedByteArray) -> PackedInt32Array:
	var indices: PackedInt32Array
	for quad_index in quads.size():
		var quad := quads[quad_index]

		var deleted := false
		for vertex_index in quad.vertex_indices:
			if mask[vertex_index]:
				deleted = true
				break

		if deleted:
			continue

		var offset := quad_index * 6
		for index in range(offset, offset + 6):
			indices.append(topology.indices[index])

	return indices


class RenderTopology:
	## For each render vertex, stores the corresponding original geometry vertex.
	##
	## Several render vertices may reference the same geometry vertex when that
	## vertex lies on a UV seam.
	var geometry_indices: PackedInt32Array

	## One UV coordinate for every render vertex.
	var uvs: PackedVector2Array

	## Triangle indices referencing the compact render vertex arrays.
	var indices: PackedInt32Array
