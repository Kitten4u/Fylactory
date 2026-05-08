class_name MergePipe extends Area2D

const GIVES_UP := Vector2(0, 1)
const GIVES_RIGHT := Vector2(-1, 0)
const GIVES_DOWN := Vector2(0, -1)
const GIVES_LEFT := Vector2(1, 0)

const RECIEVES_UP := Vector2(1, 0)
const RECIEVES_RIGHT := Vector2(0, 1)
const RECIEVES_DOWN := Vector2(-1, 0)
const RECIEVES_LEFT := Vector2(0, -1)

const MERGES_UP := Vector2(-1, 0)
const MERGES_RIGHT := Vector2(0, -1)
const MERGES_DOWN := Vector2(1, 0)
const MERGES_LEFT := Vector2(0, 1)

static func get_merge_pipe_gives(building_rotation : int, flip : bool) -> Vector2:
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

static func get_merge_pipe_recieves(building_rotation : int, flip : bool) -> Vector2:
	if building_rotation == 0:
		if flip == false:
			return RECIEVES_UP
		else: 
			return RECIEVES_DOWN
	elif  building_rotation == 90 or building_rotation == -270:
		return RECIEVES_RIGHT
	elif building_rotation == 180 or building_rotation == -180:
		if flip == false:
			return RECIEVES_DOWN
		else:
			return RECIEVES_UP
	elif building_rotation == 270 or building_rotation == -90:
		return RECIEVES_LEFT
	else:
		return Vector2(100, 100)
	
static func get_merge_pipe_merges(building_rotation : int, flip : bool) -> Vector2:
	if building_rotation == 0:
		if flip == false:
			return MERGES_UP
		else: 
			return MERGES_DOWN
	elif  building_rotation == 90 or building_rotation == -270:
		return MERGES_RIGHT
	elif building_rotation == 180 or building_rotation == -180:
		if flip == false:
			return MERGES_DOWN
		else:
			return MERGES_UP
	elif building_rotation == 270 or building_rotation == -90:
		return MERGES_LEFT
	else:
		return Vector2(100, 100)
