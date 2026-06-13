extends Control

# 0.0 = empty, 1.0 = reached the 70% finish (the centre line)
var coral_target := 0.0
var pollution_target := 0.0
var coral_shown := 0.0
var pollution_shown := 0.0

const CORAL_COLOR := Color(0.95, 0.55, 0.4)      # warm coral
const POLLUTION_COLOR := Color(0.45, 0.55, 0.5)  # murky
const BG_COLOR := Color(0.1, 0.12, 0.15)
const LINE_COLOR := Color(1, 1, 1, 0.85)

func set_values(coral_coverage: float, pollution_coverage: float):
	# coverage is 0..1; the finish is 0.70, so normalise to 0..1 of the race
	coral_target = clamp(coral_coverage / 0.70, 0.0, 1.0)
	pollution_target = clamp(pollution_coverage / 0.70, 0.0, 1.0)

func _process(delta):
	var moved = false
	if coral_shown != coral_target:
		coral_shown = move_toward(coral_shown, coral_target, delta * 0.6)
		moved = true
	if pollution_shown != pollution_target:
		pollution_shown = move_toward(pollution_shown, pollution_target, delta * 0.6)
		moved = true
	if moved:
		queue_redraw()

func _draw():
	var w = size.x
	var h = size.y
	var half = w / 2.0

	draw_rect(Rect2(0, 0, w, h), BG_COLOR)                          # background
	draw_rect(Rect2(0, 0, half * coral_shown, h), CORAL_COLOR)      # coral from left

	var poll_w = half * pollution_shown
	draw_rect(Rect2(w - poll_w, 0, poll_w, h), POLLUTION_COLOR)     # pollution from right

	draw_line(Vector2(half, 0), Vector2(half, h), LINE_COLOR, 3.0)  # 70% finish line
