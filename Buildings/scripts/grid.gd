extends Node2D

@onready var clickTimer := %ClickTimer

# Grid Information
@export var GRID_SIZE := Vector2(1000, 1000)
var CELL_AMOUNT : Vector2

# Building Information
var buildingArray = []
var sourceArray : Array[Source]

# Build Mode Information
var selectedBuilding = FactoryGlobal.normalPipe
var selectedBuildingIndex : int = 0
var buildingPreviewInstance
var pipeInfo : Dictionary
var buildingRotation : int = 0
var flip : bool = false
var justBuiltBuildingUnderground : bool = false
var undergroundLocation : String
var phylacteryLocation : Vector2

# Preview for Dragging Info
var preDragBuilding
var preDragBuildingIndex : int
var preDragBuildingRotation : int
var preDragBuildingFlip : bool
var dragging : bool = false
var isBuildingUnderground : bool = false
var previewDirection := Vector2.INF
var previewStart := Vector2.INF
var currentPreview := Vector2.INF
var previewEnd : Vector2
var reversePath : bool = false
var transformPipe : bool = false
var playerLocation : Vector2
var overlappingPipes : Array[Vector2] = []
var outsideBuildAreaPipes : Array[Vector2] = []

# Total Element Counters
# NOTE FOR ELEMENT ARRAYS
# 0 is water
# 1 is fire
# 2 is air
# 3 is earth
var waterAmount = 0
var fireAmount = 0
var airAmount = 0
var earthAmount = 0

func _ready() -> void:
	# calculate grid size
	CELL_AMOUNT = Vector2(GRID_SIZE.x / FactoryGlobal.CELL_SIZE.x, GRID_SIZE.y / FactoryGlobal.CELL_SIZE.y)
	
	# Add Buildings to the buildingArray
	buildingArray = FactoryGlobal.buildingArray
	
	# Create the building preview
	buildingPreviewInstance = selectedBuilding.instantiate()
	add_child(buildingPreviewInstance)
	buildingPreviewInstance.modulate.a = 0.7
	
	# Add Sources to sourceArray
	for source in %Sources.get_children():
		if source is Source:
			sourceArray.append(source)
	
	# Rebuild Factory
	if FactoryGlobal.activePipeLayout.has(get_parent().name):
		pipeInfo = FactoryGlobal.activePipeLayout[get_parent().name].duplicate(true)
		for pipe in FactoryGlobal.activePipeLayout[get_parent().name]:
			var buildingScene = null
			while not buildingScene:
				buildingScene = load(pipeInfo[pipe]["Scene"])
				await get_tree().process_frame
			
			var building = buildingScene.instantiate()
			%Buildings.add_child(building)
			building.position = Vector2(pipeInfo[pipe]["X"], pipeInfo[pipe]["Y"]) + FactoryGlobal.HALF_CELL_SIZE
			if pipeInfo[pipe]["Flip"] == true:
				building.scale.x = -1
			building.get_node("Sprite2D").rotate(deg_to_rad(pipeInfo[pipe]["Rotation"]))
			building.add_to_group("Buildings")
		recalculate_factory()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("build_mode"):
		enter_exit_build_mode()
	
	if %Grid.visible == true:
		if Input.is_action_just_released("attack_build"):
			dragging = false
			if selectedBuilding != FactoryGlobal.undergroundPipeStart:
				if clickTimer.get_time_left() > 0.0:
					previewStart = Vector2.INF
					currentPreview = Vector2.INF
					spawn_building(var_to_str(cursor_snap()))
				else:
					previewEnd = cursor_snap()
					
					if previewStart != previewEnd:
						handle_pipe_chain()
					else:
						spawn_building(var_to_str(previewStart))
						previewStart = Vector2.INF
						currentPreview = Vector2.INF
				
				selectedBuildingIndex = preDragBuildingIndex
				selectedBuilding = buildingArray[selectedBuildingIndex]
				flip = preDragBuildingFlip
				buildingRotation = preDragBuildingRotation
				select_building(selectedBuildingIndex)
			else:
				isBuildingUnderground = false
				spawn_building(var_to_str(previewStart))
				previewStart = Vector2.INF
			
		elif Input.is_action_just_pressed("attack_build"):
			if selectedBuilding != FactoryGlobal.undergroundPipeStart:
				previewEnd = Vector2.INF
				dragging = true
				clickTimer.start(0.05)
				preDragBuilding = selectedBuilding
				preDragBuildingIndex = selectedBuildingIndex
				preDragBuildingFlip = flip
				preDragBuildingRotation = buildingRotation
			
			else:
				isBuildingUnderground = true
				previewStart = cursor_snap()
		
		elif Input.is_action_just_pressed("select_building") and justBuiltBuildingUnderground == false:
			$BuildingWheel.global_position = get_global_mouse_position()
			$BuildingWheel.show()
		
		elif Input.is_action_just_released("select_building"):
			selectedBuildingIndex = $BuildingWheel.close()
			select_building(selectedBuildingIndex)
		
		elif Input.is_action_just_pressed("delete_building"):
			delete_building(var_to_str(cursor_snap()))
		
		elif Input.is_action_just_pressed("rotate_left"):
			rotate_building(-90)
		
		elif Input.is_action_just_pressed("rotate_right"):
			rotate_building(90)
		
		elif Input.is_action_just_pressed("flip_horizontal"):
			flip_building()
	
	if FactoryGlobal.player:
		playerLocation = FactoryGlobal.player.get_node("BuildArea").global_position
	
	if dragging == true:
		if buildingPreviewInstance:
			buildingPreviewInstance.queue_free()
		create_preview_path()
		
		if currentPreview != Vector2.INF and previewStart != Vector2.INF:
			overlappingPipes.clear()
			outsideBuildAreaPipes.clear()
			transformPipe = false
			
			var rectStart := Rect2(create_preview_path_start()).abs()
			var rectEnd := Rect2(create_preview_path_end()).abs()
			var pipeFacing : Vector2
			var pipeCorner : Vector2
			
			if playerLocation.distance_to(previewStart) > FactoryGlobal.buildAreaRadius:
				outsideBuildAreaPipes.append(previewStart)
				
				if currentPreview != previewStart:
					var coordCheck : Vector2 = previewStart
					var pointCheck : float
					var farthestPoint : float 
					var previewPlace : float = 0
					
					if abs(previewDirection.x) > abs(previewDirection.y):
						pointCheck = previewStart.x
						farthestPoint = currentPreview.x
						if currentPreview.x > previewStart.x:
							previewPlace = FactoryGlobal.CELL_SIZE.x
						else:
							previewPlace = -FactoryGlobal.CELL_SIZE.x
					else:
						pointCheck = previewStart.y
						farthestPoint = currentPreview.y
						if currentPreview.y > previewStart.y:
							previewPlace = FactoryGlobal.CELL_SIZE.y
						else:
							previewPlace = -FactoryGlobal.CELL_SIZE.y
							
					while is_inside_build_area(coordCheck) == false and pointCheck != farthestPoint:
						if abs(previewDirection.x) > abs(previewDirection.y):
							coordCheck = Vector2(previewStart.x + previewPlace, previewStart.y)
							outsideBuildAreaPipes.append(coordCheck)
						else: 
							coordCheck = Vector2(previewStart.x, previewStart.y + previewPlace)
							outsideBuildAreaPipes.append(coordCheck)
						
						if abs(previewDirection.x) > abs(previewDirection.y):
							if currentPreview.x > previewStart.x:
								pointCheck += FactoryGlobal.CELL_SIZE.x
								previewPlace += FactoryGlobal.CELL_SIZE.x
							else:
								pointCheck -= FactoryGlobal.CELL_SIZE.x
								previewPlace -= FactoryGlobal.CELL_SIZE.x
						else:
							if currentPreview.y > previewStart.y:
								pointCheck += FactoryGlobal.CELL_SIZE.y
								previewPlace += FactoryGlobal.CELL_SIZE.y
							else:
								pointCheck -= FactoryGlobal.CELL_SIZE.y
								previewPlace -= FactoryGlobal.CELL_SIZE.y
						
						if abs(previewDirection.x) > abs(previewDirection.y):
							if is_inside_build_area(Vector2(previewStart.x + previewPlace, previewStart.y)):
								break	
						else: 
							if is_inside_build_area(Vector2(previewStart.x, previewStart.y + previewPlace)):
								break
		
			if playerLocation.distance_to(currentPreview) > FactoryGlobal.buildAreaRadius:
				outsideBuildAreaPipes.append(currentPreview)
				
				if currentPreview != previewStart:
					var coordCheck : Vector2 = currentPreview
					var pointCheck : float
					var farthestPoint : float 
					var previewPlace : float = 0
					
					if abs(previewDirection.x) > abs(previewDirection.y):
						pointCheck = currentPreview.y
						farthestPoint = previewStart.y
						if currentPreview.y > previewStart.y:
							previewPlace = -FactoryGlobal.CELL_SIZE.y
						else:
							previewPlace = FactoryGlobal.CELL_SIZE.y
					else:
						pointCheck = currentPreview.x
						farthestPoint = previewStart.x
						if currentPreview.x > previewStart.x:
							previewPlace = -FactoryGlobal.CELL_SIZE.x
						else:
							previewPlace = FactoryGlobal.CELL_SIZE.x
							
					while is_inside_build_area(coordCheck) == false and pointCheck != farthestPoint:
						if abs(previewDirection.x) > abs(previewDirection.y):
							coordCheck = Vector2(currentPreview.x, currentPreview.y + previewPlace)
							outsideBuildAreaPipes.append(coordCheck)
						else: 
							coordCheck = Vector2(currentPreview.x + previewPlace, currentPreview.y)
							outsideBuildAreaPipes.append(coordCheck)
						
						if abs(previewDirection.x) > abs(previewDirection.y):
							if currentPreview.y > previewStart.y:
								pointCheck -= FactoryGlobal.CELL_SIZE.y
								previewPlace -= FactoryGlobal.CELL_SIZE.y
							else:
								pointCheck += FactoryGlobal.CELL_SIZE.y
								previewPlace += FactoryGlobal.CELL_SIZE.y
						else:
							if currentPreview.x > previewStart.x:
								pointCheck -= FactoryGlobal.CELL_SIZE.x
								previewPlace -= FactoryGlobal.CELL_SIZE.x
							else:
								pointCheck += FactoryGlobal.CELL_SIZE.x
								previewPlace += FactoryGlobal.CELL_SIZE.x
								
						if abs(previewDirection.x) > abs(previewDirection.y):
							if is_inside_build_area(Vector2(currentPreview.x, currentPreview.y + previewPlace)):
								break
						else: 
							if is_inside_build_area(Vector2(currentPreview.x + previewPlace, currentPreview.y)):
								break
			
			if abs(previewDirection.x) > abs(previewDirection.y):
				pipeFacing = previewStart.direction_to(Vector2(currentPreview.x, previewStart.y))
				pipeCorner = Vector2(currentPreview.x, previewStart.y)
			else: 
				pipeFacing = previewStart.direction_to(Vector2(previewStart.x, currentPreview.y))
				pipeCorner = Vector2(previewStart.x, currentPreview.y)
			
			if pipeInfo.has(var_to_str(previewStart)):
				if pipeInfo[var_to_str(previewStart)]["Name"] == "Turn Pipe" \
				and previewStart != currentPreview \
				and Vector2(previewStart).direction_to(str_to_var(pipeInfo[var_to_str(previewStart)]["Gives"])) == pipeFacing * -1:
					transformPipe = true
						
				elif previewStart != currentPreview:
					if Vector2(previewStart).direction_to(str_to_var(pipeInfo[var_to_str(previewStart)]["Recieves"])) == pipeFacing \
					or Vector2(previewStart).direction_to(str_to_var(pipeInfo[var_to_str(previewStart)]["Merge Recieves"])) == pipeFacing:
						transformPipe = true
			
			for pipe in pipeInfo:
				if rectStart.has_point(Vector2(pipeInfo[pipe]["X"], pipeInfo[pipe]["Y"])) \
				or rectEnd.has_point(Vector2(pipeInfo[pipe]["X"], pipeInfo[pipe]["Y"])) \
				or Vector2(pipeInfo[pipe]["X"], pipeInfo[pipe]["Y"]) == currentPreview \
				or (Vector2(pipeInfo[pipe]["X"], pipeInfo[pipe]["Y"]) == previewStart and transformPipe == false) \
				or Vector2(pipeInfo[pipe]["X"], pipeInfo[pipe]["Y"]) == pipeCorner:
					overlappingPipes.append(Vector2(pipeInfo[pipe]["X"], pipeInfo[pipe]["Y"]))
	
	elif isBuildingUnderground == true:
		if buildingPreviewInstance:
			buildingPreviewInstance.queue_free()
	
	if buildingPreviewInstance:
		buildingPreviewInstance.position = cursor_snap() + FactoryGlobal.HALF_CELL_SIZE
	
	queue_redraw()

func _draw() -> void:
	for i in CELL_AMOUNT.x:
		var lineTop := Vector2(i * FactoryGlobal.CELL_SIZE.x, 0)
		var lineBottom := Vector2(i * FactoryGlobal.CELL_SIZE.x, GRID_SIZE.y)
		draw_line(lineTop, lineBottom, FactoryGlobal.GRID_LINE_COLOR)
	
	for i in CELL_AMOUNT.y:
		var lineLeft := Vector2(0, FactoryGlobal.CELL_SIZE.y * i)
		var lineRight := Vector2(GRID_SIZE.x, lineLeft.y)
		draw_line(lineLeft, lineRight, FactoryGlobal.GRID_LINE_COLOR)
	
	draw_rect(highlight_cell(), FactoryGlobal.GRID_HIGHLIGHT_COLOR)
	
	if dragging == true:
		draw_rect(create_preview_path_start(), FactoryGlobal.GRID_DRAG_COLOR)
		draw_rect(Rect2(previewStart, FactoryGlobal.CELL_SIZE), FactoryGlobal.GRID_DRAG_COLOR)
		draw_rect(create_preview_path_end(), FactoryGlobal.GRID_DRAG_COLOR)
		draw_rect(Rect2(currentPreview, FactoryGlobal.CELL_SIZE), FactoryGlobal.GRID_DRAG_COLOR)
		if abs(previewDirection.x) > abs(previewDirection.y):
			draw_rect(Rect2(currentPreview.x, previewStart.y, FactoryGlobal.CELL_SIZE.x, FactoryGlobal.CELL_SIZE.y), FactoryGlobal.GRID_DRAG_COLOR)
		else:
			draw_rect(Rect2(previewStart.x, currentPreview.y, FactoryGlobal.CELL_SIZE.x, FactoryGlobal.CELL_SIZE.y), FactoryGlobal.GRID_DRAG_COLOR)
		
		if overlappingPipes != []:
			for index in overlappingPipes.size():
				draw_rect(Rect2(overlappingPipes[index], FactoryGlobal.CELL_SIZE), FactoryGlobal.GRID_ERROR_COLOR)
		
		if outsideBuildAreaPipes != []:
			for index in outsideBuildAreaPipes.size():
				draw_rect(Rect2(outsideBuildAreaPipes[index], FactoryGlobal.CELL_SIZE), FactoryGlobal.GRID_ERROR_COLOR)
		
		if transformPipe == true:
			draw_rect(Rect2(previewStart, FactoryGlobal.CELL_SIZE), FactoryGlobal.GRID_TRANSFORM_COLOR)
	
	elif isBuildingUnderground == true:
		draw_rect(Rect2(previewStart, FactoryGlobal.CELL_SIZE), FactoryGlobal.GRID_DRAG_COLOR)

func highlight_cell() -> Rect2:
	return Rect2(cursor_snap(), FactoryGlobal.CELL_SIZE)

func enter_exit_build_mode() -> void:
	if %Grid.visible == false:
		%Buildings.self_modulate.a = 1
		%Grid.show()
	else:
		%Buildings.self_modulate.a = FactoryGlobal.factoryOpacity
		%Grid.hide()

func handle_pipe_chain() -> void:
	var previewPipesStart : Array[String] = create_dragged_pipes_start()
	var previewPipesEnd : Array[String] = create_dragged_pipes_end()
	var pipeFacing : Vector2
	
	if abs(previewDirection.x) > abs(previewDirection.y):
		pipeFacing = previewStart.direction_to(Vector2(currentPreview.x, previewStart.y))
	else: 
		pipeFacing = previewStart.direction_to(Vector2(previewStart.x, currentPreview.y))
	
	for pipe in previewPipesStart:
		if previewPipesStart[0] == pipe:
			if pipeInfo.has(pipe):
				if pipeInfo[pipe]["Name"] == "Turn Pipe":
					if Vector2(pipeInfo[pipe]["X"], pipeInfo[pipe]["Y"]).direction_to(str_to_var(pipeInfo[pipe]["Recieves"])) == pipeFacing:
							reversePath = true
					
					elif Vector2(pipeInfo[pipe]["X"], pipeInfo[pipe]["Y"]).direction_to(str_to_var(pipeInfo[pipe]["Gives"])) == pipeFacing * -1:
						selectedBuilding = FactoryGlobal.splitPipe
						buildingRotation = pipeInfo[pipe]["Rotation"]
						flip = pipeInfo[pipe]["Flip"]
						delete_building(pipe)
				
				elif Vector2(pipeInfo[pipe]["X"], pipeInfo[pipe]["Y"]).direction_to(str_to_var(pipeInfo[pipe]["Recieves"])) == pipeFacing \
				or Vector2(pipeInfo[pipe]["X"], pipeInfo[pipe]["Y"]).direction_to(str_to_var(pipeInfo[pipe]["Merge Recieves"])) == pipeFacing:
					reversePath = true
			
			else:
				handle_first_pipe_special_cases()
		
		elif previewPipesStart[-1] == pipe and previewPipesEnd != []:
			selectedBuilding = FactoryGlobal.turnPipe
			rotate_drgged_turn_pipes()
	
		else:
			selectedBuilding = FactoryGlobal.normalPipe
			selectedBuildingIndex = 0
			
			flip = false
			rotate_dragged_straight_pipes()
		
		spawn_building(pipe)
	
	selectedBuilding = FactoryGlobal.normalPipe
	selectedBuildingIndex = 0
	flip = false
	if reversePath == false:
		if abs(previewDirection.x) > abs(previewDirection.y):
			if previewEnd.y > previewStart.y:
				buildingRotation = 0
			else: 
				buildingRotation = 180
		else:
			if currentPreview.x > previewStart.x:
				buildingRotation = 270
			else: 
				buildingRotation = 90
	else:
		if abs(previewDirection.x) > abs(previewDirection.y):
			if previewEnd.y > previewStart.y:
				buildingRotation = 180
			else: 
				buildingRotation = 0
		else:
			if currentPreview.x > previewStart.x:
				buildingRotation = 90
			else: 
				buildingRotation = 270
	
	for pipe in previewPipesEnd:
		spawn_building(pipe)
	
	previewStart = Vector2.INF
	currentPreview = Vector2.INF
	reversePath = false
	transformPipe = false
	overlappingPipes.clear()
	outsideBuildAreaPipes.clear()

func rotate_dragged_straight_pipes() -> void:
	if reversePath == false:
		if abs(previewDirection.x) > abs(previewDirection.y):
			if previewEnd.x > previewStart.x:
				buildingRotation = 270
			else:
				buildingRotation = 90
		else:
			if previewEnd.y > previewStart.y:
				buildingRotation = 0
			else: 
				buildingRotation = 180
	else:
		if abs(previewDirection.x) > abs(previewDirection.y):
			if previewEnd.x > previewStart.x:
				buildingRotation = 90
			else:
				buildingRotation = 270
		else:
			if previewEnd.y > previewStart.y:
				buildingRotation = 180
			else: 
				buildingRotation = 0

func rotate_drgged_turn_pipes() -> void:
	if reversePath == false:
		if abs(previewDirection.x) > abs(previewDirection.y):
			if previewEnd.x > previewStart.x:
				if previewEnd.y > previewStart.y:
					buildingRotation = 90
					flip = true
				else:
					buildingRotation = 270
					flip = false
			else:
				if previewEnd.y > previewStart.y:
					buildingRotation = 90
					flip = false
				else:
					buildingRotation = 270
					flip = true
		else:
			if previewEnd.y > previewStart.y:
				if previewEnd.x > previewStart.x:
					buildingRotation = 0
					flip = false
				else: 
					buildingRotation = 0
					flip = true
			else: 
				if previewEnd.x > previewStart.x:
					buildingRotation = 180
					flip = true
				else:
					buildingRotation = 180
					flip = false
	else:
		if abs(previewDirection.x) > abs(previewDirection.y):
			if previewEnd.x > previewStart.x:
				if previewEnd.y > previewStart.y:
					buildingRotation = 180
					flip = false
				else:
					buildingRotation = 0
					flip = true
			else:
				if previewEnd.y > previewStart.y:
					buildingRotation = 180
					flip = true
				else:
					buildingRotation = 0
					flip = false
		else:
			if previewEnd.y > previewStart.y:
				if previewEnd.x > previewStart.x:
					buildingRotation = 270
					flip = true
				else: 
					buildingRotation = 270
					flip = false
			else: 
				if previewEnd.x > previewStart.x:
					buildingRotation = 90
					flip = false
				else:
					buildingRotation = 90
					flip = true

func handle_first_pipe_special_cases() -> void:
	selectedBuilding = preDragBuilding
	flip = preDragBuildingFlip
				
	if selectedBuilding == FactoryGlobal.splitPipe:
		buildingRotation = preDragBuildingRotation
					
	elif selectedBuilding == FactoryGlobal.turnPipe:
		buildingRotation = preDragBuildingRotation
		flip = false
		if abs(previewDirection.x) > abs(previewDirection.y):
			if previewEnd.x > previewStart.x:
				buildingRotation = 0
				if pipeInfo.has(var_to_str(Vector2(previewStart.x, previewStart.y + FactoryGlobal.CELL_SIZE.y))):
					if pipeInfo[var_to_str(Vector2(previewStart.x, previewStart.y + FactoryGlobal.CELL_SIZE.y))]["Gives"] == var_to_str(previewStart) \
					or pipeInfo[var_to_str(Vector2(previewStart.x, previewStart.y + FactoryGlobal.CELL_SIZE.y))]["Split Gives"] == var_to_str(previewStart):
						flip = true
						buildingRotation = 180
			else:
				buildingRotation = 180
				if pipeInfo.has(var_to_str(Vector2(previewStart.x, previewStart.y - FactoryGlobal.CELL_SIZE.y))):
					if pipeInfo[var_to_str(Vector2(previewStart.x, previewStart.y - FactoryGlobal.CELL_SIZE.y))]["Gives"] == var_to_str(previewStart) \
					or pipeInfo[var_to_str(Vector2(previewStart.x, previewStart.y - FactoryGlobal.CELL_SIZE.y))]["Split Gives"] == var_to_str(previewStart):
						flip = true
						buildingRotation = 0
		else:
			if previewEnd.y > previewStart.y:
				buildingRotation = 90
				if pipeInfo.has(var_to_str(Vector2(previewStart.x - FactoryGlobal.CELL_SIZE.x, previewStart.y))):
					if pipeInfo[var_to_str(Vector2(previewStart.x - FactoryGlobal.CELL_SIZE.x, previewStart.y))]["Gives"] == var_to_str(previewStart) \
					or pipeInfo[var_to_str(Vector2(previewStart.x - FactoryGlobal.CELL_SIZE.x, previewStart.y))]["Split Gives"] == var_to_str(previewStart):
						flip = true
			else:
				buildingRotation = 270
				if pipeInfo.has(var_to_str(Vector2(previewStart.x + FactoryGlobal.CELL_SIZE.x, previewStart.y))):
					if pipeInfo[var_to_str(Vector2(previewStart.x + FactoryGlobal.CELL_SIZE.x, previewStart.y))]["Gives"] == var_to_str(previewStart) \
					or pipeInfo[var_to_str(Vector2(previewStart.x + FactoryGlobal.CELL_SIZE.x, previewStart.y))]["Split Gives"] == var_to_str(previewStart):
						flip = true
								
	else:
		rotate_dragged_straight_pipes()

func create_preview_path() -> void:
	if previewStart == Vector2.INF:
		previewStart = cursor_snap()
	
	elif previewDirection == Vector2.INF and cursor_snap().distance_to(previewStart) >= FactoryGlobal.CELL_SIZE.x:
		previewDirection = previewStart.direction_to(cursor_snap())
		currentPreview = cursor_snap()
	
	elif currentPreview != Vector2.INF and cursor_snap().distance_to(currentPreview) >= FactoryGlobal.CELL_SIZE.x:
		currentPreview = cursor_snap()
	
	elif cursor_snap() == previewStart and previewStart != Vector2.INF and previewDirection != Vector2.INF:
		previewDirection = Vector2.INF
		currentPreview = Vector2.INF


func create_preview_path_start() -> Rect2:
	if previewDirection == Vector2.INF:
		return Rect2(previewStart, FactoryGlobal.CELL_SIZE)
	else:
		if abs(previewDirection.x) > abs(previewDirection.y):
			return Rect2(previewStart.x, previewStart.y, currentPreview.x - previewStart.x, FactoryGlobal.CELL_SIZE.y)
		else:
			return Rect2(previewStart.x, previewStart.y, FactoryGlobal.CELL_SIZE.x, currentPreview.y - previewStart.y)

func create_preview_path_end() -> Rect2:
	if previewDirection == Vector2.INF:
		return Rect2(previewStart, FactoryGlobal.CELL_SIZE)
	else:
		if abs(previewDirection.x) > abs(previewDirection.y):
			return Rect2(cursor_snap().x, cursor_snap().y, FactoryGlobal.CELL_SIZE.x, previewStart.y - cursor_snap().y)
		else:
			return Rect2(currentPreview.x, currentPreview.y, previewStart.x - cursor_snap().x, FactoryGlobal.CELL_SIZE.y)
	
func create_dragged_pipes_start() -> Array[String]:
	var previewPipePath : Array[String] = []
	var previewCount : float
	var previewPlace : float
	
	previewPipePath.append(var_to_str(previewStart))
	
	if abs(previewDirection.x) > abs(previewDirection.y):
		if previewEnd.x > previewStart.x:
			previewPlace = FactoryGlobal.CELL_SIZE.x
		else:
			previewPlace = -FactoryGlobal.CELL_SIZE.x
		
		previewCount = abs(previewStart.x - previewEnd.x)
		
		while previewCount > 0:
			previewPipePath.append(var_to_str(Vector2(previewStart.x + previewPlace, previewStart.y)))
			previewCount -= FactoryGlobal.CELL_SIZE.x
			if previewEnd.x > previewStart.x:
				previewPlace += FactoryGlobal.CELL_SIZE.x
			else:
				previewPlace -= FactoryGlobal.CELL_SIZE.x
	
	else:
		if previewEnd.y > previewStart.y:
			previewPlace = FactoryGlobal.CELL_SIZE.x
		else:
			previewPlace = -FactoryGlobal.CELL_SIZE.x
		
		previewCount = abs(previewStart.y - previewEnd.y)
		
		while previewCount > 0:
			previewPipePath.append(var_to_str(Vector2(previewStart.x, previewStart.y + previewPlace)))
			previewCount -= FactoryGlobal.CELL_SIZE.y
			if previewEnd.y > previewStart.y:
				previewPlace += FactoryGlobal.CELL_SIZE.y
			else:
				previewPlace -= FactoryGlobal.CELL_SIZE.y
	
	return previewPipePath

func create_dragged_pipes_end() -> Array[String]:
	var previewPipePath : Array[String] = []
	var previewCount : float
	var previewPlace : float
	
	if abs(previewDirection.x) > abs(previewDirection.y):
		previewCount = abs(previewEnd.y - previewStart.y)
		
		if previewEnd.y > previewStart.y:
			previewPlace = FactoryGlobal.CELL_SIZE.y
		else:
			previewPlace = -FactoryGlobal.CELL_SIZE.y
		
		while previewCount > 0:
			previewPipePath.append(var_to_str(Vector2(currentPreview.x, previewStart.y + previewPlace)))
			previewCount -= FactoryGlobal.CELL_SIZE.y
			if previewEnd.y > previewStart.y:
				previewPlace += FactoryGlobal.CELL_SIZE.y
			else:
				previewPlace -= FactoryGlobal.CELL_SIZE.y
				
	else:
		previewCount = abs(previewEnd.x - previewStart.x)
		
		if previewEnd.x > previewStart.x:
			previewPlace = FactoryGlobal.CELL_SIZE.x
		else:
			previewPlace = -FactoryGlobal.CELL_SIZE.x
		
		while previewCount > 0:
			previewPipePath.append(var_to_str(Vector2(previewStart.x + previewPlace, currentPreview.y)))
			previewCount -= FactoryGlobal.CELL_SIZE.x
			if previewEnd.x > previewStart.x:
				previewPlace += FactoryGlobal.CELL_SIZE.x
			else:
				previewPlace -= FactoryGlobal.CELL_SIZE.x
	
	return previewPipePath

# Builds the building. Puts it on the grid and gives the game all the info it needs about the building.
func spawn_building(location : String) -> void:
	var trueLocation = str_to_var(location)
	
	if is_inside_build_area(trueLocation) == true:
	#if 1 == 1:
		# Check to see if there's a pipe at that location already
		if pipeInfo.has(location) == false:
			# Keeps track of whether or not building can be built on that tile
			var canBuild = false
				
			# Variables for pipe dictionary
			# Keeps track of all the info on placed pipes
				
			var buildingScene : String
				
			# Name of the building
			var nameBuilding : String
				
			# Where the pipes connect - which location feeds into this pipe?
			var recieves : String
				
			# Mergers have two locations for this, so they need an extra. 
			# For everyone else it's (-100, -100)
			var mergeRecieves : String = var_to_str(Vector2.INF)
				
			# Where the pipes connect - which location does this feed out to?
			var gives : String
				
			# Splitters feed out into two locations, so they need an extra one
			# For everyone else it's (-100, -100)
			var splitGives : String = var_to_str(Vector2.INF)
				
			# The list of resources that can run through the pipes
			# Defaults to an amount of 0 for everything but the things that pull the resource from the environment
			var sourceDictionary : Dictionary[String, float] = {"Water" : 0, "Fire" : 0, "Air" : 0, "Earth" : 0}
				
			# Each pipe has unique info, so check the type of pipe and populate the info accordingly
			# Some have unique circumstances where they can't be placed, so check that too
			# Each pipe has a script that says which direction it's facing. That's used to determine which tiles connect to it
			if selectedBuilding == FactoryGlobal.normalPipe:
				canBuild = true
				buildingScene = "uid://b5ljabl0gd3u5"
				nameBuilding = "Normal Pipe"
				var vectorRecieves = get_grid_coordinates(trueLocation) + NormalPipe.get_normal_pipe_recieves(buildingRotation, flip)
				recieves = var_to_str(get_grid_position(vectorRecieves))
				var vectorGives = get_grid_coordinates(trueLocation) + NormalPipe.get_normal_pipe_gives(buildingRotation, flip)
				gives = var_to_str(get_grid_position(vectorGives))
			
			elif selectedBuilding == FactoryGlobal.turnPipe:
				canBuild = true
				buildingScene = "uid://cqy8ue3p87kvi"
				nameBuilding = "Turn Pipe"
				var vectorRecieves = get_grid_coordinates(trueLocation) + TurnPipe.get_turn_pipe_recieves(buildingRotation, flip)
				recieves = var_to_str(get_grid_position(vectorRecieves))
				var vectorGives = get_grid_coordinates(trueLocation) + TurnPipe.get_turn_pipe_gives(buildingRotation, flip)
				gives = var_to_str(get_grid_position(vectorGives))
			
			elif selectedBuilding == FactoryGlobal.mergePipe:
				canBuild = true
				buildingScene = "uid://cvfg3ivtnqdxs"
				nameBuilding = "Merge Pipe"
				var vectorRecieves = get_grid_coordinates(trueLocation) + MergePipe.get_merge_pipe_recieves(buildingRotation, flip)
				recieves = var_to_str(get_grid_position(vectorRecieves))
				var vectorMergeRecieves = get_grid_coordinates(trueLocation) + MergePipe.get_merge_pipe_merges(buildingRotation, flip)
				mergeRecieves = var_to_str(get_grid_position(vectorMergeRecieves))
				var vectorGives = get_grid_coordinates(trueLocation) + MergePipe.get_merge_pipe_gives(buildingRotation, flip)
				gives = var_to_str(get_grid_position(vectorGives))
			
			elif selectedBuilding == FactoryGlobal.splitPipe:
				canBuild = true
				buildingScene = "uid://dcktntwmsputu"
				nameBuilding = "Split Pipe"
				var vectorRecieves = get_grid_coordinates(trueLocation) + SplitPipe.get_split_pipe_recieves(buildingRotation, flip)
				recieves = var_to_str(get_grid_position(vectorRecieves))
				var vectorGives = get_grid_coordinates(trueLocation) + SplitPipe.get_split_pipe_gives(buildingRotation, flip)
				gives = var_to_str(get_grid_position(vectorGives))
				var vectorSplitGives = get_grid_coordinates(trueLocation) + SplitPipe.get_split_pipe_splits(buildingRotation, flip)
				splitGives = var_to_str(get_grid_position(vectorSplitGives))
			
			# After an underground pipe is placed, the end point must be placed
			# The gives value is set once the end is placed
			if selectedBuilding == FactoryGlobal.undergroundPipeStart:
				canBuild = true
				buildingScene = "uid://u56j8q2q6t43"
				nameBuilding = "Underground Pipe Start"
				var vectorRecieves = get_grid_coordinates(trueLocation) + NormalPipe.get_normal_pipe_recieves(buildingRotation, flip)
				recieves = var_to_str(get_grid_position(vectorRecieves))
				undergroundLocation = location
				justBuiltBuildingUnderground = true
				
			# Sets it's recieves variable based on where the first underground was placed
			# Sets the first underground pipe's gives based on its own location
			if selectedBuilding == FactoryGlobal.undergroundPipeEnd:
				canBuild = true
				buildingScene = "uid://cxy7k3037vmg4"
				nameBuilding = "Underground Pipe End"
				recieves = undergroundLocation
				var vectorGives = get_grid_coordinates(trueLocation) + NormalPipe.get_normal_pipe_gives(buildingRotation, flip)
				gives = var_to_str(get_grid_position(vectorGives))
				pipeInfo[undergroundLocation]["Gives"] = location
			
			if selectedBuilding == FactoryGlobal.vaporizer:
				canBuild = true
				buildingScene = "uid://ct6w6os54d0fy"
				nameBuilding = "Vaporizer"
				var vectorRecieves = get_grid_coordinates(trueLocation) + NormalPipe.get_normal_pipe_recieves(buildingRotation, flip)
				recieves = var_to_str(get_grid_position(vectorRecieves))
				
			# Extractors can only be placed on resource tiles
			# The first check makes sure that it is overlapping it (a source)
			# Extractors are the only one to have an element value set on creation as well
			elif selectedBuilding == FactoryGlobal.extractor: 
				# Check where all the sources are
				for source in sourceArray:
					# Check to see if the buildingPreview overlaps with the source
					var sourceCoords := get_grid_coordinates(source.global_position)
					sourceCoords = get_grid_position(sourceCoords)
					
					if cursor_snap() == sourceCoords or previewStart == sourceCoords:
						canBuild = true
						buildingScene = "uid://dxqdm37qygx70"
						nameBuilding = "Extractor"
						var vectorGives = get_grid_coordinates(trueLocation) + Extractor.get_extractor_gives(buildingRotation, flip)
						gives = var_to_str(get_grid_position(vectorGives))
						recieves = var_to_str(Vector2.ZERO)
						var elementCounter = 0
						for type in source.type:
							sourceDictionary[type] = source.amount[elementCounter]
							elementCounter += 1
						
						break
				
			# Only one phylactery can be placed on each map/scene
			elif selectedBuilding == FactoryGlobal.phylactery:
				if pipeInfo.size() != 0:
					for item in pipeInfo:
						var valueArray = pipeInfo[item].values()
						if valueArray.has("Phylactery") == true:
							return
				
				canBuild = true
				buildingScene = "uid://rwrddigeppfh"
				nameBuilding = "Phylactery"
				var vectorRecieves = get_grid_coordinates(trueLocation) + Phylactery.get_phylactery_recieves(buildingRotation)
				recieves = var_to_str(get_grid_position(vectorRecieves))
				gives = var_to_str(Vector2.ZERO)
				
			# If the conditions for building are fulfilled, then build it
			if canBuild == true:
				var building = selectedBuilding.instantiate()
					
				# Populates the pipe dictionary
				# Name, name of the building
				# X, x location in pixels
				# Y, y location in pixels
				# Rotation, building rotation in increments of 90 degrees
				# Flip, whether or not the building had to be flipped horizontally
				# Recieves, which tile the pipe gets its resources from
				# Merge Recieves, for mergers, since they get resources from two locations
				# Gives, which tile the pipe sends its resource to
				# Splot Gives, for splitters since they send resources to two locations
				# Elements, the list of resources in the pipe, only extractors have this populated at the beginning
				pipeInfo[location] = {
					"Scene" : buildingScene,
					"Name" : nameBuilding, 
					"X" : trueLocation.x, 
					"Y" : trueLocation.y, 
					"Rotation" : buildingRotation, 
					"Flip" : flip, 
					"Recieves" : recieves, 
					"Merge Recieves" : mergeRecieves,
					"Gives" : gives,
					"Split Gives" : splitGives,
					"Elements" : sourceDictionary, 
				}
				# Places the visuals for the pipe and adds it to the Building Global Group
				%Buildings.add_child(building)
				building.position = trueLocation + FactoryGlobal.HALF_CELL_SIZE
				if flip == true:
					building.scale.x = -1
				building.get_node("Sprite2D").rotate(deg_to_rad(buildingRotation))
				building.add_to_group("Buildings")
					
				# Need to make sure the end point of an underground pipe is placed immediately after the start point
				if selectedBuilding == FactoryGlobal.undergroundPipeStart or selectedBuilding == FactoryGlobal.undergroundPipeEnd:
					select_building(0)
					justBuiltBuildingUnderground = false
					
				# Sends the dictionary to the Factory Global script
				FactoryGlobal.activePipeLayout[get_parent().name] = pipeInfo.duplicate(true)
					
				# Calculates the resources running through the factory
				recalculate_factory()

func delete_building(location : String) -> void:
	if pipeInfo.has(location) == true:
		for body in %Buildings.get_children():
			if body.global_position - FactoryGlobal.HALF_CELL_SIZE == str_to_var(location):
				pipeInfo.erase(location)
				body.queue_free()
				recalculate_factory()
				break

func select_building(index : int) -> void:
	if justBuiltBuildingUnderground == false:
		if selectedBuildingIndex != -1:
			selectedBuildingIndex = index
			selectedBuilding = buildingArray[selectedBuildingIndex]
		else: 
			selectedBuilding = null
	else:
		selectedBuilding = FactoryGlobal.undergroundPipeEnd
	
	# Delete old preview
	if buildingPreviewInstance:
		buildingPreviewInstance.queue_free()
	
	# Generate new preview
	if selectedBuilding:
		buildingPreviewInstance = selectedBuilding.instantiate()
		add_child(buildingPreviewInstance)
		if flip == true:
			buildingPreviewInstance.scale.x = -1
		buildingPreviewInstance.get_node("Sprite2D").rotate(deg_to_rad(buildingRotation))
		buildingPreviewInstance.modulate.a = 0.7

func rotate_building(direction : int) -> void:
	buildingRotation += direction
	if buildingRotation >= 360 or buildingRotation <= -360:
		buildingRotation = 0
	buildingPreviewInstance.get_node("Sprite2D").rotate(deg_to_rad(direction))

func flip_building() -> void:
	if flip == false:
		buildingPreviewInstance.scale.x = -1
	else:
		buildingPreviewInstance.scale.x = 1
	flip = !flip

func get_grid_position(cellPosition : Vector2) -> Vector2:
	return cellPosition * FactoryGlobal.CELL_SIZE

func get_grid_coordinates(gridPosition : Vector2) -> Vector2:
	return floor(gridPosition / FactoryGlobal.CELL_SIZE)

func cursor_snap() -> Vector2:
	var cursorPosition := Vector2(get_global_mouse_position().x, get_global_mouse_position().y)
	var cursorCoords := get_grid_coordinates(cursorPosition)
	return get_grid_position(cursorCoords)
	
func is_inside_build_area(trueLocation : Vector2) -> bool:
	if playerLocation.distance_to(trueLocation) <= FactoryGlobal.buildAreaRadius \
	or playerLocation.distance_to(Vector2(trueLocation.x + FactoryGlobal.CELL_SIZE.x, trueLocation.y)) <= FactoryGlobal.buildAreaRadius \
	or playerLocation.distance_to(Vector2(trueLocation.x + FactoryGlobal.CELL_SIZE.x, trueLocation.y + FactoryGlobal.CELL_SIZE.y)) <= FactoryGlobal.buildAreaRadius \
	or playerLocation.distance_to(Vector2(trueLocation.x, trueLocation.y + FactoryGlobal.CELL_SIZE.y)) <= FactoryGlobal.buildAreaRadius:
		return true
	else:
		return false

# Used to calculate how many resources are flowing through the pipes
# There are no throughput limits
# Any source connected to the phylactery is immediately counted. There's nothing based on time
# In other words, everything can be calculated immediately
func recalculate_factory():
	# Reset energy
	waterAmount = 0
	fireAmount = 0
	airAmount = 0
	earthAmount = 0
	
	# Every non-extractor pipe needs to have its resource amounts reset
	for pipe in pipeInfo:
		if pipeInfo[pipe]["Name"] != "Extractor":
			for element in pipeInfo[pipe]["Elements"]:
				pipeInfo[pipe]["Elements"][element] = 0
	
	# Goes through the entire pipe list to find all the extractors
	# Each path starts from the extractor
	# Each path is calculated separately. Mathmatically, this works out
	for item in pipeInfo:
		if pipeInfo[item]["Name"] == "Extractor":
			print("")
			print("")
			print("")
			print("")
			print("")
			print("")
			print("")
			print("")
			print("Start")
			print("**********************")
			phylacteryLocation = Vector2(-100, -100)
			
			# Sees if a path exists
			# If it does, get an array of pipes in the path
			# If it doesn't (returns empty array) do nothing
			var path = find_pipe_path(item, {}, item)
			print("Path")
			print(path)
			if path != {}:
				# If a path is found, calculate how many resources are going through the pipe path
				calculate_flow(path, pipeInfo[item]["Elements"])
				
				# If the path includes a phylactery, update the global variables for the values going into it
				if phylacteryLocation != Vector2(-100, -100):
					var phylacteryIndex = var_to_str(phylacteryLocation)
					waterAmount = pipeInfo[phylacteryIndex]["Elements"]["Water"]
					fireAmount = pipeInfo[phylacteryIndex]["Elements"]["Fire"]
					airAmount = pipeInfo[phylacteryIndex]["Elements"]["Air"]
					earthAmount = pipeInfo[phylacteryIndex]["Elements"]["Earth"]
	
	# Update the player's stats based on the resources going through the factory
	# The values are stored in a global class, which then updates the player
	FactoryGlobal.get_total_water(waterAmount)
	FactoryGlobal.get_total_fire(fireAmount)
	FactoryGlobal.get_total_air(airAmount)
	FactoryGlobal.get_total_earth(earthAmount)
	print("Water")
	print(waterAmount)

func find_pipe_path(item : String, pathDictionary : Dictionary[String, Dictionary], previousVertex : String) -> Dictionary[String, Dictionary]:
	var current = pipeInfo[item]
	var currentCoords : String = item
	var next : String = pipeInfo[item]["Gives"]
	var joiningPipes : Array[String] = []
	var pathFound : bool = false
	
	# If the end point is right next to a splitter, needs an extra check
	if is_endpoint(current["Name"]) == true:
		var connections : Array[String] = [currentCoords]
		
		if pathDictionary.has(previousVertex):
			connections = pathDictionary[previousVertex]["Connections"] + connections
			joiningPipes = pathDictionary[previousVertex]["Joining Pipes"] + joiningPipes
						
		pathDictionary[previousVertex] = {
			"Connections" : connections,
			"Joining Pipes" : joiningPipes,
			"Elements" : pipeInfo[previousVertex]["Elements"]
		}
					
		pathDictionary[currentCoords] = {
			"Connections" : [],
			"Joining Pipes" : [],
			"Elements" : pipeInfo[currentCoords]["Elements"]
		}
		joiningPipes.clear()
		pathFound = true
	
	while pathFound == false:
		for pipe in pipeInfo:
			
			pathFound = true
			
			if pipe == next:
				if is_endpoint(pipeInfo[pipe]["Name"]):
					var connections : Array[String] = [pipe]
					
					if pathDictionary.has(previousVertex):
						connections = pathDictionary[previousVertex]["Connections"] + connections
						joiningPipes = pathDictionary[previousVertex]["Joining Pipes"] + joiningPipes
						
					pathDictionary[previousVertex] = {
						"Connections" : connections,
						"Joining Pipes" : joiningPipes,
						"Elements" : pipeInfo[previousVertex]["Elements"]
					}
					
					pathDictionary[pipe] = {
						"Connections" : [],
						"Joining Pipes" : [],
						"Elements" : pipeInfo[pipe]["Elements"]
					}
					joiningPipes.clear()
					pathFound = true
					break
					
				if pipeInfo[pipe]["Recieves"] == currentCoords \
				or pipeInfo[pipe]["Merge Recieves"] == currentCoords:
					
					if pipeInfo[pipe]["Name"] == "Merge Pipe":
						var connections : Array[String] = [pipe]
							
						if pathDictionary.has(previousVertex):
							connections = pathDictionary[previousVertex]["Connections"] + connections
							joiningPipes = pathDictionary[previousVertex]["Joining Pipes"] + joiningPipes
						
						pathDictionary[previousVertex] = {
							"Connections" : connections,
							"Joining Pipes" : joiningPipes,
							"Elements" : pipeInfo[previousVertex]["Elements"]
						}
							
						joiningPipes.clear()
						previousVertex = pipe
						
						# In case of a pipe that loops around
						if pathDictionary.has(pipe):
							return {}
						
					elif pipeInfo[pipe]["Name"] == "Split Pipe":
						var connections : Array[String] = [pipe]
					
						if pathDictionary.has(previousVertex):
							connections = pathDictionary[previousVertex]["Connections"] + connections
							joiningPipes = pathDictionary[previousVertex]["Joining Pipes"] + joiningPipes
						
						pathDictionary[previousVertex] = {
							"Connections" : connections,
							"Joining Pipes" : joiningPipes,
							"Elements" : pipeInfo[previousVertex]["Elements"]
						}
						
						previousVertex = pipe
						joiningPipes.clear()
						
						if pipeInfo.has(pipeInfo[pipe]["Split Gives"]):
							var splitDictionary = find_pipe_path(pipeInfo[pipe]["Split Gives"], pathDictionary, previousVertex)
							pathDictionary.merge(splitDictionary)
					
					else: 
						if pipeInfo[pipe]["Name"] != "Extractor" \
						and is_endpoint(pipeInfo[pipe]["Name"]) == false:
							joiningPipes.append(pipe)
					
					current = pipeInfo[pipe]
					currentCoords = pipe
					next = current["Gives"]
					pathFound = false
					
					# Don't need to seach the rest of the array once we find the path
					break
	
	var reachedEnd : bool = false
	for pipe in pathDictionary:
		if is_endpoint(pipeInfo[pipe]["Name"]):
			reachedEnd = true
			
			if pipeInfo[pipe]["Name"] == "Phylactery":
				phylacteryLocation = Vector2(pipeInfo[pipe]["X"], pipeInfo[pipe]["Y"])
	
	if reachedEnd == true:
		return pathDictionary
	else:
		return {}

func calculate_flow(path : Dictionary[String, Dictionary], elements : Dictionary) -> void:
	var loopList : Array[String] = []
	var isLooping : bool = false
	
	for pipe in path:
		if path[pipe].has("Connections"):
			for connection in path[pipe]["Connections"]:
				path[connection]["Elements"] = path[pipe]["Elements"].duplicate()
				
		if pipeInfo[pipe]["Name"] == "Split Pipe":
			if path[pipe].has("Connections"):
				if is_splitter_balanced(path, pipe):
					for connection in path[pipe]["Connections"]:
						path[connection]["Split"] = true
	
		elif pipeInfo[pipe]["Name"] == "Merge Pipe":
			if path[pipe].has("Connections"):
				loopList =  check_for_pipe_loop(path, pipe, pipe)
				
				if loopList != []:
					isLooping = true
					for loop in loopList:
						path[loop]["Looping"] = elements
	
	for pipe in path:
		
		
		if path[pipe].has("Split"):
			for element in elements:
				path[pipe]["Elements"][element] = elements[element] / 2
		
		print(pipeInfo[pipe]["Name"])
		print(path[pipe])
		print("###########")
		
		print("~~~~~~~~~~~~~~~~~~~~")
		print(pipeInfo[pipe]["Name"])
		print(path[pipe])
		print("~~~~~~~~~~~~~~~~~~~~")
	for pipe in path:
		if pipeInfo[pipe]["Name"] != "Extractor":
			for element in elements:
				pipeInfo[pipe]["Elements"][element] += path[pipe]["Elements"][element]
		
		if path[pipe].has("Joining Pipes"):
			for edge in path[pipe]["Joining Pipes"]:
				for element in pipeInfo[pipe]["Elements"]:
					pipeInfo[edge]["Elements"][element] += pipeInfo[pipe]["Elements"][element]
	
		print("--------------------")
		print(pipeInfo[pipe])
		print("--------------------")

func is_splitter_balanced(path : Dictionary[String, Dictionary], startingPipe : String) -> bool:
	var connections = path[startingPipe]["Connections"]
	
	if connections.size() != 2:
		return false
	
	var firstConnection : Vector2 = connections[0]
	var secondConnection : Vector2 = connections[1]
	
	if does_path_exist(firstConnection, []) == true and does_path_exist(secondConnection, []) == true:
		return true
	else:
		return false

func check_for_pipe_loop(path : Dictionary[String, Dictionary], startingPipe : String, mergePipeCheck : String) -> Array[String]:
	var mergePath : Array[String] = []
	var check : String = startingPipe
	
	while true:
		if path[check].has("Connections"):
			if path[check]["Connections"].size() == 2:
				var splitMergeList : Array[String] = check_for_pipe_loop(path, path[check]["Connections"][0], mergePipeCheck)
				if splitMergeList != []:
					mergePath.append(check)
					mergePath.append_array(splitMergeList)
					return mergePath
				else: 
					mergePath.append(check)
					check = path[check]["Connections"][1]
			
			else:
				mergePath.append(check)
				check = path[check]["Connections"][0]
		else:
			return []
		
		if check == mergePipeCheck:
			return mergePath
	
	return []

func is_endpoint(pipeName : String) -> bool:
	if pipeName == "Phylactery" \
	or pipeName == "Vaporizer":
		return true
	else: 
		return false

func does_path_exist(item : Vector2, mergerList : Array[Vector2]) -> bool:
	# The current pipe being checked
	var current = pipeInfo[item]
	
	# x, y coordinates of the current pipe
	var currentCoords = item
	
	# The previous pipe being looked at - null on the first pass, gets updated every loop
	var previous = null
	
	# The pipe properties that need to be checked
	var check = pipeInfo[item]["Name"]
	var next = pipeInfo[item]["Gives"]
	
	# Need an extra check in case the end is right next to a splitter
	if is_endpoint(check) == true:
		return true
	
	# Check to see if you've gotten to the Phylactery
	while check != "Phylactery":
		# The current pipe gets added to the array every loop
		
		# Escape the loop if Phylactery is not found
		if previous == current:
			return false
		
		# Update previous to the current pipe. If current and previous are the same we've run out of pipes to look through
		previous = current
		
		# Loop through all the pipes until you've found an end point or the next pipe in the chain
		for pipe in pipeInfo:
			if pipe == next:
				if is_endpoint(pipeInfo[pipe]["Name"]):
					return true
				
				# The next pipe must actually recieve from the current pipe
				# No trying to be silly and feed pipes sideways!
				# Sets the things we need to check for the next loop to find the next pipe in the chain
				if pipeInfo[pipe]["Recieves"] == currentCoords \
				or pipeInfo[pipe]["Merge Recieves"] == currentCoords:
					check = pipeInfo[pipe]["Name"]
					next = pipeInfo[pipe]["Gives"]
					current = pipeInfo[pipe]
					currentCoords = pipe
					
					# If it's a merge pipe, make sure we haven't passed it before
					# Failure to do so results in infinite recursion and thus stack overflow
					# Basically, checking to make sure the pipes don't make a circle
					if check == "Merge Pipe":
						if mergerList.has(currentCoords):
							return false
						
						# If it's new, add it to the list just in case this one loops
						mergerList.append(currentCoords)
					
					# If the pipe is a split pipe, we need to check both sides
					# First, check the gives side. If you find something, great a path exists
					# If no end point exists on one path, try the other one
					elif check == "Split Pipe":
						if does_path_exist(pipe, mergerList) == true:
							return true
						else:
							next = pipeInfo[pipe]["Split Gives"]
					
					# Don't need to keep looping through the dictinary once we find the next one
					break
	
	return true

## Sees if a path to an end point can be found
## Right now, the only end points are the phylactery and vaporizer
## item is the location of the starting pipe
## mergerList is a list of Merge Pipes to check for looping pipes
## Returns an array of pipes connected to each other if an end point is found
## Returns an empty array if no end point is found
#func find_pipe_path(item : Vector2, mergerList : Array[Vector2]) -> Array[Vector2]:
	## The array of connected pipes. This is returned if a path is found
	#var pathArray : Array[Vector2] = []
	#
	## The current pipe being checked
	#var current = pipeInfo[item]
	#
	## x, y coordinates of the current pipe
	#var currentCoords = item
	#
	## The previous pipe being looked at - null on the first pass, gets updated every loop
	#var previous = null
	#
	## The pipe properties that need to be checked
	#var check = pipeInfo[item]["Name"]
	#var next = pipeInfo[item]["Gives"]
	#
	## Need an extra check in case the end is right next to a splitter
	#if check == "Phylactery" or check == "Vaporizer":
		#pathArray.append(currentCoords)
		#if check == "Phylactery":
			#phylacteryLocation = currentCoords
		#return pathArray
	#
	## Check to see if you've gotten to the Phylactery
	#while check != "Phylactery":
		## The current pipe gets added to the array every loop
		#pathArray.append(currentCoords)
		#
		## Escape the loop if Phylactery is not found
		#if previous == current:
			#return []
		#
		## Update previous to the current pipe. If current and previous are the same we've run out of pipes to look through
		#previous = current
		#
		## Loop through all the pipes until you've found an end point or the next pipe in the chain
		#for pipe in pipeInfo:
			#if pipe == next:
				#if pipeInfo[pipe]["Name"] == "Phylactery" or pipeInfo[pipe]["Name"] == "Vaporizer":
					#pathArray.append(pipe)
					#if pipeInfo[pipe]["Name"] == "Phylactery":
						#phylacteryLocation = pipe
					#
					#return pathArray
				#
				## The next pipe must actually recieve from the current pipe
				## No trying to be silly and feed pipes sideways!
				## Sets the things we need to check for the next loop to find the next pipe in the chain
				#if pipeInfo[pipe]["Recieves"] == currentCoords \
				#or pipeInfo[pipe]["Merge Recieves"] == currentCoords:
					#check = pipeInfo[pipe]["Name"]
					#next = pipeInfo[pipe]["Gives"]
					#current = pipeInfo[pipe]
					#currentCoords = pipe
					#
					## If it's a merge pipe, make sure we haven't passed it before
					## Failure to do so results in infinite recursion and thus stack overflow
					## Basically, checking to make sure the pipes don't make a circle
					#if check == "Merge Pipe":
						#if mergerList.has(currentCoords):
							#return []
						#
						## If it's new, add it to the list just in case this one loops
						#mergerList.append(currentCoords)
					#
					## If the pipe is a split pipe, we need to check both sides
					## First, check the gives side. If you find something, great a path exists
					## If no end point exists on one path, try the other one
					#elif check == "Split Pipe":
						#var splitPath : Array[Vector2] = find_pipe_path(pipe, mergerList)
						#if splitPath != []:
							#pathArray.append_array(splitPath)
							#return pathArray
						#else:
							#next = pipeInfo[pipe]["Split Gives"]
					#
					## Don't need to keep looping through the dictinary once we find the next one
					#break
	#
	#return pathArray
#
## Now that we know a path exists, calculate the resource amounts flowing through the path
## pathArray is an array of pipe locations that make up the found path
## mergerList is a list of Merge Pipes we've passed. There to make sure there's no infinite recursion if there's a chain of pipes that make a circle
## originalAmount is the amount in the initial extractor. Necessary for looping pipes
## recursionLoop checks if we're going through a looping pipe
## Returns nothing, but all the resource values are updated in each pipe
#func calculate_flow(pathArray : Array[Vector2], mergerList : Array[Vector2], originalAmount : Dictionary, recursionLoop : bool) -> void:
#
	## First pipe in the path
	#var first = pipeInfo[pathArray[0]]
	#
	## The first splitter encountered - stays null if there's no splitters
	#var baseSplit = null
	#
	## If there's a circle of pipes, get the first merger in the loop
	#var recursivePipe := Vector2(-100, 100)
	#print("--------------------------")
	#
	#for index in pathArray.size():
		#
		## Check for looping pipes first. They need special logic
		## Their resource is based on what's going through the pipe added to the original amount from the extractor
		#if pipeInfo[pathArray[index]]["Name"] == "Merge Pipe":
			#if mergerList.has(pathArray[index]):
				#print("***!***!***!***!***!***!***!***")
				#print("RECURSIVE PIPE ABORT ABORT")
				#print("***!***!***!***!***!***!***!***")
				#mergerList.clear()
				#mergerList.append(pathArray[index])
				#recursivePipe = pathArray[index]
				#var elementCheck
				#
				## Once the difference between the amount of resources from the current loop and previous loop is small, stop looping
				#for element in originalAmount:
					#if originalAmount[element] > 0:
						#elementCheck = element
				#
				#var previousLoop : float = pipeInfo[pathArray[index]]["Elements"][elementCheck]
				#var nextLoop : float = originalAmount[elementCheck] + first["Elements"][elementCheck]
				#
				#print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
				#print(pipeInfo[pathArray[index]])
				#print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
				#print(nextLoop)
				#print(previousLoop)
				#print(originalAmount[elementCheck] / 1000)
				#print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
				#if nextLoop - previousLoop >= originalAmount[elementCheck] / 1000:
					#recursionLoop = true
					#for element in pipeInfo[pathArray[index]]["Elements"]:
						#pipeInfo[pathArray[index]]["Elements"][element] = originalAmount[element] + first["Elements"][element]
				#else:
					#return
				#
				#first = pipeInfo[pathArray[index]]
				#
			#else:
				## If it's a new merger, add it to the mergerList
				#mergerList.append(pathArray[index])
		#
		## If we're in the middle of a loop of pipes, set it to the amounts in the merger instead of adding it to what's already there
		#if recursionLoop == true and first != pipeInfo[pathArray[index]] and pathArray[index] != recursivePipe:
			#for element in pipeInfo[pathArray[index]]["Elements"]:
				#pipeInfo[pathArray[index]]["Elements"][element] = first["Elements"][element]
		#
		## If we're just going through normally, add the value inside the pipe to the value coming through
		## Keeps things accurate if multiple extractors are flowing through this route
		#elif first != pipeInfo[pathArray[index]] and pipeInfo[pathArray[index]]["Name"] != "Extractor":
			#for element in pipeInfo[pathArray[index]]["Elements"]:
				#pipeInfo[pathArray[index]]["Elements"][element] += first["Elements"][element]
		#
		##if pipeInfo[pathArray[index]]["Name"] == "Phylactery" or pipeInfo[pathArray[index]]["Name"] == "Vaporizer":
		#print(pipeInfo[pathArray[index]])
		#print("--------------------------")
		#
		## If splitters exist we have to do all kinds of shenanigans
		## This gets the splitter so we can check all its paths
		#if pipeInfo[pathArray[index]]["Name"] == "Split Pipe":
			#baseSplit = pipeInfo[pathArray[index]]
			#break
	#
	## If a splitter exists, we must check all its paths
	## Splitter logic is like this
	## If both sides lead somewhere, the resources in it is split equally
	## If one side is a dead end, it becomes a normal pipe
	## 100% of the resources flowing through it go to that side
	## If neither side goes anywhere, it's a dead end and can be ignored
	## If the pipe is looping, we don't add to the existing value, we set it to the value in the first splitter
	## Multiple resources can go in each pipe
	#if baseSplit != null:
		#var gives = baseSplit["Gives"]
		#var splitGives = baseSplit["Split Gives"]
		#
		## Both the points that feed out of the splitter have a pipe on the tile
		#if pipeInfo.has(gives) == true and pipeInfo.has(splitGives) == true:
			#
			## Check to see if both sides actually have a path
			#var givesPath : Array[Vector2] = find_pipe_path(gives, [])
			#var splitsPath : Array[Vector2] = find_pipe_path(splitGives, [])
			#
			## If both sides reach an end point, split the resources in them
			#if givesPath != [] and splitsPath != []:
				#if recursionLoop == true:
					#for element in baseSplit["Elements"]:
						#pipeInfo[gives]["Elements"][element] = baseSplit["Elements"][element] / 2
						#pipeInfo[splitGives]["Elements"][element] = baseSplit["Elements"][element] / 2
				#else:
					#for element in baseSplit["Elements"]:
						#pipeInfo[gives]["Elements"][element] += baseSplit["Elements"][element] / 2
						#pipeInfo[splitGives]["Elements"][element] += baseSplit["Elements"][element] / 2
				#
				## Then continue calculating from here
				#calculate_flow(givesPath, mergerList, originalAmount, recursionLoop)
				#if recursionLoop == false:
					#calculate_flow(splitsPath, mergerList, originalAmount, recursionLoop)
			#
			## If only one side has an end point, don't divide the resources
			#elif givesPath != [] and splitsPath == []:
				#if recursionLoop == true:
					#for element in baseSplit["Elements"]:
						#pipeInfo[gives]["Elements"][element] = baseSplit["Elements"][element]
				#else: 
					#for element in baseSplit["Elements"]:
						#pipeInfo[gives]["Elements"][element] += baseSplit["Elements"][element]
				#
				## Then continue calculating from here
				#calculate_flow(givesPath, mergerList, originalAmount, recursionLoop)
			#
			## If only one side has an end point, don't divide the resources - but for the other side
			#elif givesPath == [] and splitsPath != []:
				#if recursionLoop == true:
					#for element in baseSplit["Elements"]:
						#pipeInfo[splitGives]["Elements"][element] = baseSplit["Elements"][element]
				#else:
					#
					#for element in baseSplit["Elements"]:
						#pipeInfo[splitGives]["Elements"][element] += baseSplit["Elements"][element]
				#
				## Then continue calculating from here
				#calculate_flow(splitsPath, mergerList, originalAmount, recursionLoop)
		#
		## Only one spot that the splitter feeds out to has a pipe on it
		#elif pipeInfo.has(gives) == true and pipeInfo.has(splitGives) == false:
			#
			## Make sure a path actually exists and we're not trying to feed into the pipe sideways or something
			#var newPath = find_pipe_path(gives, [])
			#
			#if newPath != []:
				#if recursionLoop == true:
					#for element in baseSplit["Elements"]:
						#pipeInfo[gives]["Elements"][element] = baseSplit["Elements"][element]
				#else:
					#for element in baseSplit["Elements"]:
						#pipeInfo[gives]["Elements"][element] += baseSplit["Elements"][element]
				#
				## Then continue calculating from here
				#calculate_flow(newPath, mergerList, originalAmount, recursionLoop)
		#
		## Only one spot that the splitter feeds out to has a pipe on it - but it's the other side from the above
		#elif pipeInfo.has(gives) == false and pipeInfo.has(splitGives) == true:
			#
			## Make sure a path actually exists and we're not trying to feed into the pipe sideways or something
			#var newPath = find_pipe_path(splitGives, [])
			#
			#if newPath != []:
				#if recursionLoop == true:
					#for element in baseSplit["Elements"]:
						#pipeInfo[splitGives]["Elements"][element] = baseSplit["Elements"][element]
				#else:
					#for element in baseSplit["Elements"]:
						#pipeInfo[splitGives]["Elements"][element] += baseSplit["Elements"][element]
				#
				## Then continue calculating from here
				#calculate_flow(newPath, mergerList, originalAmount, recursionLoop)
