extends Control

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$ScoreLabel.text = "Completed in %d turns" % [GameData.last_turns, GameData.last_rating]
