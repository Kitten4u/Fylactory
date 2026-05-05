class_name Extractor extends Area2D

const GIVES_UP := Vector2(0, 1)
const GIVES_RIGHT := Vector2(-1, 0)
const GIVES_DOWN := Vector2(0, -1)
const GIVES_LEFT := Vector2(1, 0)

static func get_extractor_gives(building_rotation : int, flip : bool) -> Vector2:
	if building_rotation == 0:
		return GIVES_UP
	elif  building_rotation == 90 or building_rotation == -270:
		if flip == false:
			return GIVES_RIGHT
		else:
			return GIVES_LEFT
	elif building_rotation == 180 or building_rotation == -180:
		return GIVES_DOWN
	elif building_rotation == 270 or building_rotation == -90:
		if flip == false:
			return GIVES_LEFT
		else: 
			return GIVES_RIGHT
	else:
		return Vector2(100, 100)
