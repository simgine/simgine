class_name MHMatImporter
extends EditorImportPlugin
## Importer for MakeHuman `.mhmat` files.
##
## For details, see https://github.com/makehumancommunity/mpfb2/blob/master/docs/fileformats/mhmat.md


func _get_importer_name() -> String:
	return "make_human.mhmat_importer"


func _get_visible_name() -> String:
	return "MakeHuman Material Importer"


func _get_recognized_extensions() -> PackedStringArray:
	return ["mhmat"]


func _get_save_extension() -> String:
	return "res"


func _get_resource_type() -> String:
	return "Resource"


func _get_preset_name(_preset_index: int) -> String:
	return ""


func _get_import_order() -> int:
	return 1 # Depends on images.


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
		push_error(
			"Unable to open '%s': %s" % [source_file, error_string(FileAccess.get_open_error())]
		)
		return ERR_PARSE_ERROR

	var base_dir := source_file.get_base_dir()
	var material := StandardMaterial3D.new()
	var transparent := false
	var roughness: float = INF
	var shininess: float = INF
	var line_index := 0
	while not file.eof_reached():
		line_index += 1

		var line := file.get_line().strip_edges()
		if line.is_empty() || line.begins_with("#") || line.begins_with("//"):
			continue

		var separator := line.find(" ")
		if separator == -1:
			push_error("Invalid tag at %d: '%s'" % [line_index, line])
			continue

		var tag := line.substr(0, separator)
		var value := line.substr(separator + 1).strip_edges()
		match tag:
			# Metadata
			"name", "description", "uuid", "license", "author", "homepage", "url", "tag":
				pass
			# Colors
			"diffuseColor":
				var parts := value.split(" ", false)
				if parts.size() != 3:
					push_error("Invalid diffuse color at %d: '%s'" % [line_index, value])
					continue

				material.albedo_color.r = parts[0].to_float()
				material.albedo_color.g = parts[1].to_float()
				material.albedo_color.b = parts[2].to_float()
			"specularColor":
				pass
			"emissiveColor":
				var parts := value.split(" ", false)
				if parts.size() != 3:
					push_error("Invalid diffuse color at %d: '%s'" % [line_index, value])
					continue

				material.emission_enabled = true
				material.emission.r = parts[0].to_float()
				material.emission.g = parts[1].to_float()
				material.emission.b = parts[2].to_float()
			"ambientColor", "viewportColor":
				pass
			# Textures
			"diffuseTexture", "diffusemapTexture", "albedoTexture", "albedoMapTexture", "basecolorTexture", "basecolorMapTexture":
				var texture := _load_texture(base_dir, value, line_index)
				if texture:
					material.albedo_texture = texture
			"bumpmapTexture", "bumpTexture":
				pass
			"normalmapTexture":
				var texture := _load_texture(base_dir, value, line_index)
				if texture:
					material.normal_enabled = true
					material.normal_texture = texture
			"displacementmapTexture", "specularmapTexture", "transmissionmapTexture", "opacitymapTexture", "opacityTexture", "opacityMapTexture":
				pass
			"roughnessmapTexture":
				var texture := _load_texture(base_dir, value, line_index)
				if texture:
					material.roughness_texture = texture
			"metallicmapTexture":
				var texture := _load_texture(base_dir, value, line_index)
				if texture:
					material.metallic_texture = texture
			"aomapTexture":
				var texture := _load_texture(base_dir, value, line_index)
				if texture:
					material.ao_enabled = true
					material.ao_texture = texture
			"emissionColorMapTexture", "emissiveTexture", "emissionTexture":
				var texture := _load_texture(base_dir, value, line_index)
				if texture:
					material.emission_enabled = true
					material.emission_texture = texture
			"emissionStrengthMapTexture", "subsurfaceColorMapTexture", "sssTexture", "sssMapTexture", "subsurfaceStrengthMapTexture":
				pass
			# Intensities
			"diffuseIntensity", "bumpmapIntensity":
				pass
			"normalmapIntensity":
				material.normal_scale = value.to_float()
			"displacementmapIntensity", "specularmapIntensity", "opacitymapIntensity", "aomapIntensity":
				pass
			"emissionIntensity":
				material.emission_energy_multiplier = value.to_float()
			"subsurfaceIntensity":
				material.subsurf_scatter_strength = value.to_float()
			# Sub-Surface Scattering
			"sssEnabled":
				material.subsurf_scatter_enabled = _parse_bool(value)
			"sssRScale", "sssGScale", "sssBScale":
				pass
			# Material Properties
			"metallic":
				material.metallic = value.to_float()
			"roughness":
				roughness = clampf(value.to_float(), 0.0, 1.0)
			"shininess":
				shininess = clampf(value.to_float(), 0.0, 1.0)
			"opacity":
				# MakeHuman's Phong and litsphere shaders use diffuse-texture alpha,
				# ignoring scalar opacity.
				if value.to_float() < 1.0:
					transparent = true
			"ior", "translucency", "litsphereTexture", "blendMaterial":
				pass
			# Boolean Flags
			"shadeless":
				if _parse_bool(value):
					material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				else:
					material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			"wireframe":
				pass
			"transparent":
				transparent = transparent or _parse_bool(value)
			"alphaToCoverage":
				if _parse_bool(value):
					material.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
				else:
					material.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_OFF
			"backfaceCull":
				if _parse_bool(value):
					material.cull_mode = BaseMaterial3D.CULL_BACK
				else:
					material.cull_mode = BaseMaterial3D.CULL_DISABLED
			"depthless":
				material.no_depth_test = _parse_bool(value)
			"castShadows":
				pass
			"receiveShadows":
				material.disable_receive_shadows = not _parse_bool(value)
			"autoBlendSkin":
				pass
			# Shader Properties
			"shader", "shaderParam", "shaderConfig":
				pass
			_:
				push_error("Unknown tag at %d: '%s'" % [line_index, line])
				continue

	# Explicit PBR roughness takes precedence over the shininess approximation.
	if roughness != INF:
		material.roughness = roughness
	elif shininess != INF:
		# Approximate MakeHuman's shininess using inverse PBR roughness.
		material.roughness = 1.0 - shininess

	if transparent:
		if material.alpha_antialiasing_mode == BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		else:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	else:
		material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED

	return ResourceSaver.save(material, "%s.%s" % [save_path, _get_save_extension()])


static func _load_texture(base_dir: String, value: String, line_index: int) -> Texture2D:
	var path := base_dir.path_join(value)
	var texture := ResourceLoader.load(path) as Texture2D
	if not texture:
		push_error("Could not load texture '%s' at %d" % [path, line_index])

	return texture


static func _parse_bool(value: String) -> bool:
	return value.to_lower() in ["true", "t", "1"]
