extends Control
func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$ScoreLabel.text = "Lasted %d turns" % GameData.last_turns
