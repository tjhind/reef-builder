extends Control

@onready var terrain_tilemap = $TerrainTileMap

const DEEP_SEA_SOURCE = 0
const ROCK_SOURCE = 1
const SAND_SOURCE = 2
const WIDTH = 15
const HEIGHT = 15


const ORTHOGONAL_DIRS := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
const DIAGONAL_DIRS := [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]

enum Coral { BRANCHING, BRAIN, FAN }
const CORAL_HEALTH := { Coral.BRANCHING: 1, Coral.FAN: 2, Coral.BRAIN: 3 }
const POLLUTION_RATE := 1  

@export var branching_texture: Texture2D
@export var brain_texture: Texture2D
@export var fan_texture: Texture2D
@export var pollution_texture: Texture2D

var coral_textures: Dictionary = {}
var coral_types := [Coral.BRANCHING, Coral.BRAIN, Coral.FAN]
var total_growable := 0   # sand + rock tiles, counted once at start
var turn_count := 0
@onready var coral_label: Label = $ScorePanel/CoralLabel
@onready var pollution_label: Label = $ScorePanel/PollutionLabel
@onready var turn_label: Label = $ScorePanel/TurnLabel

# logical state of the board — the source of truth 
var coral_grid: Dictionary = {}
var pollution_grid: Dictionary = {}   

var current_coral: int
var cursor_sprite: Sprite2D

func _ready():
	randomize()
	generate_terrain()
	count_growable()
	fit_board_to_screen()
	setup_coral()
	spawn_pollution(2)
	update_hud()

func generate_terrain():
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var roll = randf()
			var source_id: int
			if roll < 0.70:
				source_id = SAND_SOURCE
			elif roll < 0.90:
				source_id = ROCK_SOURCE
			else:
				source_id = DEEP_SEA_SOURCE
			terrain_tilemap.set_cell(Vector2i(x, y), source_id, Vector2i(0, 0))


func fit_board_to_screen():
	var viewport = get_viewport_rect().size
	var top_margin = 200     
	var bottom_margin = 200 
	var available_height = viewport.y - top_margin - bottom_margin
	var board_tiles_px = WIDTH * terrain_tilemap.tile_set.tile_size.x

	var s = min(viewport.x / board_tiles_px, available_height / board_tiles_px)
	terrain_tilemap.scale = Vector2(s, s)

	var board_px = board_tiles_px * s
	terrain_tilemap.position = Vector2(
		(viewport.x - board_px) / 2.0,
		top_margin + (available_height - board_px) / 2.0
	)

func setup_coral():
	coral_textures = {
		Coral.BRANCHING: branching_texture,
		Coral.BRAIN: brain_texture,
		Coral.FAN: fan_texture,
	}
	# "ghost" sprite 
	cursor_sprite = Sprite2D.new()
	cursor_sprite.scale = terrain_tilemap.scale   
	cursor_sprite.z_index = 100                   
	add_child(cursor_sprite)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN    
	give_new_coral()


func give_new_coral():
	current_coral = coral_types.pick_random()
	cursor_sprite.texture = coral_textures[current_coral]


func _process(_delta):
	cursor_sprite.position = get_global_mouse_position()
	if is_valid_placement(get_hovered_tile()):
		cursor_sprite.modulate = Color(1, 1, 1, 0.7)      
	else:
		cursor_sprite.modulate = Color(1, 0.4, 0.4, 0.6)  


func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		try_place_coral(get_hovered_tile())


func get_hovered_tile() -> Vector2i:
	var local = terrain_tilemap.to_local(get_global_mouse_position())
	return terrain_tilemap.local_to_map(local)


func is_valid_placement(coords: Vector2i) -> bool:
	if coords.x < 0 or coords.x >= WIDTH or coords.y < 0 or coords.y >= HEIGHT:
		return false
	var terrain = terrain_tilemap.get_cell_source_id(coords)
	if terrain == DEEP_SEA_SOURCE or terrain == -1:
		return false
	if coral_grid.has(coords):
		return false
	if pollution_grid.has(coords):  
		return false
	return true

func try_place_coral(coords: Vector2i):
	if not is_valid_placement(coords):
		print("Invalid placement at ", coords)
		return
	place_coral(coords, current_coral)
	end_turn()


func end_turn():
	spread_coral()
	pollution_spread()
	turn_count += 1
	update_hud()
	if check_win_loss():
		return            
	give_new_coral()

func spread_coral():
	# Snapshot the coral that exists at the START of the turn.
	# tiles grown THIS turn must not spread again this turn.
	var sources = coral_grid.keys()
	for coords in sources:
		var type = coral_grid[coords]["type"]
		var budget = get_spread_budget(coords, type)
		var dirs = DIAGONAL_DIRS if type == Coral.FAN else ORTHOGONAL_DIRS

		var targets := []
		for dir in dirs:
			if is_valid_placement(coords + dir):
				targets.append(coords + dir)

		targets.shuffle()
		for i in range(min(budget, targets.size())):
			place_coral(targets[i], type)


func get_spread_budget(coords: Vector2i, type: int) -> int:
	var budget = 1 
	var terrain = terrain_tilemap.get_cell_source_id(coords)
	if terrain == SAND_SOURCE:
		budget += 1
	elif terrain == ROCK_SOURCE:
		budget += 2
	if type == Coral.BRANCHING:
		budget += 2
	return budget

func place_coral(coords: Vector2i, type: int):
	var sprite = Sprite2D.new()
	sprite.texture = coral_textures[type]
	sprite.position = terrain_tilemap.map_to_local(coords)
	terrain_tilemap.add_child(sprite)
	coral_grid[coords] = { "type": type, "sprite": sprite, "health": CORAL_HEALTH[type] }
	
	
	
func spawn_pollution(count: int):
	var placed = 0
	var attempts = 0
	while placed < count and attempts < 1000:
		attempts += 1
		var c = Vector2i(randi() % WIDTH, randi() % HEIGHT)
		var terrain = terrain_tilemap.get_cell_source_id(c)
		if terrain == DEEP_SEA_SOURCE or terrain == -1:
			continue          # not on deep sea / empty
		if pollution_grid.has(c):
			continue          # not on an existing source
		pollute_tile(c)
		placed += 1


func pollution_spread():
	for step in range(POLLUTION_RATE):
		advance_pollution()


func advance_pollution():
	var sources = pollution_grid.keys()
	for coords in sources:
		for dir in ORTHOGONAL_DIRS:
			var n = coords + dir
			if not can_pollute(n):
				continue
			if coral_grid.has(n):
				damage_coral(n) 
			else:
				pollute_tile(n) 


func can_pollute(coords: Vector2i) -> bool:
	if coords.x < 0 or coords.x >= WIDTH or coords.y < 0 or coords.y >= HEIGHT:
		return false
	var terrain = terrain_tilemap.get_cell_source_id(coords)
	if terrain == DEEP_SEA_SOURCE or terrain == -1:
		return false
	if pollution_grid.has(coords):
		return false   # already polluted
	return true        # empty OR coral are both valid targets


func damage_coral(coords: Vector2i):
	coral_grid[coords]["health"] -= 1
	if coral_grid[coords]["health"] <= 0:
		kill_coral(coords)
	else:
		# darken survivors so damage is visible: TODO add new assets for this 
		coral_grid[coords]["sprite"].modulate = Color(0.7, 0.7, 0.7)


func kill_coral(coords: Vector2i):
	coral_grid[coords]["sprite"].queue_free()
	coral_grid.erase(coords)
	pollute_tile(coords)   # the dead coral's tile becomes pollution


func pollute_tile(coords: Vector2i):
	var sprite = Sprite2D.new()
	sprite.texture = pollution_texture
	sprite.position = terrain_tilemap.map_to_local(coords)
	terrain_tilemap.add_child(sprite)
	pollution_grid[coords] = { "sprite": sprite }
	
	
func count_growable():
	total_growable = 0
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var t = terrain_tilemap.get_cell_source_id(Vector2i(x, y))
			if t == SAND_SOURCE or t == ROCK_SOURCE:
				total_growable += 1


func get_coral_coverage() -> float:
	if total_growable == 0:
		return 0.0
	return float(coral_grid.size()) / total_growable


func get_pollution_coverage() -> float:
	if total_growable == 0:
		return 0.0
	return float(pollution_grid.size()) / total_growable


func check_win_loss() -> bool:
	if get_coral_coverage() >= 0.70:
		win()
		return true
	if get_pollution_coverage() >= 0.70:
		lose()
		return true
	return false


func win():
	GameData.last_turns = turn_count
	GameData.last_rating = get_rating()
	get_tree().change_scene_to_file("res://scenes/screens/win_screen.tscn")


func lose():
	GameData.last_turns = turn_count
	get_tree().change_scene_to_file("res://scenes/screens/lose_screen.tscn")

func get_rating() -> String:
	if turn_count <= 15:
		return "Gold"
	elif turn_count <= 20:
		return "Silver"
	else:
		return "Bronze"

func update_hud():
	coral_label.text = "Coral: %d%%" % int(round(get_coral_coverage() * 100))
	pollution_label.text = "Pollution: %d%%" % int(round(get_pollution_coverage() * 100))
	turn_label.text = "Turn: %d" % turn_count
