class_name HealthComponent extends Node

@onready var damageArea = %DamageArea

@export var maxHP : int
var currentHP : int

func _ready() -> void:
	damageArea.damageTaken.connect(take_damage)
	currentHP = maxHP

func take_damage(damage) -> void:
	currentHP -= damage
	print(currentHP)
	if currentHP <= 0:
		die()

func die() -> void:
	get_parent().queue_free()
