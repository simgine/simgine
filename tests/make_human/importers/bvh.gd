extends TestSuite

const STANDING_POSE := "res://characters/visuals/make_human/data/poses/callharvey3d_standingnatural/callharvey3d_standingnatural.bvh"
const RIG := "res://characters/visuals/make_human/data/rigs/rig.default.json"


func requires_editor() -> bool:
	return true


func test_pose() -> void:
	var importer := MHBVHImporter.new()

	var saver := TestResourceSaver.new()
	ResourceSaver.add_resource_format_saver(saver, true)

	var error := importer._import(
		STANDING_POSE,
		"",
		{ "rig": RIG, "bone_map": "", "reference_pose": "" },
		[],
		[],
	)
	assert_eq(error, OK)

	var pose := saver.resource as MHNativePose
	assert_eq(pose.rig, load(RIG))
	assert_eq(pose.rotations.size(), 163)
	assert_approx_eq(
		Basis(pose.rotations["wrist.L"]),
		Basis(Quaternion(0.0000010874495, -0.1961218, -0.00000058030827, 0.98057956)),
	)
	assert_approx_eq(pose.translations["root"], Vector3(0, -0.06397821, -0.016439797))


func test_retargeted_pose() -> void:
	var importer := MHBVHImporter.new()

	var saver := TestResourceSaver.new()
	ResourceSaver.add_resource_format_saver(saver, true)

	var error := importer._import(
		STANDING_POSE,
		"",
		{
			"rig": RIG,
			"bone_map": "res://characters/visuals/make_human/data/rigs/default_bone_map.tres",
			"reference_pose": "res://characters/visuals/make_human/data/poses/default_fk/t-pose.json",
		},
		[],
		[],
	)
	assert_eq(error, OK)

	var pose := saver.resource as MHPose
	assert_approx_eq(
		Basis(pose.rotations["LeftHand"]),
		Basis(Quaternion(0.02093259, 0.56021804, -0.050638873, 0.8265309)),
	)
	assert_approx_eq(
		Basis(pose.rotations["LeftFoot"]),
		Basis(Quaternion(-0.1175437, -0.6595445, 0.71776223, -0.18974155)),
	)
