class_name PlayerStateFall extends PlayerState

func init() -> void:
	pass

func enter() -> void:
	pass

func process(_delta: float) -> PlayerState:
	if player.is_on_floor():
		return idle
		
	return

func physics_process(_delta: float) -> PlayerState:
	player.velocity.x = player.direction.x * player.moveSpeed
	return

func exit() -> void:
	pass

func handle_input(_event) -> PlayerState:
	return
