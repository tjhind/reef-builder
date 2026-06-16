extends Control

@onready var board_mask = $BoardMask
@onready var terrain_tilemap = $BoardMask/TerrainTileMap

const DEEP_SEA_SOURCE = 4
const ROCK_SOURCE = 9
const SAND_SOURCE = 5
const WIDTH = 15
const HEIGHT = 15


const HAND_SIZE := 3
const RECLAIM_NEIGHBOURS := 3 
const RECLAIM_CHANCE := 0.6
const CORAL_SPREAD_CHANCE := 0.6   
const POLLUTION_SPREAD_CHANCE := 0.5
const LOW_TILES_WARNING := 3


var warning_label: Label
var hand: Array = []         
var selected_index: int = 0    
var card_buttons: Array = []   
var just_placed = null


@onready var hand_panel: HBoxContainer = %HandPanel

const ORTHOGONAL_DIRS := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
const DIAGONAL_DIRS := [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]

enum Coral { BRANCHING, BRAIN, FAN }
const CORAL_HEALTH := { Coral.BRANCHING: 2, Coral.FAN: 3, Coral.BRAIN: 4 }
const POLLUTION_RATE := 1  
const CORAL_SUPPRESSION := 0.25 

const STATUS_MESSAGES := {
	"warn": ["look carefully for empty spaces on the reef - including ones on the rocks."],
	"winning_big": ["the reef is thriving, you're almost there!",
		"life is winning! just a little more and the reef is saved."],
	"danger": ["the reef is in danger, surround the pollution to push it back!",
		"don't give up, wall it off and reclaim your reef!"],
	"losing": ["pollution is gaining ground - fight back!",
		"the tide's against you, but the reef can recover. keep going!"],
	"winning": ["the coral is spreading beautifully - keep it up!",
		"life is taking hold across the seabed. push onward!"],
	"start": ["click to choose a coral from the toolbox and start spreading life across the reef."],
	"close": ["it's neck and neck - every coral counts!",
		"too close to call! make every placement matter."],
}

var current_status_key := ""
var current_status_text := ""

@export var branching_texture: Texture2D
@export var brain_texture: Texture2D
@export var fan_texture: Texture2D
@export var branching_tiles: Array[Texture2D]
@export var brain_tiles: Array[Texture2D]
@export var fan_tiles: Array[Texture2D]
@export var pollution_textures: Array[Texture2D]
@export var fish_texture: Texture2D
@export var pollution_cloud_texture: Texture2D



var coral_textures: Dictionary = {}
var coral_tile_variants: Dictionary = {}
var coral_types := [Coral.BRANCHING, Coral.BRAIN, Coral.FAN]
var total_growable := 0 
var turn_count := 0
@onready var race_bar = %RaceBar

# source of truth of the state of the board
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
	spawn_pollution(1)
	setup_warning_label()
	update_hud()

func generate_terrain():
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var source_id = SAND_SOURCE if randf() < 0.75 else ROCK_SOURCE
			terrain_tilemap.set_cell(Vector2i(x, y), source_id, random_variant(source_id), random_transform())


func random_transform() -> int:
	var t = 0
	if randf() < 0.5:
		t |= TileSetAtlasSource.TRANSFORM_FLIP_H
	if randf() < 0.5:
		t |= TileSetAtlasSource.TRANSFORM_FLIP_V
	if randf() < 0.5:
		t |= TileSetAtlasSource.TRANSFORM_TRANSPOSE
	return t

func random_variant(source_id: int) -> Vector2i:
	var source = terrain_tilemap.tile_set.get_source(source_id) as TileSetAtlasSource
	return source.get_tile_id(randi() % source.get_tiles_count())

func fit_board_to_screen():
	var viewport = get_viewport_rect().size
	var top_margin = 200
	var bottom_margin = 200
	var available_height = viewport.y - top_margin - bottom_margin
	var board_tiles_px = WIDTH * terrain_tilemap.tile_set.tile_size.x
	var s = min(viewport.x / board_tiles_px, available_height / board_tiles_px)
	var board_px = board_tiles_px * s

	# size & place the mask where the board should sit
	board_mask.size = Vector2(board_px, board_px)
	board_mask.position = Vector2(
		(viewport.x - board_px) / 2.0,
		top_margin + (available_height - board_px) / 2.0
	)
	board_mask.queue_redraw()

	terrain_tilemap.scale = Vector2(s, s)
	terrain_tilemap.position = Vector2.ZERO

func setup_coral():
	coral_textures = {
		Coral.BRANCHING: branching_texture,
		Coral.BRAIN: brain_texture,
		Coral.FAN: fan_texture,
	}
	coral_tile_variants = {
		Coral.BRANCHING: branching_tiles,
		Coral.BRAIN: brain_tiles,
		Coral.FAN: fan_tiles,
	}
	# "ghost" sprite 
	cursor_sprite = Sprite2D.new()
	cursor_sprite.scale = terrain_tilemap.scale   
	cursor_sprite.z_index = 100   
	cursor_sprite.visible = false                   
	add_child(cursor_sprite)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   
	deal_hand()
	build_hand_ui()
	update_cursor_to_selection()


func deal_hand():
	hand.clear()
	for i in range(HAND_SIZE):
		hand.append(coral_types.pick_random())
	selected_index = 0


func build_hand_ui():
	# Clear out any old cards, then create one button per hand slot
	for child in hand_panel.get_children():
		child.queue_free()
	card_buttons.clear()
	hand_panel.add_theme_constant_override("separation", 16)
	for i in range(HAND_SIZE):
		var btn := TextureButton.new()
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.custom_minimum_size = Vector2(90, 90)
		btn.pivot_offset = btn.custom_minimum_size / 2 
		btn.pressed.connect(_on_card_pressed.bind(i))
		hand_panel.add_child(btn)
		card_buttons.append(btn)
	update_hand_ui()


func update_hand_ui():
	for i in range(card_buttons.size()):
		var btn = card_buttons[i]
		btn.texture_normal = coral_textures[hand[i]]
		var is_selected = (i == selected_index)
		var target_scale = Vector2(1.2, 1.2) if is_selected else Vector2(0.9, 0.9)
		var target_color = Color.WHITE if is_selected else Color(0.5, 0.5, 0.5)
		var tween = create_tween().set_parallel(true)
		tween.tween_property(btn, "scale", target_scale, 0.15) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(btn, "modulate", target_color, 0.15)
		
		
func count_empty_tiles() -> int:
	return total_growable - coral_grid.size() - pollution_grid.size()

func setup_warning_label():
	warning_label = Label.new()
	warning_label.text = "look carefully for empty spaces on the reef — including ones on the rocks."
	warning_label.add_theme_font_override("font", load("res://fonts/garet-book.ttf"))
	warning_label.add_theme_font_size_override("font_size", 20)
	warning_label.add_theme_color_override("font_color", Color.WHITE)

	var box = StyleBoxFlat.new()
	box.bg_color = Color(0.85, 0.85, 0.85)  
	box.set_corner_radius_all(12)
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	warning_label.add_theme_stylebox_override("normal", box)
	warning_label.add_theme_color_override("font_color", Color("#24183d")) 

	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning_label.mouse_filter = Control.MOUSE_FILTER_IGNORE   # don't swallow clicks
	warning_label.z_index = 200

	# sit it in the bottom strip, centred between the toolbox and the bars
	var vp = get_viewport_rect().size
	var box_width = 480.0
	warning_label.size = Vector2(box_width, 80)
	warning_label.position = Vector2((vp.x - box_width) / 2.0, vp.y - 165)

	warning_label.visible = false
	add_child(warning_label)
	
func update_cursor_to_selection():
	current_coral = hand[selected_index]
	cursor_sprite.texture = coral_textures[current_coral]


func _on_card_pressed(index: int):
	selected_index = index
	update_cursor_to_selection()
	update_hand_ui()


func replace_selected_card():
	hand[selected_index] = coral_types.pick_random()
	update_cursor_to_selection()
	update_hand_ui()

func _process(_delta):
	cursor_sprite.position = get_global_mouse_position()
	if is_valid_placement(get_hovered_tile()):
		cursor_sprite.modulate = Color(1, 1, 1, 0.7)      
	else:
		cursor_sprite.modulate = Color(1, 0.4, 0.4, 0.6)  


func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		try_place_coral(get_hovered_tile())

func get_hovered_tile() -> Vector2i:
	var local = terrain_tilemap.to_local(get_global_mouse_position())
	return terrain_tilemap.local_to_map(local)


func is_valid_placement(coords: Vector2i) -> bool:
	if coords.x < 0 or coords.x >= WIDTH or coords.y < 0 or coords.y >= HEIGHT:
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
	just_placed = coords 
	end_turn()


func end_turn():
	spread_coral()
	reclaim_pollution()
	pollution_spread()
	turn_count += 1
	update_hud()
	if check_win_loss():
		return
	replace_selected_card()
	
	

func spread_coral():
	var sources = coral_grid.keys()
	var grew = 0
	for coords in sources:
		if coords == just_placed:
			continue   # the coral you just placed establishes first, spreads next turn
		if randf() > CORAL_SPREAD_CHANCE:
			continue   # this coral rests this turn
		var type = coral_grid[coords]["type"]
		var budget = get_spread_budget(coords, type)
		var dirs = DIAGONAL_DIRS if type == Coral.FAN else ORTHOGONAL_DIRS
		var targets := []
		for dir in dirs:
			if is_valid_placement(coords + dir):
				targets.append(coords + dir)
		targets.shuffle()
		for i in range(min(budget, targets.size())):
			place_coral(targets[i], type, grew * 0.04)
			grew += 1
	just_placed = null   # cleared so it spreads normally next turn
	if grew > 0:
		spawn_fish(2)
		
		
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

func place_coral(coords: Vector2i, type: int, delay: float = 0.0):
	var sprite = Sprite2D.new()
	var variants = coral_tile_variants[type]
	sprite.texture = variants.pick_random() if variants.size() > 0 else coral_textures[type]
	sprite.position = terrain_tilemap.map_to_local(coords)
	sprite.position += Vector2(randf_range(-20, 20), randf_range(-20, 20))
	sprite.rotation = randf_range(-0.4, 0.4)
	sprite.flip_h = randf() < 0.5
	var s = randf_range(1.05, 1.25)
	var final_scale = Vector2(s, s)
	sprite.scale = Vector2.ZERO          # start at nothing, then pop in
	terrain_tilemap.add_child(sprite)
	coral_grid[coords] = { "type": type, "sprite": sprite, "health": CORAL_HEALTH[type] }

	var tween = sprite.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)       # wait its turn in the ripple
	tween.tween_property(sprite, "scale", final_scale, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
		
	
func spawn_pollution(count: int):
	var placed = 0
	var attempts = 0
	while placed < count and attempts < 1000:
		attempts += 1
		var c = Vector2i(randi() % WIDTH, randi() % HEIGHT)
		if pollution_grid.has(c):
			continue
		pollute_tile(c)
		placed += 1


func pollution_spread():
	var before = pollution_grid.size()
	for step in range(POLLUTION_RATE):
		advance_pollution()
	if pollution_grid.size() > before:
		spawn_pollution_clouds(1)
		
func count_coral_neighbours(coords: Vector2i) -> int:
	var count = 0
	for dir in ORTHOGONAL_DIRS:
		if coral_grid.has(coords + dir):
			count += 1
	return count

func advance_pollution():
	var sources = pollution_grid.keys()
	var spread_count = 0
	for coords in sources:
		var choked = randf() < count_coral_neighbours(coords) * CORAL_SUPPRESSION
		var spreads = (not choked) and randf() < POLLUTION_SPREAD_CHANCE
		for dir in ORTHOGONAL_DIRS:
			var n = coords + dir
			if not can_pollute(n):
				continue
			if coral_grid.has(n):
				damage_coral(n)        # still gnaws at adjacent coral every turn
			elif spreads:
				pollute_tile(n, spread_count * 0.06)
				spread_count += 1
				
				
func can_pollute(coords: Vector2i) -> bool:
	if coords.x < 0 or coords.x >= WIDTH or coords.y < 0 or coords.y >= HEIGHT:
		return false
	if pollution_grid.has(coords):
		return false
	return true
	
	
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
	pollute_tile(coords)  


func pollute_tile(coords: Vector2i, delay: float = 0.0):
	var sprite = Sprite2D.new()
	sprite.texture = pollution_textures.pick_random()
	sprite.position = terrain_tilemap.map_to_local(coords)
	sprite.position += Vector2(randf_range(-25, 25), randf_range(-25, 25))
	sprite.rotation = randf() * TAU
	var s = randf_range(1.1, 1.35)
	var final_scale = Vector2(s, s)
	sprite.z_index = 1
	sprite.scale = Vector2.ZERO          # creep out from nothing
	sprite.modulate.a = 0.0              # and seep in from transparent
	terrain_tilemap.add_child(sprite)
	pollution_grid[coords] = { "sprite": sprite }

	var tween = sprite.create_tween().set_parallel(true)
	tween.tween_property(sprite, "scale", final_scale, 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(delay)
	tween.tween_property(sprite, "modulate:a", 0.9, 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(delay)
		
func count_growable():
	total_growable = WIDTH * HEIGHT

func get_coral_coverage() -> float:
	if total_growable == 0:
		return 0.0
	return float(coral_grid.size()) / total_growable


func get_pollution_coverage() -> float:
	if total_growable == 0:
		return 0.0
	return float(pollution_grid.size()) / total_growable


func board_is_full() -> bool:
	return coral_grid.size() + pollution_grid.size() >= total_growable


func check_win_loss() -> bool:
	if get_coral_coverage() >= 0.70:
		win()
		return true
	if get_pollution_coverage() >= 0.70:
		lose()
		return true

	# Few tiles left and coral is in the lead — call it rather than making
	# the player hunt down the last empty squares.
	if count_empty_tiles() <= LOW_TILES_WARNING and get_coral_coverage() > get_pollution_coverage():
		win()
		return true

	# Board completely full but neither hit 70% — decide by who covers more
	if board_is_full():
		if get_coral_coverage() >= get_pollution_coverage():
			win()
		else:
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
		
func get_status_message() -> String:
	var c = get_coral_coverage()
	var p = get_pollution_coverage()
	var key := ""
	if count_empty_tiles() <= LOW_TILES_WARNING:
		key = "warn"
	elif c >= 0.6:
		key = "winning_big"
	elif p >= 0.6:
		key = "danger"
	elif p > c + 0.1:
		key = "losing"
	elif c > p + 0.1:
		key = "winning"
	elif c + p < 0.08:
		key = "start"
	else:
		key = "close"
	if key != current_status_key:
		current_status_key = key
		current_status_text = STATUS_MESSAGES[key].pick_random()
	return current_status_text

func update_hud():
	race_bar.set_values(get_coral_coverage(), get_pollution_coverage())
	if warning_label:
		warning_label.text = get_status_message()
		warning_label.visible = true

var instructions_overlay: Control = null

func _on_info_button_pressed() -> void:
	if is_instance_valid(instructions_overlay):
		return
	get_tree().paused = true
	instructions_overlay = preload("res://scenes/screens/instructions_screen.tscn").instantiate()
	instructions_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	instructions_overlay.z_index = 1000      
	add_child(instructions_overlay)
	
	
func spawn_fish(count: int = 2):
	if fish_texture == null:
		return
	var viewport = get_viewport_rect().size
	for i in range(count):
		var fish = Sprite2D.new()
		fish.texture = fish_texture
		fish.z_index = 50
		var fish_scale = randf_range(0.2, 0.45)
		fish.scale = Vector2(fish_scale, fish_scale)
		fish.modulate.a = lerp(0.6, 1.0, fish_scale / 0.45)  
		add_child(fish)

		var going_right = randf() < 0.5
		var y = randf_range(viewport.y * 0.15, viewport.y * 0.85)
		fish.position = Vector2((-200.0) if going_right else (viewport.x + 200.0), y)
		fish.flip_h = going_right     
		var end_x = (viewport.x + 200.0) if going_right else (-200.0)

		var swim = fish.create_tween()
		var duration = lerp(8.0, 4.5, fish_scale / 0.45)   # bigger = faster
		swim.tween_property(fish, "position:x", end_x, duration)
		swim.tween_callback(fish.queue_free)

		var bob = fish.create_tween().set_loops()
		bob.tween_property(fish, "position:y", y - 15, 1.0).set_trans(Tween.TRANS_SINE)
		bob.tween_property(fish, "position:y", y + 15, 1.0).set_trans(Tween.TRANS_SINE)


func spawn_pollution_clouds(count: int = 1):
	if pollution_cloud_texture == null:
		return
	var viewport = get_viewport_rect().size
	for i in range(count):
		var cloud = Sprite2D.new()
		cloud.texture = pollution_cloud_texture
		cloud.z_index = 40
		cloud.scale = Vector2(0.5, 0.5)           
		cloud.modulate = Color(1, 1, 1, 0.55)  
		add_child(cloud)

		var y = randf_range(viewport.y * 0.1, viewport.y * 0.6)
		cloud.position = Vector2(-250, y)

		var drift = cloud.create_tween()
		drift.tween_property(cloud, "position:x", viewport.x + 250, randf_range(9.0, 13.0))
		drift.tween_callback(cloud.queue_free)
		
		
func reclaim_pollution():
	# Decide all reclaims against the current board, THEN apply them, so a tile
	# reclaimed this turn doesn't chain-reclaim its neighbours in the same turn.
	var to_reclaim := []
	for coords in pollution_grid.keys():
		if count_coral_neighbours(coords) >= RECLAIM_NEIGHBOURS and randf() < RECLAIM_CHANCE:
			to_reclaim.append(coords)
	for coords in to_reclaim:
		reclaim_tile(coords)
	if to_reclaim.size() > 0:
		spawn_fish(1)  


func reclaim_tile(coords: Vector2i):
	pollution_grid[coords]["sprite"].queue_free()
	pollution_grid.erase(coords)
	# heal it over with coral, taking the type of an adjacent coral
	place_coral(coords, get_a_coral_neighbour_type(coords))


func get_a_coral_neighbour_type(coords: Vector2i) -> int:
	for dir in ORTHOGONAL_DIRS:
		if coral_grid.has(coords + dir):
			return coral_grid[coords + dir]["type"]
	return Coral.BRANCHING
