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

	var process := OS.execute_with_pipe(OS.get_executable_path(), args, false)

	if not process:
		printerr("Failed to start worker")
		return false

	var tree := Engine.get_main_loop() as SceneTree
	var pid: int = process.pid
	while true:
		var process_running := OS.is_process_running(pid)

		_read_pipe(process.stdio, test_name)
		_read_pipe(process.stderr, test_name)

		if not process_running:
			break

		await tree.physics_frame

	return OS.get_process_exit_code(pid) == 0


func _read_pipe(pipe: FileAccess, test_name: String) -> void:
	var available := pipe.get_length()
	if available <= 0:
		return

	var output := pipe.get_buffer(available).get_string_from_utf8().replace("res://", "")
	if output:
		outputs[test_name] += output
		output_received.emit(output)
