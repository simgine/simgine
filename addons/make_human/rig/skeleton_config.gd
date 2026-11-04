@tool
class_name MHSkeletonConfig
extends Resource

@export var rig: MHRig:
	set(value):
		if rig == value:
			return

		rig = value
		emit_changed()

## Optional native MakeHuman pose applied before adapting bone axes to humanoid.
##
## If unset, preserves the rig's native rest silhouette.
@export var reference_pose: MHPose:
	set(value):
		if reference_pose == value:
			return

		reference_pose = value
		emit_changed()
