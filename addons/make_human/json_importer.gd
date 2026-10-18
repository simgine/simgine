class_name MHJSONImporter
extends EditorImportPlugin
## Importer for `target.json`, `macro.json` and `rig.game_engine.json`.
##
## For details, see https://github.com/makehumancommunity/mpfb2/blob/master/docs/fileformats/target_metadata.md
## and https://github.com/makehumancommunity/mpfb2/blob/master/docs/fileformats/rig.md

## Additional metadata required to interpret `macro.json`.
##
## Some of this information is hardcoded in MPFB2 rather than stored
## in `macro.json`, so it is represented explicitly here.
const MACRO_METADATA: Dictionary[StringName, Dictionary] = {
	"racegenderage": { "directory": "macrodetails" },
	"genderagemuscleweight": { "directory": "macrodetails", "prefix": "universal" },
	"genderagemuscleweightproportions": { "directory": "macrodetails/proportions" },
	"genderagemuscleweightheight": { "directory": "macrodetails/height" },
	"genderagemuscleweightcupsizefirmness": {
		"directory": "breast",
		# MPFB2 uses only the female component for breast targets.
		"allowed_components": { &"gender": [&"female"] },
		# MPFB2 excludes gender from the breast target weight.
		"weight_exclusions": [&"gender"],
	},
}

## Maps MakeHuman bone names to the names in [SkeletonProfileHumanoid].
##
## This way, animations retargeted through it play back on the skeleton as-is.
## Bones without an entry fall back to PascalCase, which matches the profile for `Root` and `head`.
const EXPORT_BONE_NAMES: Dictionary[StringName, StringName] = {
	"pelvis": "Hips",
	"spine_01": "Spine",
	"spine_02": "Chest",
	"spine_03": "UpperChest",
	"neck_01": "Neck",
	"clavicle_l": "LeftShoulder",
	"clavicle_r": "RightShoulder",
	"upperarm_l": "LeftUpperArm",
	"upperarm_r": "RightUpperArm",
	"lowerarm_l": "LeftLowerArm",
	"lowerarm_r": "RightLowerArm",
	"hand_l": "LeftHand",
	"hand_r": "RightHand",
	"thumb_01_l": "LeftThumbMetacarpal",
	"thumb_02_l": "LeftThumbProximal",
	"thumb_03_l": "LeftThumbDistal",
	"thumb_01_r": "RightThumbMetacarpal",
	"thumb_02_r": "RightThumbProximal",
	"thumb_03_r": "RightThumbDistal",
	"index_01_l": "LeftIndexProximal",
	"index_02_l": "LeftIndexIntermediate",
	"index_03_l": "LeftIndexDistal",
	"index_01_r": "RightIndexProximal",
	"index_02_r": "RightIndexIntermediate",
	"index_03_r": "RightIndexDistal",
	"middle_01_l": "LeftMiddleProximal",
	"middle_02_l": "LeftMiddleIntermediate",
	"middle_03_l": "LeftMiddleDistal",
	"middle_01_r": "RightMiddleProximal",
	"middle_02_r": "RightMiddleIntermediate",
	"middle_03_r": "RightMiddleDistal",
	"ring_01_l": "LeftRingProximal",
	"ring_02_l": "LeftRingIntermediate",
	"ring_03_l": "LeftRingDistal",
	"ring_01_r": "RightRingProximal",
	"ring_02_r": "RightRingIntermediate",
	"ring_03_r": "RightRingDistal",
	"pinky_01_l": "LeftLittleProximal",
	"pinky_02_l": "LeftLittleIntermediate",
	"pinky_03_l": "LeftLittleDistal",
	"pinky_01_r": "RightLittleProximal",
	"pinky_02_r": "RightLittleIntermediate",
	"pinky_03_r": "RightLittleDistal",
	"thigh_l": "LeftUpperLeg",
	"thigh_r": "RightUpperLeg",
	"calf_l": "LeftLowerLeg",
	"calf_r": "RightLowerLeg",
	"foot_l": "LeftFoot",
	"foot_r": "RightFoot",
	"ball_l": "LeftToes",
	"ball_r": "RightToes",
}


func _get_importer_name() -> String:
	return "make_human.json_importer"


func _get_visible_name() -> String:
	return "MakeHuman JSON Importer"


func _get_recognized_extensions() -> PackedStringArray:
	return ["json"]


func _get_save_extension() -> String:
	return "res"


func _get_resource_type() -> String:
	return "Resource"


func _get_preset_name(_preset_index: int) -> String:
	return ""


func _get_import_order() -> int:
	return 1 # Depends on targets.


func _get_import_options(_path: String, _preset_index: int) -> Array[Dictionary]:
	return []


func _import(
	source_file: String,
	save_path: String,
	_options: Dictionary,
	_platform_variants: Array,
	_gen_files: Array,
) -> Error:
	var string := FileAccess.get_file_as_string(source_file)
	if FileAccess.get_open_error() != OK:
		push_error(
			"Unable to open '%s': %s" % [source_file, error_string(FileAccess.get_open_error())]
		)
		return ERR_PARSE_ERROR

	var json := JSON.new()
	if json.parse(string) != OK:
		push_error(
			"Unable to parse: '%s' at line %d" % [json.get_error_message(), json.get_error_line()],
		)
		return ERR_PARSE_ERROR

	var filename := source_file.get_file()
	if filename == "target.json":
		var targets_dir := source_file.get_base_dir()
		return _import_target_registry(json.data, targets_dir, save_path)
	if filename == "macro.json":
		var targets_dir := source_file.get_base_dir().get_base_dir()
		return _import_macro_registry(json.data, targets_dir, save_path)
	if filename == "basemesh_vertex_groups.json":
		return _import_vertex_groups(json.data, save_path)
	if filename == "rig.game_engine.json" or filename == "rig.game_engine_with_breast.json":
		return _import_rig(json.data, save_path)
	if filename == "weights.game_engine.json":
		return _import_rig_weights(json.data, save_path)
	else:
		push_error("Unknown MakeHuman JSON")
		return ERR_PARSE_ERROR


func _import_target_registry(dict: Dictionary, targets_dir: String, save_path: String) -> Error:
	var registry := MHTargetRegistry.new()
	for label: String in dict:
		var section := _parse_section(dict[label], targets_dir.path_join(label))
		registry.sections.push_back(section)

	return ResourceSaver.save(registry, "%s.%s" % [save_path, _get_save_extension()])


static func _parse_section(dict: Dictionary, section_dir: String) -> MHTargetSection:
	var section := MHTargetSection.new()
	section.label = dict.label

	for category_dict: Dictionary in dict.categories:
		var category := _parse_category(category_dict, section_dir)
		section.categories.push_back(category)

	return section


static func _parse_category(dict: Dictionary, section_dir: String) -> MHTargetCategory:
	var category := MHTargetCategory.new()
	category.has_left_and_right = dict.has_left_and_right
	category.label = dict.label

	var opposites: Dictionary = dict.get("opposites", { })
	if opposites:
		category.opposites = _parse_opposites(opposites)

	for target_name: String in dict.targets:
		category.targets[target_name] = _load_target(target_name, section_dir)

	return category


static func _parse_opposites(dict: Dictionary) -> MHTargetOpposites:
	var opposites := MHTargetOpposites.new()
	opposites.negative_left = dict["negative-left"]
	opposites.negative_right = dict["negative-right"]
	opposites.negative_unsided = dict["negative-unsided"]
	opposites.positive_left = dict["positive-left"]
	opposites.positive_right = dict["positive-right"]
	opposites.positive_unsided = dict["positive-unsided"]
	return opposites


func _import_macro_registry(dict: Dictionary, targets_dir: String, save_path: String) -> Error:
	var registry := MHMacroRegistry.new()

	var macrotargets: Dictionary = dict.macrotargets
	for name: String in macrotargets:
		registry.macrotargets[name] = _parse_macro(macrotargets[name])

	var combinations: Dictionary = dict.combinations
	for name: String in combinations:
		var combination := _parse_combination(
			name,
			combinations[name],
			registry.macrotargets,
			targets_dir,
		)
		registry.combinations.push_back(combination)

	return ResourceSaver.save(registry, "%s.%s" % [save_path, _get_save_extension()])


static func _parse_macro(dict: Dictionary) -> MHMacro:
	var macro := MHMacro.new()

	for part_dict: Dictionary in dict.parts:
		var part := _parse_macro_part(part_dict)
		macro.parts.push_back(part)

	return macro


static func _parse_macro_part(dict: Dictionary) -> MHMacroPart:
	var part := MHMacroPart.new()
	part.lowest = dict.lowest
	part.highest = dict.highest
	part.low = dict.low
	part.high = dict.high
	return part


static func _parse_combination(
	combination_name: String,
	dimensions: PackedStringArray,
	macrotargets: Dictionary[StringName, MHMacro],
	targets_dir: String,
) -> MHMacroCombination:
	var combination := MHMacroCombination.new()
	combination.dimensions.assign(dimensions)

	var metadata: Dictionary = MACRO_METADATA[combination_name]
	combination.allowed_components.assign(metadata.get("allowed_components", { }))
	combination.weight_exclusions.assign(metadata.get("weight_exclusions", []))

	var component_sets: Array[PackedStringArray]
	for name in combination.dimensions:
		if name == "race":
			component_sets.push_back(MHMacroRegistry.RACES)
		else:
			component_sets.push_back(macrotargets[name].get_components())

	var target_dir := targets_dir.path_join(metadata.directory)
	var selected_components: PackedStringArray # Temporary value to build current component combination.
	var prefix: String = metadata.get("prefix", "")
	_load_target_combinations(
		combination,
		component_sets,
		selected_components,
		0,
		target_dir,
		prefix,
	)

	return combination


static func _load_target_combinations(
	combination: MHMacroCombination,
	component_sets: Array[PackedStringArray],
	selected_components: PackedStringArray,
	dim_index: int,
	target_dir: String,
	prefix: String,
) -> void:
	if dim_index == component_sets.size():
		var without_prefix := "-".join(selected_components)
		var target_name := without_prefix
		if prefix:
			target_name = prefix + "-" + without_prefix

		# Missing combinations are expected. For example, there are no baby proportion
		# targets and no male breast targets in the bundled data.
		var target := _load_target(target_name, target_dir, true)
		if target:
			combination.targets[without_prefix] = target

		return

	var component_names := component_sets[dim_index]
	for name in component_names:
		selected_components.push_back(name)
		_load_target_combinations(
			combination,
			component_sets,
			selected_components,
			dim_index + 1,
			target_dir,
			prefix,
		)
		selected_components.remove_at(selected_components.size() - 1)


static func _load_target(target_name: String, dir: String, optional := false) -> MHTarget:
	var base_path := dir.path_join(target_name)
	var full_path := base_path + ".target"
	if FileAccess.file_exists(full_path):
		return ResourceLoader.load(full_path) as MHTarget

	full_path = base_path + ".target.gz"
	if FileAccess.file_exists(full_path):
		return ResourceLoader.load(full_path) as MHTarget

	if not optional:
		push_error("Unable to find '%s'" % base_path)

	return null


func _import_vertex_groups(dict: Dictionary, save_path: String) -> Error:
	var vertex_groups := MHVertexGroups.new()
	for group_name: String in dict:
		if group_name != "body" and not group_name.begins_with("joint-"):
			continue

		var ranges: PackedInt32Array
		for vertex_range: Array in dict[group_name]:
			assert(vertex_range.size() == 2)
			ranges.push_back(vertex_range[0])
			ranges.push_back(vertex_range[1])

		vertex_groups.ranges[group_name] = ranges

	return ResourceSaver.save(vertex_groups, "%s.%s" % [save_path, _get_save_extension()])


func _import_rig(dict: Dictionary, save_path: String) -> Error:
	var rig := MHRig.new()
	var bone_indices: Dictionary[StringName, int]
	for bone_name: String in dict:
		_append_bone_with_parents(bone_name, dict, rig, bone_indices)

	return ResourceSaver.save(rig, "%s.%s" % [save_path, _get_save_extension()])


## Traverse bone ancestors to store them in parent-first order.
static func _append_bone_with_parents(
	bone_name: StringName,
	dict: Dictionary,
	rig: MHRig,
	bone_indices: Dictionary[StringName, int],
) -> int:
	if bone_indices.has(bone_name):
		return bone_indices[bone_name]

	var bone_dict: Dictionary = dict[bone_name]
	var parent_name: StringName = bone_dict.parent
	var parent_index := -1

	if parent_name:
		parent_index = _append_bone_with_parents(parent_name, dict, rig, bone_indices)

	var bone := _parse_bone(bone_name, parent_index, bone_dict)
	rig.bones.push_back(bone)

	var bone_index := rig.bones.size() - 1
	bone_indices[bone_name] = bone_index
	return bone_index


static func _parse_bone(bone_name: StringName, parent_index: int, dict: Dictionary) -> MHBone:
	var bone := MHBone.new()
	bone.name = bone_name
	var export_name: Variant = EXPORT_BONE_NAMES.get(bone_name)
	if not export_name:
		# Rename bones missing in SkeletonProfileHumanoid for consistency.
		export_name = bone_name.to_pascal_case()
	bone.export_name = export_name
	bone.parent_index = parent_index
	bone.head = _parse_rig_position(dict.head)
	bone.tail = _parse_rig_position(dict.tail)
	bone.roll = dict.roll

	assert(not dict.use_connect, "'use_connect' should be 'false' in the game rig")
	assert(dict.use_inherit_rotation, "'use_inherit_rotation' should be 'true' in the game rig")
	assert(dict.use_local_location, "'use_local_location' should be 'true' in the game rig")
	assert(dict.inherit_scale == "FULL", "'inherit_scale' should be 'FULL' in the game rig")

	return bone


static func _parse_rig_position(dict: Dictionary) -> MHRigPosition:
	var position := MHRigPosition.new()
	position.strategy = MHRigPosition.Strategy[dict.strategy]
	if position.strategy == MHRigPosition.Strategy.CUBE:
		position.cube_name = dict.cube_name
	if position.strategy == MHRigPosition.Strategy.VERTEX:
		position.vertex_indices.push_back(dict.vertex_index)
	if position.strategy == MHRigPosition.Strategy.MEAN:
		position.vertex_indices = dict.vertex_indices

	assert(not dict.has("offset"), "'offset' shouldn't be used in the game engine rig")

	return position


func _import_rig_weights(dict: Dictionary, save_path: String) -> Error:
	var weights := MHRigWeights.new()
	var weights_dict: Dictionary = dict.weights
	for bone_name: String in weights_dict:
		var bone := MHBoneWeights.new()
		for bone_array: Array in weights_dict[bone_name]:
			assert(bone_array.size() == 2)
			bone.vertices.push_back(bone_array[0])
			bone.weights.push_back(bone_array[1])

		weights.bones[bone_name] = bone

	return ResourceSaver.save(weights, "%s.%s" % [save_path, _get_save_extension()])
