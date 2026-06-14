extends Control

@export var corner_radius: int = 40

func _ready():
	clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	mouse_filter = Control.MOUSE_FILTER_IGNORE  
	
	
func _draw():
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.set_corner_radius_all(corner_radius)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
