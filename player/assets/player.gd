class_name Player extends CharacterBody2D

@export var gravity : float = 980
@export var moveSpeed : float = 200
@export var jumpHeight : float = 800
@export var health : float = 100

var direction : Vector2 = Vector2.RIGHT
var states : Array [PlayerState]
var currentState : PlayerState : 
	get : return states.front()
var previousState : PlayerState :
	get : return states[1]

func _ready() -> void:
	for state in %States.get_children():
		if state is PlayerState:
			states.append(state)
			state.player = self
	
	if states.size() == 0:
		return
	
	change_states(currentState)
	currentState.enter()
	$Label.text = currentState.name

func _process(delta: float) -> void:
	update_direction()
	change_states(currentState.process(delta))

func _physics_process(delta: float) -> void:
	velocity.y += gravity * delta
	change_states(currentState.physics_process(delta))
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	change_states(currentState.handle_input(event))

func change_states(newState: PlayerState) -> void:
	if newState == null or newState == currentState:
		return
	
	if currentState:
		currentState.exit()
	
	states.push_front(newState)
	currentState.enter()
	states.resize(2)
	$Label.text = currentState.name

func update_direction() -> void:
	var previousDirection = direction
	
	var xDirection = Input.get_axis("Left", "Right")
	
	direction = Vector2(xDirection, 0)
