class_name DamageArea extends Area2D

signal damageTaken(attackArea)

func take_damage(attackArea : AttackArea) -> void:
	print("Ouch")
	damageTaken.emit(attackArea)

func make_invulnerable(duration : float = 1.0) -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().create_timer(duration).timeout
	process_mode = Node.PROCESS_MODE_INHERIT
