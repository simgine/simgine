class_name MHProxyImporter
extends EditorImportPlugin
## Importer for MakeHuman `.proxy` and `.mhclo` files.
##
## For details, see https://github.com/makehumancommunity/mpfb2/blob/master/docs/fileformats/mhclo.md

## Affects parsing for lines with unknown tag.
##
## Some files include tags even after `verts 0`, see:
## https://github.com/makehumancommunity/mpfb2/issues/409
##
## To make our parser compatible, we try to parse regular
## tags first and fallback to vertex or delete verts parsing.
enum Section {
	NONE,
	VERTS,
	DELETE_VERTS,
}


func _get_importer_name() -> String:
	return "make_human.proxy_importer"


func _get_visible_name() -> String:
	return "MakeHuman Proxy Importer"


func _get_recognized_extensions() -> PackedStringArray:
	return ["proxy", "mhclo"]


func _get_save_extension() -> String:
	return "res"


func _get_resource_type() -> String:
	return "Resource"


func _get_preset_name(_preset_index: int) -> String:
	return ""


func _get_import_order() -> int:
	return 2 # Depends on geometry and materials.


func _get_import_options(_path: String, _preset_index: int) -> Array[Dictionary]:
	return []


func _import(
	source_file: String,
	save_path: String,
	_options: Dictionary,
	_platform_variants: Array,
	_gen_files: Array,
) -> Error:
	var file := FileAccess.open(source_file, FileAccess.READ)
	if not file:
		var open_error := FileAccess.get_open_error()
		push_error("Unable to open '%s': %s" % [source_file, error_string(open_error)])
		return open_error

	var section := Section.NONE
	var base_dir := source_file.get_base_dir()
	var proxy := MHProxy.new()
	var line_index := 0
	while not file.eof_reached():
		line_index += 1

		var line := file.get_line().strip_edges()
		if line.is_empty() || line.begins_with("#"):
			continue

		var tag := line
		var value := ""
		var separator := line.find(" ")
		if separator != -1:
			tag = line.substr(0, separator)
			value = line.substr(separator + 1).strip_edges()

		match tag:
			"basemesh":
				if value != "hm08":
					push_error("Unsupported basemesh at %d: '%s'" % [line_index, value])
					return ERR_PARSE_ERROR
			"name", "description", "tag", "uuid":
				pass
			"obj_file":
				var path := base_dir.path_join(value)
				var geometry := ResourceLoader.load(path) as MHGeometry
				if geometry:
					proxy.geometry = geometry
				else:
					push_error("Could not load mesh data '%s' at %d" % [path, line_index])
			"material":
				var path := base_dir.path_join(value)
				var material := ResourceLoader.load(path) as StandardMaterial3D
				if material:
					proxy.material = material
				else:
					push_error("Could not load material '%s' at %d" % [path, line_index])
			"x_scale":
				var scale := _parse_scale(value, line_index)
				if scale:
					proxy.x_scale = scale
			"y_scale":
				var scale := _parse_scale(value, line_index)
				if scale:
					proxy.y_scale = scale
			"z_scale":
				var scale := _parse_scale(value, line_index)
				if scale:
					proxy.z_scale = scale
			"z_depth", "max_pole":
				pass
			"vertexboneweights_file":
				# TODO: add support for this. Right now skinning
				# is derived from the active body rig.
				pass
			"verts":
				if value != "0":
					push_error("Unsupported verts start at %d: '%s'" % [line_index, value])
					continue

				section = Section.VERTS
			"delete_verts":
				section = Section.DELETE_VERTS
			_:
				match section:
					Section.NONE:
						push_error("Unknown tag at %d: '%s'" % [line_index, line])
					Section.VERTS:
						if not _parse_vertex_mapping(line, proxy):
							push_error("Invalid vertex mapping at %d: '%s'" % [line_index, line])
					Section.DELETE_VERTS:
						if not _parse_delete_verts(line, proxy):
							push_error("Invalid delete vertices at %d: '%s'" % [line_index, line])
				continue

	return ResourceSaver.save(proxy, "%s.%s" % [save_path, _get_save_extension()])


static func _parse_scale(value: String, line_index: int) -> MHScale:
	var parts := value.split(" ", false)
	if parts.size() != 3:
		push_error("Invalid X scale at %d: '%s'" % [line_index, value])
		return null

	var scale := MHScale.new()
	scale.min_vertex = parts[0].to_int()
	scale.max_vertex = parts[1].to_int()
	scale.factor = parts[2].to_float()
	return scale


static func _parse_vertex_mapping(line: String, proxy: MHProxy) -> bool:
	var parts := line.split(" ", false)
	match parts.size():
		1:
			var index := parts[0].to_int()

			proxy.ref_a.append(index)
			proxy.ref_b.append(index)
			proxy.ref_c.append(index)
			proxy.weights.append(Vector3(1.0, 0.0, 0.0))
			proxy.offsets.append(Vector3.ZERO)
			return true
		9:
			proxy.ref_a.append(parts[0].to_int())
			proxy.ref_b.append(parts[1].to_int())
			proxy.ref_c.append(parts[2].to_int())

			proxy.weights.append(
				Vector3(parts[3].to_float(), parts[4].to_float(), parts[5].to_float()),
			)

			proxy.offsets.append(
				Vector3(parts[6].to_float(), parts[7].to_float(), parts[8].to_float()),
			)
			return true
		_:
			return false


static func _parse_delete_verts(line: String, proxy: MHProxy) -> bool:
	var parts := line.split(" ", false)

	var index := 0
	while index < parts.size():
		var start := parts[index].to_int()
		index += 1

		if index < parts.size() and parts[index] == "-":
			index += 1
			if index >= parts.size():
				return false

			var end := parts[index].to_int()
			index += 1

			if end < start:
				return false

			proxy.delete_verts.push_back(start)
			proxy.delete_verts.push_back(end)
		else:
			# Single value, start and end are equal.
			proxy.delete_verts.push_back(start)
			proxy.delete_verts.push_back(start)

	return true
