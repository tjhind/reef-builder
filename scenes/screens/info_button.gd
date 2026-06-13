extends Button


# Called when the node enters the scene tree for the first time.
func _on_info_button_pressed() -> void:
		get_tree().change_scene_to_file("res://scenes/screens/instructions_screen.tscn")
