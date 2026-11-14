class_name SuiteRunner
## Runs each test in a separate Godot runtime or editor process.

signal test_completed(test_name: String, ok: bool)
signal output_received(output: String)

var running: int = 0

var suite_path: String
var editor_mode: bool
var outputs: Dictionary[String, String]
var failed: PackedStringArray


func _init(p_suite_path: String, p_editor_mode: bool = false) -> void:
	suite_path = p_suite_path
	editor_mode = p_editor_mode


func start(test_name: String) -> void:
	outputs.set(test_name, "")
	running += 1

	var ok := await run(test_name)
	if not ok:
		failed.append(test_name)

	running -= 1
	test_completed.emit(test_name, ok)


func run(test_name: String) -> bool:
	var args: PackedStringArray = ["--headless", "--no-header"]
	if editor_mode:
		args.append_array(["--editor", "--", "--test-worker"])
	else:
		args.append_array(["--script", "res://addons/test/worker.gd", "--"])
	args.append_array([suite_path, test_name])

	var process := GodotProcess.new()
	process.output_received.connect(_capture_output.bind(test_name))
	return await process.run(args) == 0


func _capture_output(text: String, test_name: String) -> void:
	var output := text.replace("res://", "")
	if output:
		outputs[test_name] += output
		output_received.emit(output)
