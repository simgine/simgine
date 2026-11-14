class_name GodotProcess
## Runs a Godot subprocess and captures its output.

signal output_received(text: String)

var output: String


func run(args: PackedStringArray) -> int:
	output = ""
	var process := OS.execute_with_pipe(OS.get_executable_path(), args, false)
	if not process:
		printerr("Unable to run Godot")
		return -1

	var tree := Engine.get_main_loop() as SceneTree
	var pid: int = process.pid
	while true:
		var process_running := OS.is_process_running(pid)
		_read_pipe(process.stdio)
		_read_pipe(process.stderr)

		if not process_running:
			break

		await tree.process_frame

	return OS.get_process_exit_code(pid)


func _read_pipe(pipe: FileAccess) -> void:
	var text := pipe.get_buffer(pipe.get_length()).get_string_from_utf8()
	if text:
		output += text
		output_received.emit(text)
