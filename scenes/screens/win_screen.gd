extends Control
func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$ScoreLabel.text = "Completed in %d coral growth cycles" % GameData.last_turns
