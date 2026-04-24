class_name PlayerStateRun extends PlayerState

func init() -> void:
	pass

func enter() -> void:
	pass

func process(_delta: float) -> PlayerState:
	if player.direction.x == 0:
		return idle
	return

func physics_process(_delta: float) -> PlayerState:
	player.velocity.x = player.direction.x * player.moveSpeed
	return nextState

func exit() -> void:
	pass

func handle_input(event) -> PlayerState:
	if event.is_action_pressed("Jump"):
		return jump
	return
