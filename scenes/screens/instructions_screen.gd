extends Control

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false


func _on_button_pressed() -> void:
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file("res://scenes/screens/game_screen.tscn")
	else:
		get_tree().paused = false
		queue_free()

func _on_back_button_pressed() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/screens/intro_screen.tscn")
