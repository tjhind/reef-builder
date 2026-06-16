extends Control
func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$ScoreLabel.text = "Completed in %d coral growth cycles" % GameData.last_turns
	modulate.a = 0.0
	var t = create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.5)
	$ScoreLabel.modulate.a = 0.0
	t.tween_property($ScoreLabel, "modulate:a", 1.0, 0.5)
