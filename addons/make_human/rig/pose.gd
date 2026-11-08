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

## Distance from the head of spine05 to the tail of spine01 when the pose was captured.
##
## Used to scale translations when applying the pose to differently proportioned characters.
## Set to 0 for non-default rigs (no scaling).
@export var original_spine_length: float

## Distance between the tails of shoulder01.L and shoulder01.R when captured.
##
## Used to scale X/Y translations. Set to 0 for non-default rigs.
@export var original_shoulder_width: float
