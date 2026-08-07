class_name AttackArea extends Area2D

@export var damage : float = 1

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	monitorable = false
	monitoring = false

func _on_area_entered(area : Node2D) -> void:
	if area is DamageArea:
		area.take_damage(self)

func activate(duration : float = 0.1) -> void:
	monitoring = true
	await get_tree().create_timer(duration).timeout
	monitoring = false

func flip(direction : float) -> void:
	if direction > 0:
		scale.x = 1
	elif direction < 0:
		scale.x = -1
