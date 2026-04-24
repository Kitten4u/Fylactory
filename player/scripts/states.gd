class_name PlayerState extends Node

@onready var idle : PlayerStateIdle = %Idle
@onready var run : PlayerStateRun = %Run
@onready var fall : PlayerStateFall = %Fall
@onready var jump : PlayerStateJump = %Jump

var player : Player
var nextState : PlayerState

func init() -> void:
	pass

func enter() -> void:
	pass

func process(_delta: float) -> PlayerState:
	return

func physics_process(_delta: float) -> PlayerState:
	return nextState

func exit() -> void:
	pass

func handle_input(_event) -> PlayerState:
	return
