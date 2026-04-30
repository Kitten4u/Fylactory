extends Node

var waterAmount : float = 0
var fireAmount : float = 0
var airAmount : float = 0
var earthAmount : float = 0

func _ready() -> void:
	pass

func get_total_water(amount : float):
	var player : Player = get_tree().get_first_node_in_group("Player")
	waterAmount = amount
	player.update_stats()

func get_total_air(amount : float):
	var player : Player = get_tree().get_first_node_in_group("Player")
	airAmount = amount
	player.update_stats()

func get_total_earth(amount : float):
	var player : Player = get_tree().get_first_node_in_group("Player")
	earthAmount = amount
	player.update_stats()

func get_total_fire(amount : float):
	var player : Player = get_tree().get_first_node_in_group("Player")
	fireAmount = amount
	player.update_stats()
