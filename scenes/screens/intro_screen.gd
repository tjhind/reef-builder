extends Control

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	animate_in()

func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/screens/instructions_screen.tscn")

func animate_in():
	var delay := 0.0
	for element in $Panel.get_children():
		if not (element is CanvasItem):
			continue
		element.modulate.a = 0.0
		var tween = element.create_tween()
		tween.tween_property(element, "modulate:a", 1.0, 0.7).set_delay(delay)
		delay += 0.12
