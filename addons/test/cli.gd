extends SceneTree
## Command-line interface for running tests, inspired by Cargo.
##
## Run it using [code]godot --headless --script addons/test/cli.gd[/code].
## See [code]--help[/code] for usage details.

var jobs: int = OS.get_processor_count()
var nocapture: bool
var list: bool
var exact: bool
var filter: String
var test: String
var help: bool


func _initialize() -> void:
	if not parse_args():
		quit(1)
		return

	if help:
		print_usage()
		quit()
		return

	if list:
		list_suites()
		quit()
		return

	if not await run_suites():
		quit(1)
		return

	quit()


func parse_args() -> bool:
	var args := OS.get_cmdline_user_args()

	var index := 0
	while index < args.size():
		var arg := args[index]
		index += 1
		match arg:
			"--help":
				help = true
			"--list":
				list = true
			"--nocapture":
				nocapture = true
			"--exact":
				exact = true
			"--jobs":
				if index >= args.size():
					printerr("Missing value for --jobs")
					return false

				var value := args[index]
				index += 1
				if not value.is_valid_int():
					printerr("Invalid jobs count: '%s'" % value)
					return false

				jobs = value.to_int()
				if jobs < 1:
					printerr("Jobs must be greater than zero")
					return false
			"--test":
				if index >= args.size():
					printerr("Missing value for --test")
					return false

				test = args[index]
				index += 1
			_:
				if arg.begins_with("-"):
					printerr("Unknown option: '%s'" % arg)
					return false

				if filter:
					printerr("Unexpected argument: '%s'" % arg)
					return false

				filter = arg

	return true


func run_suites() -> bool:
	if test:
		var suite := TestSuite.from_path(test)
		return await run_suite(suite) if suite else false

	var passed := true
	for path in TestSuite.discover():
		var suite := TestSuite.from_path(path)
		if not suite or not await run_suite(suite):
			passed = false

	return passed


func run_suite(suite: TestSuite) -> bool:
	var runner := SuiteRunner.new(suite.get_script_path(), suite.requires_editor())
	runner.test_completed.connect(
		func(test_name: String, ok: bool) -> void:
			print(
				"test %s ... %s"
				% [
					test_name,
					Ansi.paint("ok", Ansi.GREEN) if ok else Ansi.paint("FAILED", Ansi.RED),
				]
			),
	)
	if nocapture:
		runner.output_received.connect(printraw)

	var tests: PackedStringArray
	var filtered_out := 0
	for test_name in suite.get_test_names():
		if filter:
			var matched := test_name == filter if exact else test_name.contains(filter)
			if not matched:
				filtered_out += 1
				continue

		tests.append(test_name)

	print(
		"     %s %s:\n" % [Ansi.paint("Running", Ansi.BOLD_BRIGHT_GREEN), suite.get_relative_path()]
	)
	print("running %d %s" % [tests.size(), "test" if tests.size() == 1 else "tests"])
	var started_ms := Time.get_ticks_msec()
	var max_jobs := 1 if runner.editor_mode else jobs
	for test_name in tests:
		while runner.running >= max_jobs:
			await runner.test_completed

		runner.start(test_name)

	while runner.running > 0:
		await runner.test_completed

	var passed := runner.failed.size() == 0
	if not passed:
		print("\nfailures:\n")
		for test_name in runner.failed:
			print("---- %s output ----" % test_name)
			print(runner.outputs[test_name])

		print("\nfailures:")
		for test_name in runner.failed:
			print("    " + test_name)

	print(
		"\ntest result: %s. %d passed; %d failed; %d filtered out; finished in %.2fs\n"
		% [
			Ansi.paint("ok", Ansi.GREEN) if passed else Ansi.paint("FAILED", Ansi.RED),
			tests.size() - runner.failed.size(),
			runner.failed.size(),
			filtered_out,
			(Time.get_ticks_msec() - started_ms) / 1000.0,
		]
	)

	suite.free()

	return passed


static func list_suites() -> void:
	for path in TestSuite.discover():
		var suite := TestSuite.from_path(path)
		if not suite:
			continue

		print(
			"     %s %s:\n"
			% [Ansi.paint("Listing", Ansi.BOLD_BRIGHT_GREEN), suite.get_relative_path()]
		)
		var total := 0
		for test_name in suite.get_test_names():
			print("%s" % test_name.trim_prefix(TestSuite.TEST_PREFIX))
			total += 1

		suite.free()
		print()
		print("%d %s\n" % [total, "test" if total == 1 else "tests"])


static func print_usage() -> void:
	print(
		"""Run the project's test suites in parallel.

Usage: godot --headless --script addons/test/cli.gd -- [OPTIONS] [FILTER]

Options:
  --list                 List all test suites and their tests
  --nocapture            Don't capture stdout/stderr of each task, allow
                         printing directly
  --exact                Exactly match the filter rather than by substring
  --jobs <COUNT>         Number of parallel runtime jobs, defaults to # of CPUs;
                         editor-mode tests run sequentially
  --test <SUITE>         Test only the specified script file; can be
                         located outside of the tests directory
  --help                 Print help

Arguments:
	[FILTER]             Only run tests with this string in their names,
                         or with exactly this name when --exact is set"""
	)
