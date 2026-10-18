@tool
class_name MHBone
extends Resource

## MakeHuman bone name.
##
## Rig weights and vertex groups are keyed by it.
@export var name: StringName

## Name the bone is used when added to a [Skeleton3D].
##
## Corresponds to a bone name of the built-in humanoid profile
## [SkeletonProfileHumanoid].
@export var export_name: StringName

## Parent index in [member MHRig.bones], or `-1` for a root bone.
##
## Resolved from the parent name in the rig JSON during import.
@export var parent_index := -1

## Position strategy for the bone head.
@export var head: MHRigPosition

## Position strategy for the bone tail.
@export var tail: MHRigPosition

## Bone roll in radians.
@export var roll: float


## Resolves this bone's global rest transform from the current morphed body.
##
## The returned transform is in MakeHuman/global skeleton space, not in the
## parent-relative rest space expected by [Skeleton3D].
func resolve_global_rest(
	body_vertices: PackedVector3Array,
	vertex_groups: MHVertexGroups,
) -> Transform3D:
	var head_pos := head.resolve(body_vertices, vertex_groups)
	var tail_pos := tail.resolve(body_vertices, vertex_groups)

	return Transform3D(_make_basis(head_pos, tail_pos), head_pos)


## Builds the bone basis from MakeHuman head/tail coordinates and MPFB roll.
##
## MPFB bone roll is defined in Blender's Z-up coordinate space, while this
## plugin keeps MakeHuman geometry in its original Y-up coordinates.
## Bone head/tail positions are resolved from that raw geometry, so the bone
## axis must be converted to Blender space before applying roll.
func _make_basis(head_pos: Vector3, tail_pos: Vector3) -> Basis:
	const MH_TO_BLENDER := Basis(Vector3.RIGHT, PI * 0.5)
	const BLENDER_TO_MH := Basis(Vector3.RIGHT, -PI * 0.5)

	var makehuman_axis := tail_pos - head_pos
	assert(not makehuman_axis.is_zero_approx())

	var blender_axis := (MH_TO_BLENDER * makehuman_axis).normalized()
	var blender_basis := _basis_from_axis_roll(blender_axis)

	return BLENDER_TO_MH * blender_basis


## Builds a Blender-compatible bone basis from its axis and roll.
##
## Equivalent in meaning to Blender's `Bone.MatrixFromAxisRoll(axis, roll)`:
## aligns the bone's local +Y axis with [param axis], then applies [member roll]
## around that axis.
func _basis_from_axis_roll(axis: Vector3) -> Basis:
	var swing := Basis(Quaternion(Vector3.UP, axis))
	var twist := Basis(axis, roll)

	return twist * swing
