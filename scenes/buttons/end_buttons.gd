extends HBoxContainer

@export var restart_label: String = "Play Again"

@onready var restart_button: Button = $RestartButton
@onready var quit_button: Button = $QuitButton

func _ready():
	restart_button.text = restart_label
	restart_button.pressed.connect(on_restart)
	quit_button.pressed.connect(on_quit)


func on_restart() -> void:
	get_tree().change_scene_to_file("res://scenes/screens/game_screen.tscn")


func on_quit() -> void:
		get_tree().change_scene_to_file("res://scenes/screens/intro_screen.tscn")
