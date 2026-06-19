extends Node

var player: AudioStreamPlayer

func _ready():
	# keep playing even while the game is paused (e.g. the instructions overlay)
	process_mode = Node.PROCESS_MODE_ALWAYS

	player = AudioStreamPlayer.new()
	player.stream = preload("res://music/background-music.mp3")
	player.volume_db = -6.0         
	add_child(player)

	player.finished.connect(player.play)
	player.play()
