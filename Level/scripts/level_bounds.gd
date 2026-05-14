@tool
class_name LevelBounds extends Node2D

@export_range(480, 2200, 32, "suffix:px") var width = 480 : set = on_width_change
@export_range(270, 2200, 32, "suffix:px") var height = 270 : set = on_height_change

func _ready() -> void:
	z_index = 256
	
	if Engine.is_editor_hint():
		return
	
	var camera : Camera2D = null
	
	while not camera:
		await get_tree().process_frame
		camera = get_viewport().get_camera_2d()
		camera.limit_left = int(global_position.x)
		camera.limit_top = int(global_position.y)
		camera.limit_right = int(global_position.x) + width
		camera.limit_bottom = int(global_position.y) + height

func _draw() -> void:
	if Engine.is_editor_hint():
		var r : Rect2 = Rect2(Vector2.ZERO, Vector2(width, height))
		draw_rect(r, Color(0.0, 0.769, 0.784, 1.0), false, 3)

func on_width_change(newWidth : int) -> void:
	width = newWidth
	queue_redraw()

func on_height_change(newHeight : int) -> void:
	height = newHeight
	queue_redraw()
