@tool
class_name TestRunner
extends Node
## Executes a test in either a runtime or an editor process.


func run(suite_path: String, test_name: String) -> bool:
	var error_tracker := ErrorTracker.new()
	OS.add_logger(error_tracker)

	var passed := await _run_test(suite_path, test_name, error_tracker)
	OS.remove_logger(error_tracker)

	return passed


func _run_test(suite_path: String, test_name: String, error_tracker: ErrorTracker) -> bool:
	var suite := TestSuite.from_path(suite_path)
	if not suite:
		return false

	var method_name := TestSuite.TEST_PREFIX + test_name
	if not suite.has_method(method_name):
		printerr("Unable to find a method named '%s'" % method_name)
		suite.free()
		return false

	if suite.get_method_argument_count(method_name) != 0:
		printerr("Method '%s' shouldn't accept any arguments" % method_name)
		suite.free()
		return false

	suite.error_expected.connect(error_tracker.expect)
	add_child(suite)
	if not suite.is_node_ready():
		await suite.ready

	await suite.call(method_name)
	suite.free()

	if not error_tracker.expected.is_empty():
		for error in error_tracker.expected:
			var type := "error" if error.type == Logger.ERROR_TYPE_ERROR else "warning"
			printerr("Missing expected %s: '%s'" % [type, error.msg])
		return false

	return true


class ErrorTracker extends Logger:
	var expected: Array[ExpectedError]


	func _log_error(
		_function: String,
		_file: String,
		_line: int,
		code: String,
		rationale: String,
		_editor_notify: bool,
		error_type: int,
		_script_backtraces: Array[ScriptBacktrace],
	) -> void:
		var msg := rationale if rationale else code
		if not _consume_expected(error_type, msg):
			OS.kill(OS.get_process_id())


	func expect(type: Logger.ErrorType, msg: String) -> void:
		var error := ExpectedError.new()
		error.type = type
		error.msg = msg
		expected.append(error)


	## Consumes the oldest expectation when it matches [param msg] of the given [param type].
	func _consume_expected(type: Logger.ErrorType, msg: String) -> bool:
		if expected.is_empty():
			return false

		var error := expected[0]
		if error.type != type or not msg.contains(error.msg):
			return false

		expected.remove_at(0)
		return true


	class ExpectedError:
		var msg: String
		var type: Logger.ErrorType
