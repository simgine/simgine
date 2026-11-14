class_name TestSuite
extends Node
## Base class for defining test suites.
##
## Unlike other test frameworks, the first encountered error or warning
## terminates the script execution, unless it was marked as expected with
## [method expect_error] or [method expect_warning].
##
## All functions that begin with [constant TEST_PREFIX] will be treated as
## tests that can run via the CLI script: [code]res://addons/test/cli.gd[/code].
## Tests run in parallel, but each test runs in its own Godot process, so no
## data is shared between them. Assets are pre-imported once. Avoid changing
## project files or triggering imports while tests run.
##
## Only files located in [code]res://tests[/code] will be automatically discovered.
##
## Use methods like [method @GDScript.assert], [method assert_eq],
## [method assert_ne], [method assert_approx_eq] or [method panic] to
## assert expected values.

signal error_expected(type: Logger.ErrorType, msg: String)

const TEST_PREFIX: String = "test_"


## Asserts that [param left] and [param right] are equal.
##
## Regular and packed arrays are compared recursively element-wise,
## ignoring their storage types, and must have equal sizes.
##
## Calls [method panic] if the arguments are not equal, printing their
## values and the optional [param msg].
static func assert_eq(left: Variant, right: Variant, msg: String = "") -> void:
	if not _is_equal(left, right):
		var details := ": " + msg if msg else ""
		var panic_msg := "\n".join(
			[
				"assertion `left == right` failed" + details,
				"  left: %s" % var_to_str(left),
				" right: %s" % var_to_str(right),
			]
		)

		panic(panic_msg)


## Like [method assert_eq], but asserts that the values are not equal.
static func assert_ne(left: Variant, right: Variant, msg: String = "") -> void:
	if _is_equal(left, right):
		var details := ": " + msg if msg else ""
		var panic_msg := "\n".join(
			[
				"assertion `left != right` failed" + details,
				"  left: %s" % var_to_str(left),
				" right: %s" % var_to_str(right),
			]
		)

		panic(panic_msg)


## Asserts that [param left] and [param right] are approximately equal,
## within a relative [param epsilon].
##
## Two values are approximately equal when their distance does not exceed
## [param epsilon] times the larger of the two magnitudes.
## [param left] and [param right] must be floats, ints or one
## of the vector types: Vector2, Vector3, Vector4 or Quaternion.
## Arrays of supported values are compared recursively element-wise
## and must have equal sizes.
##
## Calls [method panic] if the values are not approximately equal, printing
## their values, [param epsilon] and the optional [param msg].
static func assert_approx_eq(
	left: Variant,
	right: Variant,
	epsilon: float = 1e-6,
	msg: String = "",
) -> void:
	if not _is_equal_approx(left, right, epsilon):
		var details := ": " + msg if msg else ""
		var panic_msg := "\n".join(
			[
				"assertion `left == right` failed" + details,
				"  left: %s" % var_to_str(left),
				" right: %s" % var_to_str(right),
				"epsilon: %s" % epsilon,
			]
		)

		panic(panic_msg)


## Like [method assert_approx_eq], but asserts that the values are not
## approximately equal.
static func assert_approx_ne(
	left: Variant,
	right: Variant,
	epsilon: float = 1e-6,
	msg: String = "",
) -> void:
	if _is_equal_approx(left, right, epsilon):
		var details := ": " + msg if msg else ""
		var panic_msg := "\n".join(
			[
				"assertion `left != right` failed" + details,
				"  left: %s" % var_to_str(left),
				" right: %s" % var_to_str(right),
				"epsilon: %s" % epsilon,
			]
		)

		panic(panic_msg)


static func _is_equal(left: Variant, right: Variant) -> bool:
	var left_is_array := _is_array(left)
	var right_is_array := _is_array(right)
	if left_is_array or right_is_array:
		if not left_is_array or not right_is_array or left.size() != right.size():
			return false

		for index: int in left.size():
			if not _is_equal(left[index], right[index]):
				return false

		return true

	return left == right


static func _is_equal_approx(left: Variant, right: Variant, epsilon: float) -> bool:
	var left_is_array := _is_approx_array(left)
	var right_is_array := _is_approx_array(right)
	if left_is_array or right_is_array:
		if not left_is_array or not right_is_array or left.size() != right.size():
			return false

		for index: int in left.size():
			if not _is_equal_approx(left[index], right[index], epsilon):
				return false

		return true

	# NaN remains unequal, including inside arrays.
	return _relative_epsilon(left, right) <= epsilon


static func _is_array(value: Variant) -> bool:
	return (
		_is_approx_array(value) or value is PackedByteArray or value is PackedInt32Array
		or value is PackedInt64Array or value is PackedStringArray or value is PackedColorArray
	)


static func _is_approx_array(value: Variant) -> bool:
	return (
		value is Array or value is PackedFloat32Array or value is PackedFloat64Array
		or value is PackedVector2Array or value is PackedVector3Array or value is PackedVector4Array
	)


## Returns the relative distance between [param a] and [param b]: their
## distance divided by the larger of the two magnitudes.
static func _relative_epsilon(a: Variant, b: Variant) -> float:
	var distance := _magnitude(a - b)
	if distance == 0.0:
		return 0.0

	var magnitude := maxf(_magnitude(a), _magnitude(b))
	if magnitude == 0.0:
		return 0.0

	return distance / magnitude


static func _magnitude(value: Variant) -> float:
	if value is float or value is int:
		return absf(value)

	return value.length()


## Prints a message and ends execution of the current process.
##
## [param msg] is pushed as an error before the process exits.
static func panic(msg: String) -> void:
	push_error(msg)
	OS.kill(OS.get_process_id())


## Expects an error from [method @GDScript.push_error] whose message
## contains [param msg].
##
## When a matching error is logged, the expectation is consumed
## and the error does not terminate the test.
##
## Multiple expectations can be registered. Errors are matched
## against expectations in the order they were registered.
##
## Each expectation can match only one error. Call this method
## again to expect the same error multiple times.
##
## The test fails if any expectations remain unmet at the end of the test.
func expect_error(msg: String) -> void:
	error_expected.emit(Logger.ERROR_TYPE_ERROR, msg)


## Like [method expect_error], but for warnings from [method @GDScript.push_warning].
func expect_warning(msg: String) -> void:
	error_expected.emit(Logger.ERROR_TYPE_WARNING, msg)


## Whether the tests in this script require editor mode.
##
## Useful for testing features that require editor mode, such as importers.
## Test suites must be instantiable in runtime mode for test discovery,
## so keep any logic that requires editor mode inside the test methods.
func requires_editor() -> bool:
	return false


func get_script_path() -> String:
	return get_script().resource_path


func get_relative_path() -> String:
	return get_script_path().trim_prefix("res://")


func get_test_names() -> PackedStringArray:
	var tests: PackedStringArray
	for method in get_method_list():
		var method_name: String = method.name
		if method_name.begins_with(TEST_PREFIX):
			tests.append(method_name.trim_prefix(TEST_PREFIX))

	return tests


static func discover() -> PackedStringArray:
	return _discover_recursively("res://tests")


static func _discover_recursively(scripts_dir: String) -> PackedStringArray:
	var paths: PackedStringArray
	for file in DirAccess.get_files_at(scripts_dir):
		if file.ends_with(".gd"):
			paths.append(scripts_dir.path_join(file))

	for dir in DirAccess.get_directories_at(scripts_dir):
		paths.append_array(_discover_recursively(scripts_dir.path_join(dir)))

	return paths


static func from_path(path: String) -> TestSuite:
	var script := load(path) as Script
	if not script:
		printerr("Unable to load %s" % path)
		return null

	var suite := script.new() as TestSuite
	if not suite:
		printerr("Script %s is not a TestSuite" % path)
		return null

	return suite
