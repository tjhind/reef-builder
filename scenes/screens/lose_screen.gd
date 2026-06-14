extends Control
func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$ScoreLabel.text = "you lasted %d coral growth cycles" % GameData.last_turns
