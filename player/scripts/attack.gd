class_name PlayerStateAttack extends PlayerState

var exitTimer : float = 0

func init() -> void:
	%AttackSprite.visible = false

func enter() -> void:
	exitTimer = 0.5
	%AttackSprite.visible = true
	player.attackArea.activate(exitTimer)

func process(delta: float) -> PlayerState:
	exitTimer -= delta
	if exitTimer < 0:
		nextState = idle
	return nextState

func physics_process(_delta: float) -> PlayerState:
	player.velocity.x = player.direction.x * player.moveSpeed
	return

func exit() -> void:
	exitTimer = 0
	%AttackSprite.visible = false
	nextState = null

func handle_input(event) -> PlayerState:
	if event.is_action_pressed("attack_build") and FactoryGlobal.isGridOn == false:
		exitTimer = 0.5
	return
