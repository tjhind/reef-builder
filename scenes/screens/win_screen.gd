extends Control

func _ready():
	$ScoreLabel.text = "Completed in %d turns\nRating: %s" % [GameData.last_turns, GameData.last_rating]
