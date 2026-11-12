class_name TestResourceSaver
extends ResourceFormatSaver
## Captures test resources in memory if the passed path is empty
## instead of writing them to disk.

var resource: Resource


func _recognize(_resource: Resource) -> bool:
	return true


func _recognize_path(_resource: Resource, path: String) -> bool:
	return path.get_basename().is_empty()


func _save(p_resource: Resource, _path: String, _flags: int) -> Error:
	resource = p_resource
	return OK
