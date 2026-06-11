extends Control

@onready var terrain_tilemap = $TerrainTileMap

const DEEP_SEA_SOURCE = 0
const ROCK_SOURCE = 1
const SAND_SOURCE = 2

const WIDTH = 15
const HEIGHT = 15

func _ready():
	randomize()
	generate_terrain()
	fit_board_to_screen()

func generate_terrain():
	print("generating terrain, tileset is: ", terrain_tilemap.tile_set)
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
	var s = 80.0 / terrain_tilemap.tile_set.tile_size.x 
	terrain_tilemap.scale = Vector2(s, s)
