@tool
class_name MHRigPosition
extends Resource
## Defines how bone endpoints are positioned relative to the base mesh.

## Position strategy.
##
## Not the full list, but the game engine rig uses only these strategies.
enum Strategy {
	## Positions the endpoint at the center of a joint cube defined by a vertex group on the base mesh.
	CUBE,
	## Positions the endpoint at a single mesh vertex.
	VERTEX,
	## Positions the endpoint at the average of two or more mesh vertices.
	MEAN,
}

@export var strategy: Strategy

## Rest position.
##
## Uses Blender armature coordinates.
## Used with [member MHBone.roll] to reconstruct the rest transform.
@export var default_position: Vector3

## Joint cube vertex group name, e.g. "joint-spine-1".
##
## Used by `CUBE`.
@export var cube_name: StringName

## Vertex indices to average.
##
## Used by `VERTEX` (holds a single value) and `MEAN`.
@export var vertex_indices: PackedInt32Array


## Resolves this endpoint against the current (already morphed) body vertices.
##
## Uses the [member strategy] rather than [member default_position]
## so the skeleton follows the current body shape.
##
## Joint helpers and explicit vertex references deform together with the body,
## so resolving them at runtime keeps the skeleton matched to the current shape.
func resolve(body_vertices: PackedVector3Array, vertex_groups: MHVertexGroups) -> Vector3:
	match strategy:
		Strategy.CUBE:
			return _resolve_cube(body_vertices, vertex_groups)
		Strategy.VERTEX, Strategy.MEAN:
			return _resolve_vertices(body_vertices)
		_:
			push_error("Invalid rig position strategy: %s" % strategy)
			return Vector3.ZERO


func _resolve_cube(body_vertices: PackedVector3Array, vertex_groups: MHVertexGroups) -> Vector3:
	var ranges := vertex_groups.ranges[cube_name]
	assert(ranges.size() % 2 == 0)

	var sum := Vector3.ZERO
	var count := 0
	for range_index in range(0, ranges.size(), 2):
		var first := ranges[range_index]
		var last := ranges[range_index + 1]

		for vertex_index in range(first, last + 1):
			sum += body_vertices[vertex_index]
			count += 1

	return sum / count


func _resolve_vertices(body_vertices: PackedVector3Array) -> Vector3:
	assert(not vertex_indices.is_empty())
	var sum := Vector3.ZERO
	for vertex_index in vertex_indices:
		sum += body_vertices[vertex_index]

	return sum / vertex_indices.size()
