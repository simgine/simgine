extends SceneTree
## Entry point for tests that don't require the editor.
##
## Tests that require the editor run through [code]plugin.gd[/code] instead
## because combining [code]--editor[/code] and [code]--script[/code] replaces
## the editor's initial [class SceneTree] without freeing it. This causes
## leak warnings at shutdown.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		printerr("Expected 2 args: path to a script and the test name")
		quit(1)
		return

	var runner := TestRunner.new()
	root.add_child(runner)
	if not runner.is_node_ready():
		await runner.ready

	var passed := await runner.run(args[0], args[1])
	quit(0 if passed else 1)
