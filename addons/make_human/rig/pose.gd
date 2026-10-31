@tool
class_name MHPose
extends Resource
## A pose file stores bone rotations and translations (not supported yet) for an armature,
## allowing characters to be placed into predefined poses.
##
## Imported from pose JSON. Bone names match [member MHBone.name].
## Missing entries leave a bone in its native rest pose.

## Maps bones to rotations.
@export var rotations: Dictionary[StringName, Quaternion]
