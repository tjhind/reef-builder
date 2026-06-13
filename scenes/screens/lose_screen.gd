extends Control

func _ready():
	$ScoreLabel.text = "Completed in %d turns" % [GameData.last_turns, GameData.last_rating]
