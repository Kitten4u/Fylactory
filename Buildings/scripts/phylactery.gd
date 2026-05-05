class_name Phylactery extends Area2D

const RECIEVES_UP := Vector2(0, -1)
const RECIEVES_RIGHT := Vector2(1, 0)
const RECIEVES_DOWN := Vector2(0, 1)
const RECIEVES_LEFT := Vector2(-1, 0)

static func get_phylactery_recieves(building_rotation : int) -> Vector2:
	if building_rotation >= 360:
		building_rotation -= 360
	elif building_rotation <= -360:
		building_rotation += 360
	
	if building_rotation == 0:
		return RECIEVES_UP
	elif  building_rotation == 90 or building_rotation == -270:
		return RECIEVES_RIGHT
	elif building_rotation == 180 or building_rotation == -180:
		return RECIEVES_DOWN
	elif building_rotation == 270 or building_rotation == -90:
		return RECIEVES_LEFT
	else:
		return Vector2(100, 100)
