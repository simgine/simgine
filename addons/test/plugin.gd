@tool
extends EditorPlugin
## Starts a test worker when the editor is launched with --test-worker.
##
## Needed for tests that require the editor.
## Regular scripts run with [code]worker.gd[/code].


func _enter_tree() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or args[0] != "--test-worker":
		return

	var tree := get_tree()
	if args.size() != 3:
		printerr("Expected 2 args: path to a script and the test name")
		tree.quit(1)
		return

	var filesystem := EditorInterface.get_resource_filesystem()
	while filesystem.is_scanning() or filesystem.is_importing():
		await tree.process_frame

	var runner := TestRunner.new()
	add_child(runner)

	var passed := await runner.run(args[1], args[2])
	tree.quit(0 if passed else 1)
