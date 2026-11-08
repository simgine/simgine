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

## Maps bones to position offsets relative to the reference pose.
##
## When applied, the bone and its subtree are displaced by the offset
## relative to their positions without the translations.
##
## Missing entries leave a bone where the rotations place it.
## Typically only present for the bone mapped from the source rig's root.
@export var translations: Dictionary[StringName, Vector3]
