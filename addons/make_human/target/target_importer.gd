class_name MHTargetImporter
extends EditorImportPlugin
## Importer for MakeHuman `.target` files.
##
## For details, see https://github.com/makehumancommunity/mpfb2/blob/master/docs/fileformats/target.md


func _get_importer_name() -> String:
	return "make_human.target_importer"


func _get_visible_name() -> String:
	return "MakeHuman Target Importer"


func _get_recognized_extensions() -> PackedStringArray:
	return ["target", "ptarget", "gz"]


func _get_save_extension() -> String:
	return "res"


func _get_resource_type() -> String:
	return "Resource"


func _get_preset_name(_preset_index: int) -> String:
	return ""


func _get_import_options(_path: String, _preset_index: int) -> Array[Dictionary]:
	return []


func _import(
	source_file: String,
	save_path: String,
	_options: Dictionary,
	_platform_variants: Array,
	_gen_files: Array,
) -> Error:
	var bytes := FileAccess.get_file_as_bytes(source_file)
	var open_error := FileAccess.get_open_error()
	if open_error != OK:
		push_error("Unable to open '%s': %s" % [source_file, error_string(open_error)])
		return open_error

	if source_file.get_extension().to_lower() == "gz":
		bytes = bytes.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)

	var text := bytes.get_string_from_utf8()

	var target := MHTarget.new()
	var line_index := 0
	for line in text.split("\n", false):
		line_index += 1

		line = line.strip_edges()
		if line.is_empty() || line.begins_with("#") || line.begins_with("\""):
			continue

		var parts := line.split(" ", false)
		if parts.size() != 4:
			push_error("Invalid displacement at %d: '%s'" % [line_index, line])
			return ERR_PARSE_ERROR

		target.vertex_indices.push_back(parts[0].to_int())
		target.offsets.push_back(
			Vector3(parts[1].to_float(), parts[2].to_float(), parts[3].to_float()),
		)

	return ResourceSaver.save(target, "%s.%s" % [save_path, _get_save_extension()])
