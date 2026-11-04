@tool
class_name MHRig
extends Resource
## Defines the bone hierarchy, saved rest endpoints, and how each bone endpoint
## is positioned relative to the mesh.
##
## Imported from `rig.*.json`.

## Bones in parent-first order.
@export var bones: Array[MHBone]
