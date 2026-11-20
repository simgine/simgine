@tool
class_name MakeHumanPlugin
extends EditorPlugin

var _obj_importer := MHObjImporter.new()
var _target_importer := MHTargetImporter.new()
var _json_importer := MHJSONImporter.new()
var _bvh_importer := MHBVHImporter.new()
var _mhmat_importer := MHMatImporter.new()
var _proxy_importer := MHProxyImporter.new()


func _enter_tree() -> void:
	add_import_plugin(_obj_importer)
	add_import_plugin(_target_importer)
	add_import_plugin(_json_importer)
	add_import_plugin(_bvh_importer)
	add_import_plugin(_mhmat_importer)
	add_import_plugin(_proxy_importer)


func _exit_tree() -> void:
	remove_import_plugin(_obj_importer)
	remove_import_plugin(_target_importer)
	remove_import_plugin(_json_importer)
	remove_import_plugin(_bvh_importer)
	remove_import_plugin(_mhmat_importer)
	remove_import_plugin(_proxy_importer)
