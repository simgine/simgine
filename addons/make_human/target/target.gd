@tool
class_name MHTarget
extends Resource
## A morph target (shape key) for the MakeHuman base mesh.
##
## Imported from `.target` files.

@export_storage var vertex_indices: PackedInt32Array
@export_storage var offsets: PackedVector3Array


func apply(vertices: PackedVector3Array, weight: float) -> void:
	assert(vertex_indices.size() == offsets.size())
	if weight == 0.0:
		return

	for index in vertex_indices.size():
		var vertex_index := vertex_indices[index]
		if vertex_index < vertices.size():
			vertices[vertex_index] += offsets[index] * weight
