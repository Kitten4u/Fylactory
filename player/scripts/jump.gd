class_name PlayerStateJump extends PlayerState

func init() -> void:
	pass

func enter() -> void:
	player.velocity.y = -player.jumpHeight

func process(_delta: float) -> PlayerState:
	if !player.is_on_floor() and player.velocity.y >= 0:
		return fall
		
	return

func physics_process(_delta: float) -> PlayerState:
	player.velocity.x = player.direction.x * player.moveSpeed
	return

func exit() -> void:
	pass

func handle_input(_event) -> PlayerState:
	return
