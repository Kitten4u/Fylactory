@tool
class_name LevelTransition extends Node2D

enum SIDE {LEFT, RIGHT, TOP, BOTTOM}

@export_range(2, 12, 1, "or_greater") var size : int = 2 :
	set(value):
		size = value
		apply_area_settings()
		
@export var location : SIDE = SIDE.LEFT : 
	set(value):
		location = value
		apply_area_settings()
		
@export_file("*.tscn") var targetScene : String = ""
@export var targetAreaName : String = "LevelTransition"

@onready var area : Area2D = $Area2D

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	apply_area_settings()
	SceneManager.newSceneReady.connect(_on_new_scene_ready)
	SceneManager.loadSceneFinished.connect(_on_load_scene_finished)

func get_offset(player : Node2D) -> Vector2:
	var offset := Vector2.ZERO
	var playerPosition := player.global_position
	
	if location == SIDE.LEFT or location == SIDE.RIGHT:
		offset.y = playerPosition.y - self.global_position.y
		if location == SIDE.LEFT:
			offset.x = -74
		else:
			offset.x = 74
	else:
		offset.x = playerPosition.x - self.global_position.x
		if location == SIDE.TOP:
			offset.y = -2
		else: 
			offset.y = 130
	
	return offset

func _on_player_entered(body : Node2D) -> void:
	SceneManager.transition_scene(targetScene, targetAreaName, get_offset(body), "Left")

func _on_new_scene_ready(targetName : String, offset : Vector2) -> void:
	if targetName == name:
		var player : Node = get_tree().get_first_node_in_group("Player")
		player.global_position = global_position + offset

func _on_load_scene_finished() -> void:
	area.monitoring = false
	area.body_entered.connect(_on_player_entered)
	await get_tree().physics_frame
	await get_tree().physics_frame
	area.monitoring = true

func apply_area_settings() -> void:
	area = get_node_or_null("Area2D")
	
	if not area:
		return
	
	if location == SIDE.LEFT or location == SIDE.RIGHT:
		area.scale.y = size
		if location == SIDE.LEFT:
			area.scale.x = -1
		else: 
			area.scale.x = 1
	else:
		area.scale.x = size
		if location == SIDE.TOP:
			area.scale.y = 1
		else:
			area.scale.y = -1
