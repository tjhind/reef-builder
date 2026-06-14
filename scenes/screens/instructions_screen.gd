extends Control

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_button_pressed() -> void:
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file("res://scenes/screens/game_screen.tscn")
	else:
		get_tree().paused = false
		queue_free()
