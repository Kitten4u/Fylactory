class_name PipeExit extends Area2D

enum SIDE {LEFT, RIGHT, TOP, BOTTOM}
enum DIRECTION {INSIDE, OUTSIDE}

@export var side : SIDE = SIDE.LEFT
@export var connectingRoom : String
var flowDirection : DIRECTION
var elementArray : Dictionary[String, float]

func get_side() -> String:
	return SIDE.keys()[side]

func get_direction() -> String:
	return DIRECTION.keys()[flowDirection]
