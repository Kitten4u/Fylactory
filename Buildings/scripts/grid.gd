class_name Grid extends Node2D

#region General Globals
# Grid Information
@export var GRID_SIZE := Vector2(1000, 1000)
var CELL_AMOUNT : Vector2
var menuOffset : Vector2

var sourceArray : Array[Source]
var waitForBlueprintMenuClose : bool = false
#endregion

#region Build Mode Information
var selectedBuilding
var selectedBuildingIndex
var buildingPreviewInstance
var pipeInfo : Dictionary
var buildingRotation : int = 0
var flip : bool = false
var justBuiltBuildingUnderground : bool = false
var undergroundLocation : String
var phylacteryLocation : String = var_to_str(Vector2.INF)
#endregion

#region Preview for Pipe Dragging Path
var pipeDragging : bool = false
var forceBuild : bool = false
var preDragBuilding
var preDragBuildingIndex : int
var preDragBuildingRotation : int
var preDragBuildingFlip : bool
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
#endregion

#region For Selecting Pipes
var selectionDragging : bool = false
var copying : bool = false
var selectedPipes : Array = []
var selectedBodies : Array = []
var highlightedPipes : Array = []
var selectionDragStart := Vector2.ZERO
var selectionRect := RectangleShape2D.new()
var gridParent 
#endregion

func _ready() -> void:
	# calculate grid size
	CELL_AMOUNT = Vector2(GRID_SIZE.x / FactoryGlobal.CELL_SIZE.x, GRID_SIZE.y / FactoryGlobal.CELL_SIZE.y)
	menuOffset = Vector2(0, 0)
	gridParent = get_parent()
	
	#region Create the building preview
	selectedBuilding = FactoryGlobal.selectedBuildingBetweenRooms
	selectedBuildingIndex = FactoryGlobal.selectedBuildingIndexBetweenRooms
	if selectedBuilding:
		buildingPreviewInstance = selectedBuilding.instantiate()
		add_child(buildingPreviewInstance)
		buildingPreviewInstance.modulate.a = 0.7
	#endregion

	#region Add Sources to sourceArray
	for source in %Sources.get_children():
		if source is Source:
			sourceArray.append(source)
	#endregion
	
	#region Rebuild Factory
	if FactoryGlobal.activePipeLayout.has(get_parent().name):
		pipeInfo = FactoryGlobal.activePipeLayout[get_parent().name].duplicate(true)
		for pipe in pipeInfo:
			var buildingScene = null
			while not buildingScene:
				buildingScene = load(pipeInfo[pipe]["Scene"])
				await get_tree().process_frame
			
			var building = buildingScene.instantiate()
			if pipeInfo[pipe]["Name"] == "Phylactery":
				phylacteryLocation = pipe
			building.position = Vector2(pipeInfo[pipe]["X"], pipeInfo[pipe]["Y"]) + FactoryGlobal.HALF_CELL_SIZE
			if pipeInfo[pipe]["Flip"] == true:
				building.scale.x = -1
			building.get_node("Sprite2D").rotate(deg_to_rad(pipeInfo[pipe]["Rotation"]))
			building.add_to_group("Buildings")
			%Buildings.add_child(building)
		#endregion

func _process(_delta: float) -> void:
	if waitForBlueprintMenuClose == true:
		waitForBlueprintMenuClose = false
	
	if FactoryGlobal.player:
		playerLocation = FactoryGlobal.player.get_node("BuildArea").global_position
	
	#region Blueprint placer
	if FactoryGlobal.selectedBlueprint != {}:
		var blueprint = FactoryGlobal.selectedBlueprint
		FactoryGlobal.selectedBlueprint = {}
		if buildingPreviewInstance:
			buildingPreviewInstance.queue_free()
		
		copying = true
		var holder = get_node_or_null("Holder")
		if holder:
			for building in holder.get_children():
				building.queue_free()
		else:
			holder = CanvasGroup.new()
			holder.set_name("Holder")
			holder.modulate.a = 0.7
			add_child(holder)

		var positionArray : Array[Vector2] = []
	
		for building in blueprint:
			var buildingScene = null
			while not buildingScene:
				buildingScene = blueprint[building]["Type"]
				await get_tree().process_frame
				
			var buildingInstance = load(buildingScene).instantiate()
			buildingInstance.position = Vector2(str_to_var(building)) + FactoryGlobal.HALF_CELL_SIZE
			positionArray.append(buildingInstance.position)
			if blueprint[building]["Flip"] == true:
				buildingInstance.scale.x = -1
			buildingInstance.get_node("Sprite2D").rotate(deg_to_rad(blueprint[building]["Rotation"]))
			holder.add_child(buildingInstance)
		
		var highLowDic : Dictionary[String, float] = get_blueprint_area(positionArray)
		holder.position = Vector2(highLowDic["Highest X"], highLowDic["Highest Y"])
		
		for pipe in holder.get_children():
			pipe.position = pipe.position - Vector2(highLowDic["Highest X"], highLowDic["Highest Y"]) + FactoryGlobal.HALF_CELL_SIZE
	#endregion
		
	#region Handling mass creating pipes with mouse drag
	elif pipeDragging == true:
		overlappingPipes.clear()
		outsideBuildAreaPipes.clear()
		if buildingPreviewInstance:
			buildingPreviewInstance.queue_free()
		create_preview_path()
		
		if currentPreview != Vector2.INF and previewStart != Vector2.INF:
			transformPipe = false
					
			var rectStart := Rect2(create_preview_path_start()).abs()
			var rectEnd := Rect2(create_preview_path_end()).abs()
			var pipeFacing : Vector2
			var pipeCorner : Vector2
			
			var coordCheck := previewStart
			var previewPlace : float
			var previewChange : float
			var pointCheck : float
			var farthestPoint : float
					
			if abs(previewDirection.x) > abs(previewDirection.y):
				pointCheck = previewStart.x
				farthestPoint = currentPreview.x
				if currentPreview.x > previewStart.x:
					previewChange = FactoryGlobal.CELL_SIZE.x
				else:
					previewChange = -FactoryGlobal.CELL_SIZE.x
						
			else:
				pointCheck = previewStart.y
				farthestPoint = currentPreview.y
				if currentPreview.y > previewStart.y:
					previewChange = FactoryGlobal.CELL_SIZE.y
				else:
					previewChange = -FactoryGlobal.CELL_SIZE.y
					
			previewPlace = previewChange
			if is_inside_build_area(previewStart) == false:
				outsideBuildAreaPipes.append(previewStart)
			
			while pointCheck != farthestPoint:
				if abs(previewDirection.x) > abs(previewDirection.y):
					coordCheck = Vector2(previewStart.x + previewPlace, previewStart.y)
				else: 
					coordCheck = Vector2(previewStart.x, previewStart.y + previewPlace)
				
				if is_inside_build_area(coordCheck) == false:
					outsideBuildAreaPipes.append(coordCheck)
				
				previewPlace += previewChange
				pointCheck += previewChange
			
			if abs(previewDirection.x) > abs(previewDirection.y):
				pointCheck = previewStart.y
				farthestPoint = currentPreview.y
				if currentPreview.y > previewStart.y:
					previewChange = FactoryGlobal.CELL_SIZE.y
				else:
					previewChange = -FactoryGlobal.CELL_SIZE.y
						
			else:
				pointCheck = previewStart.x
				farthestPoint = currentPreview.x
				if currentPreview.x > previewStart.x:
					previewChange = FactoryGlobal.CELL_SIZE.x
				else:
					previewChange = -FactoryGlobal.CELL_SIZE.x
					
			previewPlace = previewChange
			
			while pointCheck != farthestPoint:
				if abs(previewDirection.x) > abs(previewDirection.y):
					coordCheck = Vector2(currentPreview.x, previewStart.y + previewPlace)
				else: 
					coordCheck = Vector2(previewStart.x + previewPlace, currentPreview.y)
				
				if is_inside_build_area(coordCheck) == false:
					outsideBuildAreaPipes.append(coordCheck)
					
				previewPlace += previewChange
				pointCheck += previewChange
			
			if abs(previewDirection.x) > abs(previewDirection.y):
				pipeFacing = previewStart.direction_to(Vector2(currentPreview.x, previewStart.y))
				pipeCorner = Vector2(currentPreview.x, previewStart.y)
			else: 
				pipeFacing = previewStart.direction_to(Vector2(previewStart.x, currentPreview.y))
				pipeCorner = Vector2(previewStart.x, currentPreview.y)
			
			for pipe in %Buildings.get_children():
				var previewPipeRotation = rad_to_deg(pipe.get_node("Sprite2D").rotation)
				var previewPipeFlip = get_building_flip(pipe)
				
				if pipe.position - FactoryGlobal.HALF_CELL_SIZE == previewStart and previewStart != currentPreview:
					if pipe.TYPE == TurnPipe.TYPE \
					and pipe.get_gives(previewPipeRotation, previewPipeFlip) * -1 == pipeFacing:
						transformPipe = true
					
					if pipe.has_method("get_recieves"):
						if pipe.get_recieves(previewPipeRotation, previewPipeFlip) == pipeFacing:
							transformPipe = true
							reversePath = true
					
					if pipe.has_method("get_merge_pipe_merges"):
						if pipe.get_merge_pipe_merges(previewPipeRotation, previewPipeFlip) == pipeFacing:
							transformPipe = true
							reversePath = true
				
				if rectStart.has_point(pipe.position) \
				or rectEnd.has_point(pipe.position) \
				or currentPreview == pipe.position - FactoryGlobal.HALF_CELL_SIZE \
				or (previewStart == pipe.position - FactoryGlobal.HALF_CELL_SIZE and transformPipe == false) \
				or pipeCorner == pipe.position - FactoryGlobal.HALF_CELL_SIZE:
					overlappingPipes.append(pipe.position - FactoryGlobal.HALF_CELL_SIZE)
	#endregion
	
	#region Selections
	elif selectionDragging == true:
		selectedPipes.clear()
		selectedBodies.clear()
		highlightedPipes.clear()
		var selectionDragEnd : Vector2 = get_local_mouse_position()
		selectedBodies = get_overlapping_preview_pipes(selectionDragStart, selectionDragEnd)
		
		for body in selectedBodies:
			if body.collider.is_in_group("Buildings") and body.collider.get_parent().get_parent() == gridParent:
				var bodyPosition = body.collider.position
				var bodyGridPosition = get_grid_coordinates(bodyPosition)
				bodyPosition = get_grid_position(bodyGridPosition)
				selectedPipes.append(bodyPosition)
				highlightedPipes.append(bodyPosition)
	#endregion
	
	#region Copy/Pase functionality
	elif copying == true:
		overlappingPipes.clear()
		selectedPipes.clear()
		var holder = get_node_or_null("Holder")
		if holder:
			for pipe in holder.get_children():
				var foundOverlap = false
				for building in %Buildings.get_children():
					if pipe.global_position == building.global_position:
						foundOverlap = true
				
				if foundOverlap == true:
					overlappingPipes.append(pipe.global_position - FactoryGlobal.HALF_CELL_SIZE - menuOffset)
				else:
					selectedPipes.append(pipe.global_position - FactoryGlobal.HALF_CELL_SIZE - menuOffset)
	#endregion
	
	elif isBuildingUnderground == true:
		if buildingPreviewInstance:
			buildingPreviewInstance.queue_free()
			
	if copying == true:
		var holder = get_node_or_null("Holder")
		if holder:
			holder.position = cursor_snap()
	else:
		copying = false
		if buildingPreviewInstance:
			buildingPreviewInstance.position = cursor_snap() + FactoryGlobal.HALF_CELL_SIZE
			
	queue_redraw()

func _input(event: InputEvent) -> void:
	if FactoryGlobal.disableInput == false:
		if waitForBlueprintMenuClose == false:
			if event.is_action_pressed("build_mode"):
				enter_exit_build_mode()
			
			if %Grid.visible == true:
				#region Click Released
				if event.is_action_released("attack_build"):
					if copying == true:
						selectionDragging = false
						var holder = get_node_or_null("Holder")
						if holder:
							if forceBuild == true:
								for pipe in overlappingPipes:
									for building in %Buildings.get_children():
										if pipe == building.position - FactoryGlobal.HALF_CELL_SIZE:
											building.queue_free()
											if pipeInfo.has(var_to_str(pipe)):
												pipeInfo.erase(var_to_str(pipe))
							
							for pipe in holder.get_children():
								selectedBuilding = load(pipe.TYPE)
								selectedBuildingIndex = FactoryGlobal.buildingArray.find(selectedBuilding)
								pipe.global_position = pipe.global_position - FactoryGlobal.HALF_CELL_SIZE
								var holderRotation = 0
								if holder.rotation != 0:
									holderRotation = snapped(rad_to_deg(holder.rotation), 0)
								buildingRotation = snapped(rad_to_deg(pipe.get_node("Sprite2D").rotation), 0) + holderRotation
								flip = get_building_flip(pipe)
								if get_building_flip(holder) == true:
									flip = !flip
								if pipeInfo.has(var_to_str(pipe.global_position - menuOffset)) == false:
									spawn_building(var_to_str(pipe.global_position - menuOffset))
									pipe.global_position = pipe.global_position + FactoryGlobal.HALF_CELL_SIZE
							selectedBuilding = preDragBuilding
							selectedBuildingIndex = preDragBuildingIndex
						else:
							copying = false
					else:
						if selectedBuildingIndex != -1:
							pipeDragging = false
							if selectedBuilding != FactoryGlobal.undergroundPipeStart:
								previewEnd = cursor_snap()
								
								if previewStart != previewEnd:
									handle_pipe_chain()
								else:
									if pipeInfo.has(var_to_str(cursor_snap())) == true:
										display_pipe_info(var_to_str(cursor_snap()))
									else:
										spawn_building(var_to_str(cursor_snap()))
										
								
								selectedBuildingIndex = preDragBuildingIndex
								selectedBuilding = preDragBuilding
								flip = preDragBuildingFlip
								buildingRotation = preDragBuildingRotation
								select_building(selectedBuildingIndex)
							else:
								isBuildingUnderground = false
								if pipeInfo.has(var_to_str(previewStart)) == false:
									spawn_building(var_to_str(previewStart))
						
						else:
							selectionDragging = false
							if pipeInfo.has(var_to_str(cursor_snap())) == true:
								display_pipe_info(var_to_str(cursor_snap()))
				#endregion
				
				#region Click Pressed
				elif event.is_action_pressed("attack_build"):
					previewStart = Vector2.INF
					currentPreview = Vector2.INF
					previewEnd = Vector2.INF
					previewDirection = Vector2.INF
					transformPipe = false
					reversePath = false
					
					if copying == false:
						if selectedBuildingIndex != -1:
							if selectedBuilding != FactoryGlobal.undergroundPipeStart:
								pipeDragging = true
								preDragBuilding = selectedBuilding
								preDragBuildingIndex = selectedBuildingIndex
								preDragBuildingFlip = flip
								preDragBuildingRotation = buildingRotation
							
							else:
								isBuildingUnderground = true
								previewStart = cursor_snap()
							
						else:
							selectionDragging = true
							selectionDragStart = get_local_mouse_position()
				#endregion
				
				#region Open Blueprint
				elif event.is_action_pressed("open_blueprint"):
					var parent = get_tree().root
					var blueprintMenu = parent.get_node_or_null("BlueprintMenu")
					if blueprintMenu == null:
						blueprintMenu = load("res://Menus/blueprint_menu.tscn").instantiate()
						FactoryGlobal.selectedBlueprint = {}
						parent.add_child(blueprintMenu)
						waitForBlueprintMenuClose = true
						get_tree().paused = true
					else:
						%Grid.process_mode = Node.PROCESS_MODE_INHERIT
						get_tree().paused = false
						blueprintMenu.queue_free()
				
				elif event.is_action_pressed("create_blueprint"):		
					var parent = get_tree().root
					var blueprintMenu = parent.get_node_or_null("BlueprintMenu")
					if blueprintMenu == null:
						var holder = get_node_or_null("Holder")
						if holder:
							var prepareBlueprint : Dictionary = {}
							for pipe in holder.get_children():
								prepareBlueprint[var_to_str(pipe.position - FactoryGlobal.HALF_CELL_SIZE)] = {
									"Type" : pipe.TYPE,
									"Rotation" : rad_to_deg(pipe.get_node("Sprite2D").rotation),
									"Flip" : get_building_flip(pipe),
								}
							FactoryGlobal.blueprintChunk = prepareBlueprint.duplicate(true)
							blueprintMenu = load("res://Menus/blueprint_menu.tscn").instantiate()
							FactoryGlobal.selectedBlueprint = {}
							parent.add_child(blueprintMenu)
							waitForBlueprintMenuClose = true
							get_tree().paused = true
				#endregion
				
				#region Other Input
				elif event.is_action_pressed("copy"):
					if selectedBodies != []:
						copying = true
						create_copy_preview()
						selectedBodies.clear()
						highlightedPipes.clear()
				elif event.is_action_pressed("select_building") and justBuiltBuildingUnderground == false:
					$BuildingWheel.position = get_local_mouse_position()
					$BuildingWheel.show()
				
				elif event.is_action_released("force_build"):
					forceBuild = false
				
				elif event.is_action_pressed("force_build"):
					forceBuild = true
				
				elif event.is_action_released("select_building"):
					selectedBuildingIndex = $BuildingWheel.close()
					select_building(selectedBuildingIndex)
				
				elif event.is_action_pressed("delete_building"):
					if highlightedPipes != []:
						for pipe in highlightedPipes:
							delete_building(var_to_str(pipe))
						highlightedPipes.clear()
					else:
						delete_building(var_to_str(cursor_snap()))
				
				elif event.is_action_pressed("rotate_left"):
					rotate_building(-90)
				
				elif event.is_action_pressed("rotate_right"):
					rotate_building(90)
				
				elif event.is_action_pressed("flip_horizontal"):
					flip_building()
				#endregion

func _draw() -> void:
	#region Draw Grid Lines
	for i in CELL_AMOUNT.x:
		var lineTop := Vector2(i * FactoryGlobal.CELL_SIZE.x, 0)
		var lineBottom := Vector2(i * FactoryGlobal.CELL_SIZE.x, GRID_SIZE.y)
		draw_line(lineTop, lineBottom, FactoryGlobal.GRID_LINE_COLOR)
	
	for i in CELL_AMOUNT.y:
		var lineLeft := Vector2(0, FactoryGlobal.CELL_SIZE.y * i)
		var lineRight := Vector2(GRID_SIZE.x, lineLeft.y)
		draw_line(lineLeft, lineRight, FactoryGlobal.GRID_LINE_COLOR)
	#endregion
	
	if selectionDragging == false and copying == false:
		draw_rect(highlight_cell(), FactoryGlobal.GRID_HIGHLIGHT_COLOR)
	
	if highlightedPipes != []:
		for index in highlightedPipes.size():
			draw_rect(Rect2(highlightedPipes[index], FactoryGlobal.CELL_SIZE), FactoryGlobal.GRID_HIGHLIGHT_COLOR)
	
	#region Drawing Copying
	if copying == true:
		if selectedPipes != []:
			for index in selectedPipes.size():
				draw_rect(Rect2(selectedPipes[index], FactoryGlobal.CELL_SIZE), FactoryGlobal.GRID_GOOD_COLOR)
		
		if overlappingPipes != []:
			for index in overlappingPipes.size():
				if forceBuild == false:
					draw_rect(Rect2(overlappingPipes[index], FactoryGlobal.CELL_SIZE), FactoryGlobal.GRID_ERROR_COLOR)
				else:
					draw_rect(Rect2(overlappingPipes[index], FactoryGlobal.CELL_SIZE), FactoryGlobal.GRID_REPLACE_COLOR)
	#endregion
	
	#region Drawing pipe dragging
	elif pipeDragging == true:
		draw_rect(create_preview_path_start(), FactoryGlobal.GRID_GOOD_COLOR)
		draw_rect(Rect2(previewStart, FactoryGlobal.CELL_SIZE), FactoryGlobal.GRID_GOOD_COLOR)
		draw_rect(create_preview_path_end(), FactoryGlobal.GRID_GOOD_COLOR)
		draw_rect(Rect2(currentPreview, FactoryGlobal.CELL_SIZE), FactoryGlobal.GRID_GOOD_COLOR)
		if abs(previewDirection.x) > abs(previewDirection.y):
			draw_rect(Rect2(currentPreview.x, previewStart.y, FactoryGlobal.CELL_SIZE.x, FactoryGlobal.CELL_SIZE.y), FactoryGlobal.GRID_GOOD_COLOR)
		else:
			draw_rect(Rect2(previewStart.x, currentPreview.y, FactoryGlobal.CELL_SIZE.x, FactoryGlobal.CELL_SIZE.y), FactoryGlobal.GRID_GOOD_COLOR)
		
		if overlappingPipes != []:
			for index in overlappingPipes.size():
				if forceBuild == false:
					draw_rect(Rect2(overlappingPipes[index], FactoryGlobal.CELL_SIZE), FactoryGlobal.GRID_ERROR_COLOR)
				else:
					draw_rect(Rect2(overlappingPipes[index], FactoryGlobal.CELL_SIZE), FactoryGlobal.GRID_REPLACE_COLOR)
		
		var parent = get_tree().root
		var blueprintMenu = parent.get_node_or_null("BlueprintMenu")
		if outsideBuildAreaPipes != [] and not blueprintMenu:
			for index in outsideBuildAreaPipes.size():
				draw_rect(Rect2(outsideBuildAreaPipes[index], FactoryGlobal.CELL_SIZE), FactoryGlobal.GRID_OUTSIDE_BUILD_AREA_COLOR)
		
		if transformPipe == true:
			draw_rect(Rect2(previewStart, FactoryGlobal.CELL_SIZE), FactoryGlobal.GRID_TRANSFORM_COLOR)
	#endregion
	
	#region Selection
	elif selectionDragging == true:
		if selectedPipes != []:
			for index in selectedPipes.size():
				draw_rect(Rect2(selectedPipes[index], FactoryGlobal.CELL_SIZE), FactoryGlobal.GRID_HIGHLIGHT_COLOR)
		
		draw_rect(Rect2(selectionDragStart, get_local_mouse_position() - selectionDragStart), FactoryGlobal.GRID_SELECTION_OUTLINE_COLOR, false, FactoryGlobal.GRID_BOX_OUTLLINE_THICKNESS)
	#endregion
	
	elif isBuildingUnderground == true:
		draw_rect(Rect2(previewStart, FactoryGlobal.CELL_SIZE), FactoryGlobal.GRID_GOOD_COLOR)

#region Grid Helpers
func enter_exit_build_mode() -> void:
	if %Grid.visible == false:
		%Buildings.self_modulate.a = 1
		%Grid.show()
	else:
		%Buildings.self_modulate.a = FactoryGlobal.factoryOpacity
		%Grid.hide()

func highlight_cell() -> Rect2:
	return Rect2(cursor_snap(), FactoryGlobal.CELL_SIZE)

func get_grid_position(cellPosition : Vector2) -> Vector2:
	return cellPosition * FactoryGlobal.CELL_SIZE

func get_grid_coordinates(gridPosition : Vector2) -> Vector2:
	return floor(gridPosition / FactoryGlobal.CELL_SIZE)

func cursor_snap() -> Vector2:
	var cursorPosition := Vector2(get_local_mouse_position().x, get_local_mouse_position().y)
	var cursorCoords := get_grid_coordinates(cursorPosition)
	return get_grid_position(cursorCoords)

func get_building_flip(building) -> bool:
	if building.scale.x == -1:
		return true
	else: 
		return false

func is_inside_build_area(trueLocation : Vector2) -> bool:
	if playerLocation.distance_to(trueLocation) <= FactoryGlobal.buildAreaRadius \
	or playerLocation.distance_to(Vector2(trueLocation.x + FactoryGlobal.CELL_SIZE.x, trueLocation.y)) <= FactoryGlobal.buildAreaRadius \
	or playerLocation.distance_to(Vector2(trueLocation.x + FactoryGlobal.CELL_SIZE.x, trueLocation.y + FactoryGlobal.CELL_SIZE.y)) <= FactoryGlobal.buildAreaRadius \
	or playerLocation.distance_to(Vector2(trueLocation.x, trueLocation.y + FactoryGlobal.CELL_SIZE.y)) <= FactoryGlobal.buildAreaRadius:
		return true
	else:
		return false

func get_blueprint_area(positions : Array[Vector2]) -> Dictionary[String, float]:
	var lowestX : float = positions[0].x
	var lowestY : float = positions[0].y
	var highestX : float = positions[0].x
	var highestY : float = positions[0].y
	
	for check in positions:
		if check.x > highestX:
			highestX = check.x
		elif check.x < lowestX:
			lowestX = check.x
			
		if check.y > highestY:
			highestY = check.y
		elif check.y < lowestY:
			lowestY = check.y
	
	var highestLowestDictonary : Dictionary[String, float] = {
		"Highest X" : highestX,
		"Highest Y" : highestY,
		"Lowest X" : lowestX,
		"Lowest Y" : lowestY,
	}
	
	return highestLowestDictonary
#endregion

#region Create groups of pipes functionality
func handle_pipe_chain() -> void:
	var currentBuildings : Array = %Buildings.get_children()
	var previewPipesStart : Array[Vector2] = create_dragged_pipes_start()
	var previewPipesEnd : Array[Vector2] = create_dragged_pipes_end()
	var currentBuilding = null
	
	for pipe in previewPipesStart:
		for building in currentBuildings:
			if building.position - FactoryGlobal.HALF_CELL_SIZE == pipe:
				currentBuilding = building
				if forceBuild == true:
					delete_building(var_to_str(pipe))

		if previewPipesStart[0] == pipe:
			if currentBuilding:
				if currentBuilding.TYPE == TurnPipe.TYPE and transformPipe == true:
					selectedBuilding = FactoryGlobal.splitPipe
					selectedBuildingIndex = SplitPipe.BUILDING_INDEX
					buildingRotation = rad_to_deg(currentBuilding.get_node("Sprite2D").rotation)
					flip = get_building_flip(currentBuilding)
					delete_building(var_to_str(pipe))
				
				else:
					selectedBuilding = FactoryGlobal.normalPipe
					selectedBuildingIndex = NormalPipe.BUILDING_INDEX
			
					flip = false
					rotate_dragged_straight_pipes()
			
			else:
				handle_first_pipe_special_cases()
					
		
		elif previewPipesStart[-1] == pipe and previewPipesEnd != []:
			selectedBuilding = FactoryGlobal.turnPipe
			selectedBuildingIndex = TurnPipe.BUILDING_INDEX
			rotate_drgged_turn_pipes()
	
		else:
			selectedBuilding = FactoryGlobal.normalPipe
			selectedBuildingIndex = NormalPipe.BUILDING_INDEX
			
			flip = false
			rotate_dragged_straight_pipes()
		
		if pipeInfo.has(var_to_str(pipe)) == false:
			spawn_building(var_to_str(pipe))
	
	selectedBuilding = FactoryGlobal.normalPipe
	selectedBuildingIndex = NormalPipe.BUILDING_INDEX
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
		if pipeInfo.has(var_to_str(pipe)) == false:
			spawn_building(var_to_str(pipe))

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

func create_copy_preview() -> void:
	var holder = get_node_or_null("Holder")
	if holder:
		for building in holder.get_children():
			building.queue_free()
	else:
		holder = CanvasGroup.new()
		holder.set_name("Holder")
		holder.modulate.a = 0.7
		add_child(holder)
	
	var positonArray : Array[Vector2] = []
	
	if selectedBodies != []:
		for body in selectedBodies:
			if body.collider.is_in_group("Buildings") and body.collider.get_parent().get_parent() == gridParent:
				var previewPipe = body.collider.duplicate()
				positonArray.append(previewPipe.global_position)

				holder.add_child(previewPipe)
	
	if positonArray != []:
		var highLowDic = get_blueprint_area(positonArray)
		#var previewOffset = Vector2(highestX - lowestX, highestY - lowestY) / 2 - FactoryGlobal.HALF_CELL_SIZE
		holder.global_position = Vector2(highLowDic["Highest X"], highLowDic["Highest Y"])
		
		for pipe in holder.get_children():
			pipe.position = pipe.position - Vector2(highLowDic["Highest X"], highLowDic["Highest Y"]) + FactoryGlobal.HALF_CELL_SIZE
			#pipe.position += previewOffset

func handle_first_pipe_special_cases() -> void:
	selectedBuilding = preDragBuilding
	selectedBuildingIndex = preDragBuildingIndex
	flip = preDragBuildingFlip
				
	if selectedBuilding == FactoryGlobal.splitPipe:
		buildingRotation = preDragBuildingRotation
					#
	#elif selectedBuilding == FactoryGlobal.turnPipe:
		#buildingRotation = preDragBuildingRotation
		#flip = false
		#if abs(previewDirection.x) > abs(previewDirection.y):
			#if previewEnd.x > previewStart.x:
				#buildingRotation = 0
				#for building in %Buildings.get_children():
					#if building.position == Vector2(previewStart.x, previewStart.y + FactoryGlobal.CELL_SIZE.y):
						#if building.has_method("get_gives"):
							#var checkGrid = get_grid_coordinates(building.position) + building.get_gives(rad_to_deg(building.get_node("Sprite2D").rotation), get_building_flip(building))
							#if get_grid_position(checkGrid) == previewStart:
								#flip = true
								#buildingRotation = 180
						#
						#if building.has_method("get_split_pipe_splits"):
							#var checkGrid = get_grid_coordinates(building.position) + building.get_split_pipe_splits(rad_to_deg(building.get_node("Sprite2D").rotation), get_building_flip(building))
							#if get_grid_position(checkGrid) == previewStart:
								#flip = true
								#buildingRotation = 180
			#else:
				#buildingRotation = 180
				#for building in %Buildings.get_children():
					#if building.position == Vector2(previewStart.x, previewStart.y - FactoryGlobal.CELL_SIZE.y):
						#if building.has_method("get_gives"):
							#var checkGrid = get_grid_coordinates(building.position) + building.get_gives(rad_to_deg(building.get_node("Sprite2D").rotation), get_building_flip(building))
							#if get_grid_position(checkGrid) == previewStart:
								#flip = true
								#buildingRotation = 0
						#
						#if building.has_method("get_split_pipe_splits"):
							#var checkGrid = get_grid_coordinates(building.position) + building.get_split_pipe_splits(rad_to_deg(building.get_node("Sprite2D").rotation), get_building_flip(building))
							#if get_grid_position(checkGrid) == previewStart:
								#flip = true
								#buildingRotation = 0
		#else:
			#if previewEnd.y > previewStart.y:
				#buildingRotation = 90
				#for building in %Buildings.get_children():
					#if building.position == Vector2(previewStart.x - FactoryGlobal.CELL_SIZE.x, previewStart.y):
						#if building.has_method("get_gives"):
							#var checkGrid = get_grid_coordinates(building.position) + building.get_gives(rad_to_deg(building.get_node("Sprite2D").rotation), get_building_flip(building))
							#if get_grid_position(checkGrid) == previewStart:
								#flip = true
						#
						#if building.has_method("get_split_pipe_splits"):
							#var checkGrid = get_grid_coordinates(building.position) + building.get_split_pipe_splits(rad_to_deg(building.get_node("Sprite2D").rotation), get_building_flip(building))
							#if get_grid_position(checkGrid) == previewStart:
								#flip = true
			#else:
				#buildingRotation = 270
				#for building in %Buildings.get_children():
					#if building.position == Vector2(previewStart.x + FactoryGlobal.CELL_SIZE.x, previewStart.y):
						#if building.has_method("get_gives"):
							#var checkGrid = get_grid_coordinates(building.position) + building.get_gives(rad_to_deg(building.get_node("Sprite2D").rotation), get_building_flip(building))
							#if get_grid_position(checkGrid) == previewStart:
								#flip = true
						#
						#if building.has_method("get_split_pipe_splits"):
							#var checkGrid = get_grid_coordinates(building.position) + building.get_split_pipe_splits(rad_to_deg(building.get_node("Sprite2D").rotation), get_building_flip(building))
							#if get_grid_position(checkGrid) == previewStart:
								#flip = true
	else:
		rotate_dragged_straight_pipes()

func create_preview_path() -> void:
	if previewStart == Vector2.INF:
		previewStart = cursor_snap()
	
	elif previewDirection == Vector2.INF and cursor_snap().distance_to(previewStart) >= FactoryGlobal.CELL_SIZE.x:
		previewDirection = previewStart.direction_to(cursor_snap())
		currentPreview = cursor_snap()
	
	elif currentPreview != Vector2.INF and previewDirection != Vector2.INF and cursor_snap().distance_to(currentPreview) >= FactoryGlobal.CELL_SIZE.x:
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
	
func create_dragged_pipes_start() -> Array[Vector2]:
	var previewPipePath : Array[Vector2] = []
	var previewCount : float
	var previewPlace : float
	
	previewPipePath.append(previewStart)
	
	if abs(previewDirection.x) > abs(previewDirection.y):
		if previewEnd.x > previewStart.x:
			previewPlace = FactoryGlobal.CELL_SIZE.x
		else:
			previewPlace = -FactoryGlobal.CELL_SIZE.x
		
		previewCount = abs(previewStart.x - previewEnd.x)
		
		while previewCount > 0:
			previewPipePath.append(Vector2(previewStart.x + previewPlace, previewStart.y))
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
			previewPipePath.append(Vector2(previewStart.x, previewStart.y + previewPlace))
			previewCount -= FactoryGlobal.CELL_SIZE.y
			if previewEnd.y > previewStart.y:
				previewPlace += FactoryGlobal.CELL_SIZE.y
			else:
				previewPlace -= FactoryGlobal.CELL_SIZE.y
	
	return previewPipePath

func create_dragged_pipes_end() -> Array[Vector2]:
	var previewPipePath : Array[Vector2] = []
	var previewCount : float
	var previewPlace : float
	
	if abs(previewDirection.x) > abs(previewDirection.y):
		previewCount = abs(previewEnd.y - previewStart.y)
		
		if previewEnd.y > previewStart.y:
			previewPlace = FactoryGlobal.CELL_SIZE.y
		else:
			previewPlace = -FactoryGlobal.CELL_SIZE.y
		
		while previewCount > 0:
			previewPipePath.append(Vector2(currentPreview.x, previewStart.y + previewPlace))
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
			previewPipePath.append(Vector2(previewStart.x + previewPlace, currentPreview.y))
			previewCount -= FactoryGlobal.CELL_SIZE.x
			if previewEnd.x > previewStart.x:
				previewPlace += FactoryGlobal.CELL_SIZE.x
			else:
				previewPlace -= FactoryGlobal.CELL_SIZE.x
	
	return previewPipePath

func get_overlapping_preview_pipes(dragStart : Vector2, dragEnd : Vector2, ) -> Array:
	selectionRect.size = (dragEnd - dragStart).abs()
	var selectionSpace = get_world_2d().direct_space_state
	var selectionQuery = PhysicsShapeQueryParameters2D.new()
	selectionQuery.collide_with_areas = true
	selectionQuery.set_shape(selectionRect)
	selectionQuery.transform = Transform2D(0, (dragEnd + dragStart) / 2 + menuOffset)
	selectedBodies = selectionSpace.intersect_shape(selectionQuery)
	return selectedBodies
#endregion

#region Building functions
# Builds the building. Puts it on the grid and gives the game all the info it needs about the building.
func spawn_building(location : String) -> void:
	var trueLocation = str_to_var(location)
	
	#if is_inside_build_area(trueLocation) == true:
	if 1 == 1:
		# Check to see if there's a pipe at that location already
		#if pipeInfo.has(location) == false:
		if 1 == 1: # Look, I just don't want to fix my inditation in case this idea I have doesn't work
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
			var sourceDictionary : Dictionary[String, float] = {}
			for element in FactoryGlobal.elementArray:
				sourceDictionary[element] = 0
				
			# Each pipe has unique info, so check the type of pipe and populate the info accordingly
			# Some have unique circumstances where they can't be placed, so check that too
			# Each pipe has a script that says which direction it's facing. That's used to determine which tiles connect to it
			if selectedBuilding == FactoryGlobal.normalPipe:
				canBuild = true
				buildingScene = "uid://b5ljabl0gd3u5"
				nameBuilding = "Normal Pipe"
				var vectorRecieves = get_grid_coordinates(trueLocation) + NormalPipe.get_recieves(buildingRotation, flip)
				recieves = var_to_str(get_grid_position(vectorRecieves))
				var vectorGives = get_grid_coordinates(trueLocation) + NormalPipe.get_gives(buildingRotation, flip)
				gives = var_to_str(get_grid_position(vectorGives))
			
			elif selectedBuilding == FactoryGlobal.turnPipe:
				canBuild = true
				buildingScene = "uid://cqy8ue3p87kvi"
				nameBuilding = "Turn Pipe"
				var vectorRecieves = get_grid_coordinates(trueLocation) + TurnPipe.get_recieves(buildingRotation, flip)
				recieves = var_to_str(get_grid_position(vectorRecieves))
				var vectorGives = get_grid_coordinates(trueLocation) + TurnPipe.get_gives(buildingRotation, flip)
				gives = var_to_str(get_grid_position(vectorGives))
			
			elif selectedBuilding == FactoryGlobal.mergePipe:
				canBuild = true
				buildingScene = "uid://cvfg3ivtnqdxs"
				nameBuilding = "Merge Pipe"
				var vectorRecieves = get_grid_coordinates(trueLocation) + MergePipe.get_recieves(buildingRotation, flip)
				recieves = var_to_str(get_grid_position(vectorRecieves))
				var vectorMergeRecieves = get_grid_coordinates(trueLocation) + MergePipe.get_merge_pipe_merges(buildingRotation, flip)
				mergeRecieves = var_to_str(get_grid_position(vectorMergeRecieves))
				var vectorGives = get_grid_coordinates(trueLocation) + MergePipe.get_gives(buildingRotation, flip)
				gives = var_to_str(get_grid_position(vectorGives))
			
			elif selectedBuilding == FactoryGlobal.splitPipe:
				canBuild = true
				buildingScene = "uid://dcktntwmsputu"
				nameBuilding = "Split Pipe"
				var vectorRecieves = get_grid_coordinates(trueLocation) + SplitPipe.get_recieves(buildingRotation, flip)
				recieves = var_to_str(get_grid_position(vectorRecieves))
				var vectorGives = get_grid_coordinates(trueLocation) + SplitPipe.get_gives(buildingRotation, flip)
				gives = var_to_str(get_grid_position(vectorGives))
				var vectorSplitGives = get_grid_coordinates(trueLocation) + SplitPipe.get_split_pipe_splits(buildingRotation, flip)
				splitGives = var_to_str(get_grid_position(vectorSplitGives))
			
			# After an underground pipe is placed, the end point must be placed
			# The gives value is set once the end is placed
			if selectedBuilding == FactoryGlobal.undergroundPipeStart:
				canBuild = true
				buildingScene = "uid://u56j8q2q6t43"
				nameBuilding = "Underground Pipe Start"
				var vectorRecieves = get_grid_coordinates(trueLocation) + NormalPipe.get_recieves(buildingRotation, flip)
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
				var vectorGives = get_grid_coordinates(trueLocation) + NormalPipe.get_gives(buildingRotation, flip)
				gives = var_to_str(get_grid_position(vectorGives))
				pipeInfo[undergroundLocation]["Gives"] = location
			
			if selectedBuilding == FactoryGlobal.vaporizer:
				canBuild = true
				buildingScene = "uid://ct6w6os54d0fy"
				nameBuilding = "Vaporizer"
				var vectorRecieves = get_grid_coordinates(trueLocation) + Vaporizer.get_recieves(buildingRotation, flip)
				recieves = var_to_str(get_grid_position(vectorRecieves))
				
			# Extractors can only be placed on resource tiles
			# The first check makes sure that it is overlapping it (a source)
			# Extractors are the only one to have an element value set on creation as well
			elif selectedBuilding == FactoryGlobal.extractor: 
				# Check where all the sources are
				for source in sourceArray:
					# Check to see if the buildingPreview overlaps with the source
					var sourceCoords := get_grid_coordinates(source.position)
					sourceCoords = get_grid_position(sourceCoords)
					
					if trueLocation == sourceCoords:
						canBuild = true
						buildingScene = "uid://dxqdm37qygx70"
						nameBuilding = "Extractor"
						var vectorGives = get_grid_coordinates(trueLocation) + Extractor.get_gives(buildingRotation, flip)
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
				phylacteryLocation = location
				buildingScene = "uid://rwrddigeppfh"
				nameBuilding = "Phylactery"
				var vectorRecieves = get_grid_coordinates(trueLocation) + Phylactery.get_recieves(buildingRotation, flip)
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
		if pipeInfo[location]["Name"] == "Phylactery":
			phylacteryLocation = var_to_str(Vector2.INF)
		for body in %Buildings.get_children():
			if body.position - FactoryGlobal.HALF_CELL_SIZE == str_to_var(location):
				pipeInfo.erase(location)
				body.queue_free()
				recalculate_factory()
				break

func select_building(index : int) -> void:
	pipeDragging = false
	copying = false
	selectionDragging = false
	var holder = get_node_or_null("Holder")
	if holder:
		holder.queue_free()
	
	if justBuiltBuildingUnderground == false:
		if selectedBuildingIndex != -1:
			selectedBuildingIndex = index
			selectedBuilding = FactoryGlobal.buildingArray[selectedBuildingIndex]
		else: 
			selectedBuilding = null
	else:
		selectedBuilding = FactoryGlobal.undergroundPipeEnd
	
	FactoryGlobal.selectedBuildingBetweenRooms = selectedBuilding
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
	
	if buildingPreviewInstance:
		buildingPreviewInstance.get_node("Sprite2D").rotate(deg_to_rad(direction))
	else:
		var holder = get_node_or_null("Holder")
		if holder:
			holder.rotate(deg_to_rad(direction))

func flip_building() -> void:
	if buildingPreviewInstance:
		if flip == false:
			buildingPreviewInstance.scale.x = -1
		else:
			buildingPreviewInstance.scale.x = 1
	else:
		var holder = get_node_or_null("Holder")
		if holder:
			if flip == false:
				holder.scale.x = -1
			else:
				holder.scale.x = 1
	
	flip = !flip

func display_pipe_info(location : String) -> void:
	var existingTooltip = get_node_or_null("PipeTooltip")
	if existingTooltip:
		existingTooltip.free()
	var tooltipScene = load("uid://cg3powp8taytw")
	var tooltip = tooltipScene.instantiate()
	tooltip.global_position = cursor_snap() + FactoryGlobal.CELL_SIZE + FactoryGlobal.HALF_CELL_SIZE
	get_parent().add_child(tooltip)
	var label = get_parent().get_node("PipeTooltip/Panel/MarginContainer/HBoxContainer/TooltipText")
	var labelText = ""
	for element in FactoryGlobal.elementArray:
		labelText = labelText + element + ": " + str(pipeInfo[location]["Elements"][element])
		if element != FactoryGlobal.elementArray[-1]:
			labelText = labelText + "\n"
	label.text = labelText
#endregion

#region Element Calculations
# Used to calculate how many resources are flowing through the pipes
# There are no throughput limits
# Any source connected to the phylactery is immediately counted. There's nothing based on time
# In other words, everything can be calculated immediately
func recalculate_factory():
	# Every non-extractor pipe needs to have its resource amounts reset
	for pipe in pipeInfo:
		if pipeInfo[pipe]["Name"] != "Extractor":
			for element in pipeInfo[pipe]["Elements"]:
				pipeInfo[pipe]["Elements"][element] = 0
		if pipeInfo[pipe].has("Looping"):
			pipeInfo[pipe].erase("Looping")
	
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

			# Sees if a path exists
			# If it does, get an array of pipes in the path
			# If it doesn't (returns empty array) do nothing
			var path = find_pipe_path(item, {}, item)
			if path != {}:
				# If a path is found, calculate how many resources are going through the pipe path
				calculate_flow(path)
	
	if phylacteryLocation == var_to_str(Vector2.INF):
		reset_factory_global_elements()
	else:
		var playerElements : Dictionary[String, float] = {}
		for element in FactoryGlobal.elementArray:
			playerElements[element] = pipeInfo[phylacteryLocation]["Elements"][element]
		FactoryGlobal.activePhylacteryValues[get_parent().name] = playerElements
		print("Water")
		print(pipeInfo[phylacteryLocation]["Elements"]["Water"])
	
	FactoryGlobal.activePipeLayout[get_parent().name] = pipeInfo.duplicate(true)
	FactoryGlobal.get_elements_total()

func find_pipe_path(item : String, pathDictionary : Dictionary[String, Dictionary], previousVertex : String) -> Dictionary[String, Dictionary]:
	var current = pipeInfo[item]
	var currentCoords : String = item
	var next : String = pipeInfo[item]["Gives"]
	var joiningPipes : Array[String] = []
	var pathFound : bool = false
	
	# Everything next to a splitter needs an extra check
	if is_endpoint(current["Name"]) == true:
		var connections : Array[String] = [currentCoords]
		
		if pathDictionary.has(previousVertex):
			connections = pathDictionary[previousVertex]["Connections"] + connections
			joiningPipes = pathDictionary[previousVertex]["Joining Pipes"] + joiningPipes
						
		pathDictionary[previousVertex] = {
			"Connections" : connections,
			"Joining Pipes" : joiningPipes,
			"Elements" : pipeInfo[previousVertex]["Elements"].duplicate()
		}
					
		pathDictionary[currentCoords] = {
			"Connections" : [],
			"Joining Pipes" : [],
			"Elements" : pipeInfo[currentCoords]["Elements"].duplicate()
		}
		joiningPipes.clear()
		pathFound = true
	
	elif current["Name"] == "Merge Pipe":
		var connections : Array[String] = [currentCoords]
		
		if pathDictionary.has(previousVertex):
			connections = pathDictionary[previousVertex]["Connections"] + connections
			joiningPipes = pathDictionary[previousVertex]["Joining Pipes"] + joiningPipes
		
		pathDictionary[previousVertex] = {
			"Connections" : connections,
			"Joining Pipes" : joiningPipes,
			"Elements" : pipeInfo[previousVertex]["Elements"].duplicate()
		}
		
		joiningPipes.clear()
		previousVertex = currentCoords
		
		# In case of a pipe that loops around
		if pathDictionary.has(currentCoords):
			pathFound = true
	
	elif current["Name"] == "Split Pipe":
		var connections : Array[String] = [currentCoords]
		
		if pathDictionary.has(previousVertex):
			connections = pathDictionary[previousVertex]["Connections"] + connections
			joiningPipes = pathDictionary[previousVertex]["Joining Pipes"] + joiningPipes
		
		pathDictionary[previousVertex] = {
			"Connections" : connections,
			"Joining Pipes" : joiningPipes,
			"Elements" : pipeInfo[previousVertex]["Elements"].duplicate()
		}
		
		joiningPipes.clear()
		previousVertex = currentCoords
		
		if pipeInfo.has(current["Split Gives"]):
			var splitDictionary = find_pipe_path(current["Split Gives"], pathDictionary, previousVertex)
			pathDictionary.merge(splitDictionary)
		
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
						"Elements" : pipeInfo[previousVertex]["Elements"].duplicate()
					}
					
					pathDictionary[pipe] = {
						"Connections" : [],
						"Joining Pipes" : [],
						"Elements" : pipeInfo[pipe]["Elements"].duplicate()
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
							"Elements" : pipeInfo[previousVertex]["Elements"].duplicate()
						}
							
						joiningPipes.clear()
						previousVertex = pipe
						
						# In case of a pipe that loops around
						if pathDictionary.has(pipe):
							pathFound = true
							break
						
					elif pipeInfo[pipe]["Name"] == "Split Pipe":
						var connections : Array[String] = [pipe]
					
						if pathDictionary.has(previousVertex):
							connections = pathDictionary[previousVertex]["Connections"] + connections
							joiningPipes = pathDictionary[previousVertex]["Joining Pipes"] + joiningPipes
						
						pathDictionary[previousVertex] = {
							"Connections" : connections,
							"Joining Pipes" : joiningPipes,
							"Elements" : pipeInfo[previousVertex]["Elements"].duplicate()
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
	
	if reachedEnd == true:
		return pathDictionary
	else:
		return {}

# First, verity path to endpoint exists
# Check if recursive pipe exists ^
# How to find recursive pipe loop ^
# Follow path. If you get to a merger that you've already been to, it's recursive ^
# If no recursive pipe loop, no shenigans :> <3
# If recursive pipe loop exists what do we need to know? 
# The starting merger so we can get the amount of element running through it ^
# The proportion going from that merger down into endpoints and what loops back @_@
# In order to get the proportion above I need to know which endpoints are connected to the merge pipe @_@
# General flow stuff - Mostly splitters <- This I should have in theory, might just need to do some extra to keep track of the extra bit flowing back to the start ^
# Need to know if there's another loop that affects the loop @_@
# How much of this can I already calculate?
# I can find pipe paths SO WELL
# General flow is fine - I can always tell when splitter need to split or when they are glorified turn pipes
# I can identify pipe loops - I can even determine which pipes are in them at about 99% (need 3 or more loops on one merger in order for it to break)
# -----
# What do I tell the computer?
# Right now, I calculate the path seperately and keep a record of its connections and elements
# What does this do for me?
# Makes it so I don't loop through the whole pipe dictionary - but I do this anyay to identify the extractors
# If I don't do it then every time I want to find a connection, I have to loop through the whole pipe dictionary - Which is what I do to identify the chain already
# The big thing it does is that it verifies ahead of time that there is a path that leads to an endpoint and recursive pipes
# Which means, I don't run any extra calculations if no path exists or if no recursive pipes exists
# Okay, is probably worth
# -----
# Do I need to keep track of the pipe loops themselves?
# The question is, will keeping detailed loop information help me find the endpoints?
# Tentatively, I don't think this does anything, but I'm not convinced
# So let's think about how I'm going to find which endpoints are connected to this merge pipe
# Modify initial path creation algorithm to focus on endpoints and the proprotion of element that goes into them
# Once I have the proportions (percentages) use 1 / (1 - proportion)
# -----
# Now for the extra cursed ones where the loop affects a different loop outside of it
# To determine whether different loops affect each other, see if root merger of other loop is in the path
# So getting the path helps - Make paths accurate only if I see the root merger in another loop
# Is there a good way to cull duplicate loops before determining if a loop affects another loop?
# Maybe write loop identifier to ignore the first splitter it comes across that's balanced?
# Maybe
# If I can, then we only find the whole path if there's loops that affec each other. Otherwise it's unnecessary
# If I can't, then I can check and see if I get lucky, but I might have split loops apart to find duplicates too
# Seems like regardless, I need a good way to identify all loops
# After that, use 1 / (1 - proportion) get get values, but do it a few times
func calculate_flow(path : Dictionary[String, Dictionary]) -> void:
	var loopList : Array[Array] = []
	var foundMergePipes : Array[String] = []
	
	for pipe in path:
		if pipeInfo[pipe]["Name"] != "Extractor":
			for element in path[pipe]["Elements"]:
				path[pipe]["Elements"][element] = 0
		path[pipe].erase("Looping")
	
	for pipe in path:
		if path[pipe]["Connections"] != []:
			if pipeInfo[pipe]["Name"] == "Split Pipe" and is_splitter_balanced(path, pipe):
				for connection in path[pipe]["Connections"]:
					if path.has(connection) == true and foundMergePipes.has(connection) == false:
						for element in path[pipe]["Elements"]:
							path[connection]["Elements"][element] += path[pipe]["Elements"][element] / 2
								
			else:
				for connection in path[pipe]["Connections"]:
					if path.has(connection) == true and foundMergePipes.has(connection) == false:
						for element in path[pipe]["Elements"]:
							path[connection]["Elements"][element] += path[pipe]["Elements"][element]
		
				if pipeInfo[pipe]["Name"] == "Merge Pipe":
					#print("^^^^^^^^^^^^^^^^^^^^^^^^^^^^^")
					#print("Checking for Recursive Pipe")
					#print("^^^^^^^^^^^^^^^^^^^^^^^^^^^^^")
					foundMergePipes.append(pipe)
					var mergerLoop : Array[String] =  check_for_pipe_loop(path, [], pipe, pipe)

					if mergerLoop!= []:
						#print("^^^^^^^^^^^^^^^^^^^^^^^^^^^^^")
						#print("Loop Complete")
						#print(mergerLoop)
						#print("^^^^^^^^^^^^^^^^^^^^^^^^^^^^^")
						loopList.append(mergerLoop)
	
	# Handling pipe loops
	if loopList != []:
		#print("-----------------------------------")
		#print("loopList Before")
		#print(loopList)
		#print("-----------------------------------")
		# Separate loops that are joined together because there's more than one recursive loop on the merger
		var loopsNeedFixing : Dictionary = {}
		for loopIndex in loopList.size():
			var fixIndicies : Array[int] = []
			for index in loopList[loopIndex].size():
				if index != loopList[loopIndex].size() - 1:
					if path[loopList[loopIndex][index]]["Connections"].has(loopList[loopIndex][index + 1]) == false:
						fixIndicies.append(index + 1)
			
			if fixIndicies != []:
				loopsNeedFixing[loopIndex] = fixIndicies
		#print("-----------------------------------")
		#print("loopsNeedFixing")
		#print(loopsNeedFixing)
		#print("-----------------------------------")
		
		# After splitting some loops aren't complete. Need to reconstruct them
		if loopsNeedFixing != {}:
			var splitLoops = []
			for loop in loopsNeedFixing:
				loopsNeedFixing[loop].reverse()
			
			for loop in loopsNeedFixing:
				for index in loopsNeedFixing[loop]:
					var splitLoop = loopList[loop].slice(index)
					loopList[loop] = loopList[loop].slice(0, index)
					
					var startLoop = []
					for pipe in loopList[loop]:
						startLoop.append(pipe)
						if path[pipe]["Connections"].has(splitLoop[0]):
							break
					
					startLoop.append_array(splitLoop)
					splitLoops.append(startLoop)
			
			var splitLoopsIndex : int = 0
			var indexOffset : int = 1
			var currentStartingMerger : String = splitLoops[0][0]
			for loop in loopsNeedFixing:
				if currentStartingMerger != splitLoops[splitLoopsIndex][0]:
					indexOffset += 1
				loopList.insert(splitLoopsIndex + indexOffset, splitLoops[splitLoopsIndex])
				currentStartingMerger = splitLoops[splitLoopsIndex][0]
				splitLoopsIndex += 1
			
			for loopIndex in loopList.size():
				if path[loopList[loopIndex][-1]]["Connections"].has(loopList[loopIndex][0]) == false:
					print("Loops still broke")
					
		#print("-----------------------------------")
		#print("loopList After Loop Split")
		#print(loopList)
		#print("-----------------------------------")
		
		# Remove duplicate loops
		# If there's more than one merger in the path this often results in loops that use identical pipes
		var sortedLoopList = loopList.duplicate(true)
		for list in sortedLoopList:
			list.sort()
		
		var seenArrays = []
		var removeArrays = []
		for index in sortedLoopList.size():
			if seenArrays.has(sortedLoopList[index]):
				removeArrays.append(index)
			else:
				seenArrays.append(sortedLoopList[index])
		
		removeArrays.reverse()
		for index in removeArrays:
			loopList.remove_at(index)
		
		#print("-----------------------------------")
		#print("loopList After Duplicate Prune")
		#print(loopList)
		#print("-----------------------------------")
		
		# Remove any useless loops
		# All loops should reach an end point
		removeArrays.clear()
		var loopIndex = -1
		for loop in loopList:
			loopIndex += 1
			var foundExit : bool = false
			var recentSplitter : String = ""
			#print("------------------")
			#print("Checking if loop goes outside")
			#print(loop)
			
			for pipe in loop:
				if foundExit == true:
					break
				if path[pipe]["Connections"].size() == 2:
					#print("Recent Splitter")
					#print(recentSplitter)
					if recentSplitter != "":
						for connection in path[pipe]["Connections"]:
							if loop.has(connection) == false:
								#print("Connection")
								#print(connection)
								#print(does_path_exist(connection, []))
								#print("---")
								if does_path_exist(connection, []) == true:
									#print("Found something outside")
									#print("------------------")
									foundExit = true
									break
				
				if recentSplitter == "" and pipeInfo[pipe]["Name"] == "Split Pipe":
					recentSplitter = pipe
				if foundExit == false and pipe == loop[-1]:
					#print("Did not find something outside")
					#print("------------------")
					removeArrays.append(loopIndex)

		removeArrays.reverse()
		for index in removeArrays:
			loopList.remove_at(index)
		print("-----------------------------------")
		print("loopList After Useless Prune")
		print(loopList)
		print("-----------------------------------")
		
		# Get remaining starting mergers
		var startingMergerList : Array[String] = []
		for loop in loopList:
			if startingMergerList.has(loop[0]) == false:
				startingMergerList.append(loop[0])
		
		var seenStartingMergers : Array[String] = []
		var relevantStartingMergers : Array[String] = startingMergerList.duplicate()
		var atLastIndex : bool = false
		var isOverlappingLoops : bool = false
		var allLoopPercentages : Array[float] = []
		var uselessLoops : Array[int] = []
		for index in loopList.size():
			if index == loopList.size() - 1:
				atLastIndex = true
			if seenStartingMergers.has(loopList[index][0]) == false \
			and (atLastIndex == true or loopList[index][0] != loopList[index + 1][0]):
				var removeIndex : Array[int] = []
				for pipeIndex in relevantStartingMergers.size():
					if loopList[index].has(relevantStartingMergers[pipeIndex]):
						removeIndex.append(pipeIndex)
				
				if removeIndex != []:
					removeIndex.reverse()
					for removePipe in removeIndex:
						relevantStartingMergers.remove_at(removePipe)
				
				seenStartingMergers.append(loopList[index][0])
				if path[loopList[index][0]].has("Looping") == false:
					path[loopList[index][0]]["Looping"] = {}
				var connectedEndPoints : Array[String] = find_endpoint_from_merger(path, [], relevantStartingMergers, loopList[index][0], loopList[index][0])
				if connectedEndPoints != []:
					var loopPercentage : float = 1
					for endpoint in connectedEndPoints:
						var exampleElement : String
						for element in path[endpoint]["Elements"]:
							if path[endpoint]["Elements"][element] > 0:
								exampleElement = element
								break
						
						var endpointPercentage : float = path[endpoint]["Elements"][exampleElement] / path[loopList[index][0]]["Elements"][exampleElement]
						loopPercentage -= endpointPercentage
					
					if loopPercentage < 1:
						allLoopPercentages.append(loopPercentage)
						path[loopList[index][0]]["Looping"].set(index, {"Water" : 0, "Fire" : 0, "Air" : 0, "Earth" : 0})
						for element in path[loopList[index][0]]["Elements"]:
							path[loopList[index][0]]["Looping"][index][element] = path[loopList[index][0]]["Elements"][element] * loopPercentage * (1 / (1 - loopPercentage))
						print("=======================")
						print("Loop Percentage")
						print(loopPercentage * (1 / (1 - loopPercentage)))
						print(path[loopList[index][0]]["Elements"])
						print(loopPercentage)
						print(path[loopList[index][0]]["Looping"])
						print("=======================")
				else:
					uselessLoops.append(index)
				
				relevantStartingMergers = startingMergerList.duplicate()
			else:
				var removeIndex : Array[int] = []
				for pipeIndex in relevantStartingMergers.size():
					if loopList[index].has(relevantStartingMergers[pipeIndex]):
						removeIndex.append(pipeIndex)
				
				if removeIndex != []:
					removeIndex.reverse()
					for removePipe in removeIndex:
						relevantStartingMergers.remove_at(removePipe)
		
		if uselessLoops != []:
			uselessLoops.reverse()
			for index in uselessLoops:
				loopList.remove_at(index)
		
		startingMergerList.clear()
		for loop in loopList:
			if startingMergerList.has(loop[0]) == false:
				startingMergerList.append(loop[0])
		
		for startingPipe in startingMergerList:
			for loop in loopList:
				if startingPipe != loop[0]:
					if loop.has(startingPipe):
						isOverlappingLoops = true
		
		propogate_pipe_loop(path, startingMergerList)

		if isOverlappingLoops == true:
			var percentageIndex = -1
			atLastIndex = false
			seenStartingMergers.clear()
			var reversedPath : Array[String] = []
			for pipe in path:
				reversedPath.append(pipe)
			# Make sure the loop values get everywhere they need to go
			# And I mean EVERYWHERE
			for index in loopList.size():
				print("*****")
				print("Loop index")
				print(index)
				print(path[loopList[index][0]]["Looping"])
				reversedPath.reverse()
				for pipe in reversedPath:
					if path[pipe].has("Looping") and path[pipe].has("Connections"):
						for connection in path[pipe]["Connections"]:
							if path[connection].has("Looping") == false:
								path[connection]["Looping"] = path[pipe]["Looping"].duplicate(true)
								if is_splitter_balanced(path, pipe) == true:
									for element in path[pipe]["Elements"]:
										path[connection]["Looping"][index][element] = path[pipe]["Looping"][index][element] / 2
							
							for loopNumber in path[pipe]["Looping"]:
								if path[connection]["Looping"].has(loopNumber) == false:
									path[connection]["Looping"][loopNumber] = path[pipe]["Looping"][loopNumber].duplicate(true)
									if is_splitter_balanced(path, pipe) == true:
										for element in path[pipe]["Elements"]:
											path[connection]["Looping"][loopNumber][element] = path[pipe]["Looping"][loopNumber][element] / 2
				#for pipe in path:
					#if path[pipe].has("Looping") and path[pipe].has("Connections"):
						#for connection in path[pipe]["Connections"]:
							#if path[connection].has("Looping") == false:
								#path[connection]["Looping"] = path[pipe]["Looping"].duplicate(true)
								#if is_splitter_balanced(path, pipe) == true:
									#for element in path[pipe]["Elements"]:
										#path[connection]["Looping"][index][element] = path[pipe]["Looping"][index][element] / 2
							#
							#for loopNumber in path[pipe]["Looping"]:
								#if path[connection]["Looping"].has(loopNumber) == false:
									#path[connection]["Looping"][loopNumber] = path[pipe]["Looping"][loopNumber].duplicate(true)
									#if is_splitter_balanced(path, pipe) == true:
										#for element in path[pipe]["Elements"]:
											#path[connection]["Looping"][loopNumber][element] = path[pipe]["Looping"][loopNumber][element] / 2
				#
				if index == loopList.size() - 1:
					atLastIndex = true
				if seenStartingMergers.has(loopList[index][0]) == false \
				and (atLastIndex == true or loopList[index][0] != loopList[index + 1][0]):
					print("===============")
					print("Looping Shenanigans")
					print(path[loopList[index][0]]["Looping"])
					foundMergePipes.append(loopList[index][0])
					percentageIndex += 1
					
					if path[loopList[index][0]].has("Looping"):
						if path[loopList[index][0]]["Looping"].has(index):
							for element in path[loopList[index][0]]["Elements"]:
								path[loopList[index][0]]["Looping"][index][element] = path[loopList[index][0]]["Looping"][index][element] * allLoopPercentages[percentageIndex] * (1 / (1 - allLoopPercentages[percentageIndex]))
						
						if path[loopList[index][0]]["Looping"].size() > 1:
							for pipeLoop in path[loopList[index][0]]["Looping"]:
								if pipeLoop != index:
									var otherMerger = loopList[pipeLoop][0]
									print(otherMerger)
									if path[otherMerger].has("Looping"):
										if path[otherMerger]["Looping"].has(pipeLoop):
											var exampleElement : String
											for element in path[loopList[index][0]]["Elements"]:
												if path[loopList[index][0]]["Elements"][element] > 0:
													exampleElement = element
													break
											var loopRatio : float = path[otherMerger]["Looping"][pipeLoop][exampleElement] / (path[otherMerger]["Looping"][pipeLoop][exampleElement] - path[loopList[index][0]]["Looping"][pipeLoop][exampleElement])
											print(loopRatio)
											print("Looping Before")
											print(path[loopList[index][0]]["Looping"])
											for element in path[loopList[index][0]]["Elements"]:
												path[loopList[index][0]]["Looping"][pipeLoop][element] = loopRatio * path[loopList[index][0]]["Looping"][pipeLoop][element]
						print(pipeInfo[loopList[index][0]]["Name"] + "(" + str(pipeInfo[loopList[index][0]]["X"]) + ", " + str(pipeInfo[loopList[index][0]]["Y"]) + ")")
						print("Looping After")
						print(path[loopList[index][0]]["Looping"])
						print("===============")
				
			# Clear for repropgation
			for pipe in path:
				if path[pipe].has("Looping") and startingMergerList.has(pipe) == false:
					for index in path[pipe]["Looping"]:
						if path[pipe]["Looping"].has(index):
							for element in path[pipe]["Elements"]:
								path[pipe]["Looping"][index][element] = 0

			propogate_pipe_loop(path, startingMergerList)
			# Propogate EXTRA THOROUGHLY
			for pipe in reversedPath:
				if path[pipe].has("Looping") and path[pipe].has("Connections"):
					for connection in path[pipe]["Connections"]:
						if path[connection].has("Looping") == false:
							path[connection]["Looping"] = path[pipe]["Looping"].duplicate(true)
							if is_splitter_balanced(path, pipe) == true:
								for index in path[connection]["Looping"]:
									for element in path[pipe]["Elements"]:
										path[connection]["Looping"][index][element] = path[pipe]["Looping"][index][element] / 2
						
						for loopNumber in path[pipe]["Looping"]:
							if path[connection]["Looping"].has(loopNumber) == false:
								path[connection]["Looping"][loopNumber] = path[pipe]["Looping"][loopNumber].duplicate(true)
								if is_splitter_balanced(path, pipe) == true:
									for index in path[connection]["Looping"]:
										for element in path[pipe]["Elements"]:
											path[connection]["Looping"][loopNumber][element] = path[pipe]["Looping"][loopNumber][element] / 2
			#var loopCounter : int = 0
			#while loopCounter <= 4:
				#var percentageIndex = -1
				#atLastIndex = false
				#seenStartingMergers.clear()
				#print("===================")
				#print("Loop: " + str(loopCounter))
				## Make sure the loop values have been propogated everywhere they need to
				## And I mean EVERYWHERE
				#for index in loopList.size():
					#for pipe in loopList[index]:
						#if path[pipe].has("Looping") and path[pipe].has("Connections"):
							#for connection in path[pipe]["Connections"]:
								#if path[connection].has("Looping") == false:
									#path[connection]["Looping"] = path[pipe]["Looping"].duplicate(true)
								#
								#for loopNumber in path[pipe]["Looping"]:
									#if path[connection]["Looping"].has(loopNumber) == false:
										#path[connection]["Looping"][loopNumber] = path[pipe]["Looping"][loopNumber].duplicate(true)
									#
					#if index == loopList.size() - 1:
						#atLastIndex = true
					#if seenStartingMergers.has(loopList[index][0]) == false \
					#and (atLastIndex == true or loopList[index][0] != loopList[index + 1][0]):
						#percentageIndex += 1
						#print("************************")
						#print("Starting Mergers Looping")
						#print(path[loopList[index][0]]["Looping"])
						#print(percentageIndex)
						#print("************************")
						#if path[loopList[index][0]].has("Looping"):
							#if path[loopList[index][0]]["Looping"].has(index):
								#for element in path[loopList[index][0]]["Elements"]:
									#path[loopList[index][0]]["Looping"][index][element] = path[loopList[index][0]]["Looping"][index][element] * allLoopPercentages[percentageIndex] * (1 / (1 - allLoopPercentages[percentageIndex]))
						#
						#seenStartingMergers.append(loopList[index][0])
				#
					#for pipe in path:
						##if pipeInfo[pipe]["Name"] == "Phylactery":
							##print("=====================")
							##print("Phylactery")
							##print(path[pipe])
							##print("----")
						#if path[pipe].has("Looping"):
							#if path[pipe]["Looping"].has(index) and pipe != loopList[index][0]:
								#path[pipe]["Looping"].erase(index)
							#
							#if path[pipe]["Looping"] == {}:
								#path[pipe].erase("Looping")
				#
				#propogate_pipe_loop(path)
				#loopCounter += 1
			#var loopPercentageIndex : int = -1
			#atLastIndex = false
			#for index in loopList.size():
				#if index == loopList.size() - 1:
					#atLastIndex = true
				#if seenStartingMergers.has(loopList[index][0]) == false \
				#and (atLastIndex == true or loopList[index][0] != loopList[index + 1][0]):
					#loopPercentageIndex += 1
					#if allLoopPercentages[loopPercentageIndex] < 1:
						#for element in path[loopList[index][0]]["Elements"]:
							#path[loopList[index][0]]["Looping"][index][element] = path[loopList[index][0]]["Looping"][index][element] + (path[loopList[index][0]]["Looping"][index][element] * allLoopPercentages[loopPercentageIndex] * (1 / (1 - allLoopPercentages[loopPercentageIndex])))
					#seenStartingMergers.append(loopList[index][0])
					#print("------")
					#print(path[loopList[index][0]]["Looping"])
					#print("------")
					#
					#for pipe in path:
						##if pipeInfo[pipe]["Name"] == "Phylactery":
							##print("=====================")
							##print("Phylactery")
							##print(path[pipe])
							##print("----")
						#if path[pipe].has("Looping"):
							#if path[pipe]["Looping"].has(index) and pipe != loopList[index][0]:
								#path[pipe]["Looping"].erase(index)
							#
							#if path[pipe]["Looping"] == {}:
								#path[pipe].erase("Looping")
						#
						##if pipeInfo[pipe]["Name"] == "Phylactery":
							##print(path[pipe])
							##print("=====================")
			##for pipe in path:
				##if seenStartingMergers.has(pipe) == false and path[pipe].has("Looping"):
					##for index in path[pipe]["Looping"]:
						##for element in path[pipe]["Looping"][index]:
							##path[pipe]["Looping"][index][element] = 0
		#print("*******************")
	print("+++++++++++++++++++++++++++++++++")
	for pipe in path:
		if pipeInfo[pipe]["Name"] != "Extractor":
			for element in path[pipe]["Elements"]:
				pipeInfo[pipe]["Elements"][element] += path[pipe]["Elements"][element]

		if path[pipe].has("Looping") == true:
			pipeInfo[pipe]["Looping"] = path[pipe]["Looping"].duplicate(true)
			if is_endpoint(pipeInfo[pipe]["Name"]) == true:
				print("#################")
				print("Endpoint Before Looping Merge")
				print(pipeInfo[pipe]["Elements"])
				print("#################")
				for index in pipeInfo[pipe]["Looping"]:
					for element in pipeInfo[pipe]["Elements"]:
						pipeInfo[pipe]["Elements"][element] += pipeInfo[pipe]["Looping"][index][element]
					
		
		if path[pipe]["Joining Pipes"] != []:
			for edge in path[pipe]["Joining Pipes"]:
				for element in pipeInfo[pipe]["Elements"]:
					pipeInfo[edge]["Elements"][element] += pipeInfo[pipe]["Elements"][element]
					
				if path[pipe].has("Looping") == true:
					pipeInfo[edge]["Looping"] = pipeInfo[pipe]["Looping"].duplicate(true)
	
		print("--------------------")
		print(pipeInfo[pipe]["Name"] + "(" + str(pipeInfo[pipe]["X"]) + ", " + str(pipeInfo[pipe]["Y"]) + ")")
		print(pipeInfo[pipe]["Elements"])
		if pipeInfo[pipe].has("Looping"):
			print(pipeInfo[pipe]["Looping"])
		print("--------------------")

func is_splitter_balanced(path : Dictionary[String, Dictionary], startingPipe : String) -> bool:
	var connections = path[startingPipe]["Connections"]

	if connections.size() != 2:
		return false
	
	var firstConnection : String = connections[0]
	var secondConnection : String = connections[1]
	
	if path.has(firstConnection) == false or path.has(secondConnection) == false:
		return false
	
	if path[firstConnection].has("Connections") == false or path[secondConnection].has("Connections") == false:
		return false
	
	if path[firstConnection]["Connections"].has(startingPipe) or path[secondConnection]["Connections"].has(startingPipe):
		return false
	elif does_path_exist(firstConnection, []) == true:
		if does_path_exist(secondConnection, []) == true:
			return true
		else:
			var isLooping : Array[String] = check_for_pipe_loop(path, [], secondConnection, secondConnection)
			if isLooping != []:
				var loopReachesEnd : bool = does_loop_reach_end(path, [], secondConnection, secondConnection)
				if loopReachesEnd == true:
					return true
				else:
					return false
			else: 
				return false
	elif does_path_exist(secondConnection, []) == true:
		var isLooping : Array[String] = check_for_pipe_loop(path, [], firstConnection, firstConnection)
		if isLooping != []:
			var loopReachesEnd : bool = does_loop_reach_end(path, [], firstConnection, firstConnection)
			if loopReachesEnd == true:
				return true
			else:
				return false
		else: 
			return false
	else:
		var isLoopingFirstConnection : Array[String] = check_for_pipe_loop(path, [], firstConnection, firstConnection)
		var isLoopingSecondConnection : Array[String] = check_for_pipe_loop(path, [], secondConnection, secondConnection)
		if isLoopingFirstConnection != [] and isLoopingSecondConnection != []:
			var loopReachesEndFirstConnection : bool = does_loop_reach_end(path, [], firstConnection, firstConnection)
			var loopReachesEndSecondConnection : bool = does_loop_reach_end(path, [], secondConnection, secondConnection)
			if loopReachesEndFirstConnection == true and loopReachesEndSecondConnection == true:
				return true
			else:
				return false
		else:
			return false

func check_for_pipe_loop(path : Dictionary[String, Dictionary], parentSplitters : Array[String], startingPipe : String, mergePipeCheck : String) -> Array[String]:
	var mergePath : Array[String] = []
	var check : String = startingPipe
	var foundPath : bool = false
	var firstLoop : bool = true
	
	while foundPath == false:
		foundPath = true
		#if mergePath.has(check) == false:
		mergePath.append(check)
		
		if path.has(check):
			if path[check]["Connections"] != []:
				if parentSplitters.has(check):
					return []
				elif path[check]["Connections"].has(mergePipeCheck):
					if path[check]["Connections"].size() == 2 and parentSplitters.has(check) == false:
						var mergePipeCheckIndex : int = path[check]["Connections"].find(mergePipeCheck)
						var splitterOtherSide : int = 0
						if mergePipeCheckIndex == 0:
							splitterOtherSide = 1
						parentSplitters.append(check)
						var splitMergeList = check_for_pipe_loop(path, parentSplitters, path[check]["Connections"][splitterOtherSide], mergePipeCheck)
						#for item in splitMergeList:
							#if mergePath.has(item) == false:
								#mergePath.append(item)
						mergePath.append_array(splitMergeList)
					
					return mergePath
				elif check == startingPipe and check != mergePipeCheck and firstLoop == false:
					return []
				elif path[check]["Connections"].size() == 2:
					parentSplitters.append(check)
					var splitMergeListFirst = check_for_pipe_loop(path, parentSplitters, path[check]["Connections"][0], mergePipeCheck)
					var splitMergeListSecond = check_for_pipe_loop(path, parentSplitters, path[check]["Connections"][1], mergePipeCheck)
					parentSplitters.remove_at(-1)
					
					if splitMergeListFirst == [] and splitMergeListSecond == []:
						return []
					else:
						mergePath.append_array(splitMergeListFirst)
						mergePath.append_array(splitMergeListSecond)
						#for item in splitMergeListFirst:
							#if mergePath.has(item) == false:
								#mergePath.append(item)
						#
						#for item in splitMergeListSecond:
							#if mergePath.has(item) == false:
								#mergePath.append(item)
				else:
					foundPath = false
					check = path[check]["Connections"][0]
			else: 
				return []
		else:
			return []
		
		firstLoop = false
	
	return mergePath

func find_endpoint_from_merger(path : Dictionary[String, Dictionary], parentSplitters : Array[String], startingMergerList : Array[String], startingPipe : String, mergePipeCheck : String) -> Array[String]:
	var endpointArray : Array[String] = []
	var foundPath : bool = false
	var check = startingPipe
	var firstLoop : bool = true
	
	while foundPath == false:
		foundPath = true
		if is_endpoint(pipeInfo[check]["Name"]):
			endpointArray.append(check)
		elif startingMergerList.has(check) and firstLoop == false:
			return []
		else:
			if path.has(check):
				if path[check]["Connections"] != []:
					if parentSplitters.has(check):
						return []
					elif path[check]["Connections"].has(mergePipeCheck):
						if path[check]["Connections"].size() == 2 and parentSplitters.has(check) == false:
							var mergePipeCheckIndex : int = path[check]["Connections"].find(mergePipeCheck)
							var splitterOtherSide : int = 0
							if mergePipeCheckIndex == 0:
								splitterOtherSide = 1
							parentSplitters.append(check)
							var splitMergeList = find_endpoint_from_merger(path, parentSplitters, startingMergerList, path[check]["Connections"][splitterOtherSide], mergePipeCheck)
							for item in splitMergeList:
								if endpointArray.has(item) == false:
									endpointArray.append(item)
					
						return endpointArray
					elif check == startingPipe and check != mergePipeCheck and firstLoop == false:
						return []
					elif path[check]["Connections"].size() == 2:
						parentSplitters.append(check)
						var splitMergeListFirst = find_endpoint_from_merger(path, parentSplitters, startingMergerList, path[check]["Connections"][0], mergePipeCheck)
						var splitMergeListSecond = find_endpoint_from_merger(path, parentSplitters, startingMergerList, path[check]["Connections"][1], mergePipeCheck)
						parentSplitters.remove_at(-1)
						
						if splitMergeListFirst == [] and splitMergeListSecond == []:
							return []
						else:
							for item in splitMergeListFirst:
								if endpointArray.has(item) == false:
									endpointArray.append(item)
							
							for item in splitMergeListSecond:
								if endpointArray.has(item) == false:
									endpointArray.append(item)
					else:
						foundPath = false
						check = path[check]["Connections"][0]
				else:
					return []
			else:
				return []
		
		firstLoop = false

	return endpointArray

func does_loop_reach_end(path : Dictionary[String, Dictionary], parentSplitters : Array[String], startingPipe : String, mergePipeCheck : String) -> bool:
	var foundPath : bool = false
	var check = startingPipe
	var firstLoop : bool = true
	
	while foundPath == false:
		foundPath = true
		if is_endpoint(pipeInfo[check]["Name"]):
			return true
		else:
			if path.has(check):
				if path[check]["Connections"] != []:
					if parentSplitters.has(check):
						return false
					elif path[check]["Connections"].has(mergePipeCheck):
						if path[check]["Connections"].size() == 2 and parentSplitters.has(check) == false:
							var mergePipeCheckIndex : int = path[check]["Connections"].find(mergePipeCheck)
							var splitterOtherSide : int = 0
							if mergePipeCheckIndex == 0:
								splitterOtherSide = 1
							parentSplitters.append(check)
							if does_loop_reach_end(path, parentSplitters, path[check]["Connections"][splitterOtherSide], mergePipeCheck) == true:
								return true
							else:
								return false
					elif check == startingPipe and check != mergePipeCheck and firstLoop == false:
						return false
					elif path[check]["Connections"].size() == 2:
						parentSplitters.append(check)
						var doesFirstConnectionReachEnd : bool = does_loop_reach_end(path, parentSplitters, path[check]["Connections"][0], mergePipeCheck)
						var doesSecondConnectionReachEnd : bool = does_loop_reach_end(path, parentSplitters, path[check]["Connections"][1], mergePipeCheck)
						parentSplitters.remove_at(-1)
						
						if doesFirstConnectionReachEnd  == true and doesSecondConnectionReachEnd == true:
							return true
						else: 
							return false
					else:
						foundPath = false
						check = path[check]["Connections"][0]
				else:
					return false
			else:
				return false
		
		firstLoop = false

	return true

func propogate_pipe_loop(path : Dictionary, startingMergerList : Array[String]) -> void:
	var foundStartingMerger : Array[String] = []
	var isFoundPipe : bool = false
	print("Starting Merger List")
	print(startingMergerList)
	
	for pipe in path:
		if path[pipe].has("Looping") == true:
			if pipeInfo[pipe]["Name"] == "Split Pipe" and is_splitter_balanced(path, pipe):
				for connection in path[pipe]["Connections"]:
					if foundStartingMerger.has(connection):
						isFoundPipe = true
					if path.has(connection) == true and isFoundPipe == false:
						if path[connection].has("Looping") == false:
							path[connection]["Looping"] = path[pipe]["Looping"].duplicate(true)
							for loop in path[pipe]["Looping"]:
								for element in path[pipe]["Elements"]:
									path[connection]["Looping"][loop][element] = 0
			
						for loop in path[pipe]["Looping"]:
							if path[connection]["Looping"].has(loop) == false:
								path[connection]["Looping"][loop] = path[pipe]["Looping"][loop].duplicate(true)
								for element in path[pipe]["Elements"]:
									path[connection]["Looping"][loop][element] = 0
							
							for element in path[pipe]["Elements"]:
								path[connection]["Looping"][loop][element] += path[pipe]["Looping"][loop][element] / 2
			
			else:
				for connection in path[pipe]["Connections"]:
					if foundStartingMerger.has(connection):
						isFoundPipe = true
					if path.has(connection) == true and isFoundPipe == false:
						if path[connection].has("Looping") == false:
							path[connection]["Looping"] = path[pipe]["Looping"].duplicate(true)
							for loop in path[pipe]["Looping"]:
								for element in path[pipe]["Elements"]:
									path[connection]["Looping"][loop][element] = 0
						
						for loop in path[pipe]["Looping"]:
							if path[connection]["Looping"].has(loop) == false:
								path[connection]["Looping"][loop] = path[pipe]["Looping"][loop].duplicate(true)
								for element in path[pipe]["Elements"]:
									path[connection]["Looping"][loop][element] = 0
							
							for element in path[pipe]["Elements"]:
								path[connection]["Looping"][loop][element] += path[pipe]["Looping"][loop][element]
			#print("-----------------------------------")
			#print("Looping")
			#print(pipeInfo[pipe]["Name"] + "(" + str(pipeInfo[pipe]["X"]) + ", " + str(pipeInfo[pipe]["Y"]) + ")")
			#print(path[pipe]["Looping"])
			#print("-----------------------------------")
			
		if startingMergerList.has(pipe):
			foundStartingMerger.append(pipe)
		isFoundPipe = false
			
	for pipe in path:
		print("-----------------------------------")
		print("Looping")
		print(pipeInfo[pipe]["Name"] + "(" + str(pipeInfo[pipe]["X"]) + ", " + str(pipeInfo[pipe]["Y"]) + ")")
		if path[pipe].has("Looping"):
			print(path[pipe]["Looping"])
		print("-----------------------------------")

func is_endpoint(pipeName : String) -> bool:
	if pipeName == "Phylactery" \
	or pipeName == "Vaporizer":
		return true
	else: 
		return false

func does_path_exist(item : String, mergerList : Array[String]) -> bool:
	# The current pipe being checked
	var current = pipeInfo[item]
	
	# x, y coordinates of the current pipe
	var currentCoords = item
	
	# The previous pipe being looked at - null on the first pass, gets updated every loop
	var previous = null
	
	# The pipe properties that need to be checked
	var check = pipeInfo[item]["Name"]
	var next = pipeInfo[item]["Gives"]
	# Need an extra check in case starting pipe is splitter
	if is_endpoint(check) == true:
		return true
	elif check == "Split Pipe":
		if pipeInfo.has(pipeInfo[item]["Split Gives"]):
			if does_path_exist(pipeInfo[item]["Split Gives"], mergerList) == true:
				return true
	
	# Check to see if you've gotten to the Phylactery
	while true:
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

func reset_factory_global_elements() -> void:
	FactoryGlobal.activePhylacteryValues.erase(get_parent().name)
#endregion
