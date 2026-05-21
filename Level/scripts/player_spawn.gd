class_name PlayerSpawn extends Node2D

func _ready() -> void:
	visible = false
	await get_tree().process_frame
	
	if get_tree().get_first_node_in_group("Player"):
		return
	
	var player : Player = load("uid://b1s7a7jrfahes").instantiate()
	
	get_tree().root.add_child(player)
	player.global_position = self.global_position
