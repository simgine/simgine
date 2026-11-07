@tool
class_name MHPose
extends Resource
## A predefined character pose retargeted to a [SkeletonProfile].
##
## Imported from pose JSON.
## See also [MHNativePose] for a pose with its original rig.

## Profile used for retargeting.
@export var profile: SkeletonProfile

## Maps bones to rotations.
@export var rotations: Dictionary[StringName, Quaternion]
