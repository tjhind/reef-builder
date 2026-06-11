extends Control

func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/screens/game_screen.tscn")
