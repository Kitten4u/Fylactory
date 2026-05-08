class_name SplitPipe extends Area2D

const GIVES_UP := Vector2(1, 0)
const GIVES_RIGHT := Vector2(0, 1)
const GIVES_DOWN := Vector2(-1, 0)
const GIVES_LEFT := Vector2(0, -1)

const SPLITS_UP := Vector2(-1, 0)
const SPLITS_RIGHT := Vector2(0, -1)
const SPLITS_DOWN := Vector2(1, 0)
const SPLITS_LEFT := Vector2(0, 1)

const RECIEVES_UP := Vector2(0, -1)
const RECIEVES_RIGHT := Vector2(1, 0)
const RECIEVES_DOWN := Vector2(0, 1)
const RECIEVES_LEFT := Vector2(-1, 0)

static func get_split_pipe_gives(building_rotation : int, flip : bool) -> Vector2:
	if building_rotation == 0:
		if flip == false:
			return GIVES_UP
		else: 
			return GIVES_DOWN
	elif  building_rotation == 90 or building_rotation == -270:
		return GIVES_RIGHT
	elif building_rotation == 180 or building_rotation == -180:
		if flip == false:
			return GIVES_DOWN
		else: 
			return GIVES_UP
	elif building_rotation == 270 or building_rotation == -90:
		return GIVES_LEFT
	else:
		return Vector2(100, 100)

static func get_split_pipe_splits(building_rotation : int, flip : bool) -> Vector2:
	if building_rotation == 0:
		if flip == false:
			return SPLITS_UP
		else: 
			return SPLITS_DOWN
	elif  building_rotation == 90 or building_rotation == -270:
		return SPLITS_RIGHT
	elif building_rotation == 180 or building_rotation == -180:
		if flip == false:
			return SPLITS_DOWN
		else: 
			return SPLITS_UP
	elif building_rotation == 270 or building_rotation == -90:
		return SPLITS_LEFT
	else:
		return Vector2(100, 100)

static func get_split_pipe_recieves(building_rotation : int, flip : bool) -> Vector2:
	if building_rotation == 0:
		return RECIEVES_UP
	elif  building_rotation == 90 or building_rotation == -270:
		if flip == false:
			return RECIEVES_RIGHT
		else:
			return RECIEVES_LEFT
	elif building_rotation == 180 or building_rotation == -180:
		return RECIEVES_DOWN
	elif building_rotation == 270 or building_rotation == -90:
		if flip == false:
			return RECIEVES_LEFT
		else:
			return RECIEVES_RIGHT
	else:
		return Vector2(100, 100)
