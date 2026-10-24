extends MarginContainer


func _open_character_editor() -> void:
	Log.info("Opening the character editor")
	get_tree().change_scene_to_file("res://character_editor/character_editor.tscn")


func _exit_game() -> void:
	Log.info("Exiting the game")
	get_tree().quit()
