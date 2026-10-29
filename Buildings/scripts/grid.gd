class_name Grid extends Node2D

#region General Globals
# Grid Information
@export var GRID_SIZE := Vector2(1150, 1000)
var CELL_AMOUNT : Vector2
var menuOffset : Vector2

var sourceArray : Array[Source] = []
var exitArray : Array[PipeExit] = []
var usedExitsArray : Array[PipeExit] = []
var exitPipesArray : Array[String] = []
var waitForBlueprintMenuClose : bool = false
#endregion

#region Build Mode Information
var selectedBuilding
var selectedBuildingIndex
var buildingPreviewInstance
var pipeInfo : Dictionary
var buildingRotation : int = 0
var flip : bool = false
var phylacteryLocations : Dictionary[String, String] = {}
var flowMarginOfError : float = 0.01
#endregion

#region Preview for Pipe Dragging Path
var pipeDragging : bool = false
var forceBuild : bool = false
var preDragBuilding
var preDragBuildingIndex : int
var preDragBuildingRotation : int
var preDragBuildingFlip : bool
var previewDirection := Vector2.INF
var previewStart := Vector2.INF
var currentDragLocation := Vector2.INF
var previousPlayerLocation := Vector2.INF
var currentPreview := Vector2.INF
var previewEnd := Vector2.INF
var makingIllegalMove : bool = false
var illegalMoveCursorPosition := Vector2.INF
var reversePath : bool = false
var transformPipe : bool = false
var draggedPathPipes : Array[Vector2] = []
var overlappingPipes : Array[Vector2] = []
var outsideBuildAreaPipes : Array[Vector2] = []
var anchorPointsDictionary : Dictionary[Vector2, Vector2] = {}
var anchorPointsArray : Array[Vector2]
#endregion

#region For Selecting Pipes
var selectionDragging : bool = false
var copying : bool = false
var selectedPipes : Array = []
var selectedBodies : Array = []
var highlightedPipes : Array = []
var selectionDragStart := Vector2.ZERO
var selectionDragStartSnapped := Vector2.ZERO
var selectionRect := RectangleShape2D.new()
var gridParent 
#endregion

func _ready() -> void:
	# calculate grid size
	CELL_AMOUNT = Vector2(GRID_SIZE.x / FactoryGlobal.CELL_SIZE.x, GRID_SIZE.y / FactoryGlobal.CELL_SIZE.y)
	menuOffset = Vector2(0, 0)
	gridParent = get_parent()
	
	if FactoryGlobal.isGridOn == true:
		self.show()
	else:
		self.hide()
	
	#region Create the building preview
	selectedBuilding = FactoryGlobal.selectedBuildingBetweenRooms
	selectedBuildingIndex = FactoryGlobal.selectedBuildingIndexBetweenRooms
	buildingRotation = FactoryGlobal.rotationBetweenRooms
	flip = FactoryGlobal.flipBetweenRooms
	if selectedBuilding:
		buildingPreviewInstance = selectedBuilding.instantiate()
		buildingPreviewInstance.get_node("Sprite2D").rotate(deg_to_rad(buildingRotation))
		if flip == true:
			buildingPreviewInstance.scale.x = -1
		add_child(buildingPreviewInstance)
		buildingPreviewInstance.modulate.a = 0.7
	#endregion

	#region Add Sources to sourceArray
	for source in %Sources.get_children():
		if source is Source:
			sourceArray.append(source)
	#endregion
	
	var exits = get_node_or_null("Exits")
	if exits:
		for exit in %Exits.get_children():
			if exit is PipeExit:
				exitArray.append(exit)
	
	#region Rebuild Factory
	if FactoryGlobal.activePipeLayout.has(get_parent().name):
		pipeInfo = FactoryGlobal.activePipeLayout[get_parent().name].duplicate(true)
		for pipe in pipeInfo:
			var buildingScene = null
			while not buildingScene:
				buildingScene = load(pipeInfo[pipe]["Scene"])
				await get_tree().process_frame
			
			var building = buildingScene.instantiate()
			building.position = Vector2(pipeInfo[pipe]["X"], pipeInfo[pipe]["Y"]) + FactoryGlobal.HALF_CELL_SIZE
			if pipeInfo[pipe]["Flip"] == true:
				building.scale.x = -1
			building.get_node("Sprite2D").rotate(deg_to_rad(pipeInfo[pipe]["Rotation"]))
			building.add_to_group("Buildings")
			%Buildings.add_child(building)
			
			for exit in exitArray:
				var exitCoords := get_grid_coordinates(exit.position)
				exitCoords = get_grid_position(exitCoords)
						
				if exitCoords == str_to_var(pipe):
					handle_room_transition_pipes(pipeInfo[pipe]["Name"], pipeInfo[pipe]["Gives"], pipeInfo[pipe]["Recieves"], exit)
			
		#recalculate_factory(pipeInfo, get_parent().name, {}, true)
		#finalize_elements()
		#finalize_global_dictionaries()
		#endregion

func _process(_delta: float) -> void:
	if waitForBlueprintMenuClose == true:
		waitForBlueprintMenuClose = false
	
	# Dig into how signals work
	# Test with like 1000 pipes - Draws too slowly, how do I get them all to draw at once?
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
		var currentCursorLocation = cursor_snap()
		var playerLocation = get_player_location()
		
		if (previewEnd == Vector2.INF \
		and (currentDragLocation.distance_to(currentCursorLocation) >= FactoryGlobal.CELL_SIZE.x \
		or currentDragLocation.distance_to(currentCursorLocation) >= FactoryGlobal.CELL_SIZE.y)) \
		or (playerLocation != previousPlayerLocation):
			currentDragLocation = currentCursorLocation
			previousPlayerLocation = playerLocation
			draggedPathPipes.clear()
			overlappingPipes.clear()
			outsideBuildAreaPipes.clear()
			create_preview_path()
			if currentPreview != Vector2.INF:
				if anchorPointsDictionary != {} and anchorPointsArray != []:
					var startPoint : Vector2
					var endPoint : Vector2
					var pipeDirection : Vector2
					var previousAnchor : Vector2
					for point in anchorPointsArray:
						endPoint = point
						pipeDirection = anchorPointsDictionary[point]
						if point == anchorPointsArray[0]:
							startPoint = previewStart
						else:
							startPoint = previousAnchor
						handle_pipe_dragging(startPoint, endPoint, pipeDirection)
						previousAnchor = point
					
					handle_pipe_dragging(previousAnchor, currentPreview, previewDirection)
				else:
					handle_pipe_dragging(previewStart, currentPreview, previewDirection)
				check_existing_buildings_for_pipe_drag()
	#endregion
	
	#region Selections
	elif selectionDragging == true:
		var currentCursorLocation = cursor_snap()
		if selectionDragStartSnapped.distance_to(currentCursorLocation) >= FactoryGlobal.CELL_SIZE.x \
		or selectionDragStartSnapped.distance_to(currentCursorLocation) >= FactoryGlobal.CELL_SIZE.y:
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
			
			selectionDragStartSnapped = cursor_snap()
	#endregion
	
	# Too slow when there are lots and lots of pipes - need to figure out how to draw them at once
	#region Copy/Pase functionality
	elif copying == true:
		overlappingPipes.clear()
		selectedPipes.clear()
		var holder = get_node_or_null("Holder")
		if holder:
			for pipe in holder.get_children():
				var pipePositionOnGrid : Vector2 = get_grid_coordinates(pipe.global_position)
				var foundOverlap = false
				for building in %Buildings.get_children():
					var buildingPositionOnGrid : Vector2 = get_grid_coordinates(building.global_position)
					if pipePositionOnGrid == buildingPositionOnGrid:
						foundOverlap = true
						break
				
				if foundOverlap == true:
					overlappingPipes.append(pipe.global_position - FactoryGlobal.HALF_CELL_SIZE - menuOffset)
				else:
					selectedPipes.append(pipe.global_position - FactoryGlobal.HALF_CELL_SIZE - menuOffset)
	#endregion
	
	if copying == true:
		var holder = get_node_or_null("Holder")
		if holder:
			holder.position = cursor_snap()
	else:
		if buildingPreviewInstance:
			buildingPreviewInstance.position = cursor_snap() + FactoryGlobal.HALF_CELL_SIZE
			
	# Can this be optimized?
	queue_redraw()

func _input(event: InputEvent) -> void:
	if FactoryGlobal.disableInput == false:
		if waitForBlueprintMenuClose == false:
			if event.is_action_pressed("build_mode"):
				enter_exit_build_mode()
			
			if FactoryGlobal.isGridOn == true:
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
							
							recalculate_factory(pipeInfo, get_parent().name, {}, true)
							finalize_elements()
							finalize_global_dictionaries()
							selectedBuilding = preDragBuilding
							selectedBuildingIndex = preDragBuildingIndex
						else:
							copying = false
					elif pipeDragging == true:
						pipeDragging = false
						if illegalMoveCursorPosition == Vector2.INF:
							previewEnd = cursor_snap()
						else:
							previewEnd = anchorPointsArray[-1]
						currentPreview = cursor_snap()
						
						if previewStart != previewEnd:
							var finalDragPoint : Vector2
							if anchorPointsArray != []:
								finalDragPoint = anchorPointsArray[-1]
								var previousAnchor : Vector2
								for anchor in anchorPointsArray:
									if anchor == anchorPointsArray[0]:
										previousAnchor = previewStart
									handle_pipe_chain(anchorPointsDictionary[anchor], previousAnchor, anchor)
									previousAnchor = anchor
							else:
								finalDragPoint = previewStart
							
							handle_pipe_chain(previewDirection, finalDragPoint, previewEnd)
							recalculate_factory(pipeInfo, get_parent().name, {}, true)
							finalize_elements()
							finalize_global_dictionaries()
						else:
							if pipeInfo.has(var_to_str(cursor_snap())) == true:
								display_pipe_info(var_to_str(cursor_snap()))
							else:
								spawn_building(var_to_str(cursor_snap()))
								recalculate_factory(pipeInfo, get_parent().name, {}, true)
								finalize_elements()
								finalize_global_dictionaries()
						
						selectedBuildingIndex = preDragBuildingIndex
						selectedBuilding = preDragBuilding
						flip = preDragBuildingFlip
						buildingRotation = preDragBuildingRotation
						select_building(selectedBuildingIndex)
					
					elif selectionDragging == true:
						selectionDragging = false
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
							previewStart = cursor_snap()
							pipeDragging = true
							makingIllegalMove = false
							anchorPointsArray.clear()
							anchorPointsDictionary = {}
							preDragBuilding = selectedBuilding
							preDragBuildingIndex = selectedBuildingIndex
							preDragBuildingFlip = flip
							preDragBuildingRotation = buildingRotation
						else:
							selectedPipes.clear()
							selectedBodies.clear()
							highlightedPipes.clear()
							selectionDragging = true
							selectionDragStart = get_local_mouse_position()
							selectionDragStartSnapped = cursor_snap()
				elif event.is_action_released("create_anchor") and pipeDragging == true:
					if cursor_snap() != previewStart and anchorPointsArray.has(cursor_snap()) == false:
						anchorPointsDictionary[cursor_snap()] = previewDirection
						anchorPointsArray.append(cursor_snap())
						previewDirection = Vector2.INF
						currentPreview = Vector2.INF
						illegalMoveCursorPosition = Vector2.INF
						makingIllegalMove = false
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
				elif event.is_action_pressed("select_building"):
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
		if draggedPathPipes != []:
			for index in draggedPathPipes.size():
				draw_rect(Rect2(draggedPathPipes[index], FactoryGlobal.CELL_SIZE), FactoryGlobal.GRID_GOOD_COLOR)

		var parent = get_tree().root
		var blueprintMenu = parent.get_node_or_null("BlueprintMenu")
		if outsideBuildAreaPipes != [] and not blueprintMenu:
			for index in outsideBuildAreaPipes.size():
				draw_rect(Rect2(outsideBuildAreaPipes[index], FactoryGlobal.CELL_SIZE), FactoryGlobal.GRID_OUTSIDE_BUILD_AREA_COLOR)
				
		if overlappingPipes != []:
			for index in overlappingPipes.size():
				if forceBuild == false:
					draw_rect(Rect2(overlappingPipes[index], FactoryGlobal.CELL_SIZE), FactoryGlobal.GRID_ERROR_COLOR)
				else:
					draw_rect(Rect2(overlappingPipes[index], FactoryGlobal.CELL_SIZE), FactoryGlobal.GRID_REPLACE_COLOR)

		if transformPipe == true:
			draw_rect(Rect2(previewStart, FactoryGlobal.CELL_SIZE), FactoryGlobal.GRID_TRANSFORM_COLOR)
		
		if anchorPointsDictionary != {}:
			for point in anchorPointsDictionary:
				draw_rect(Rect2(point, FactoryGlobal.CELL_SIZE), FactoryGlobal.GRID_ANCHOR_COLOR)
	#endregion
	
	#region Selection
	elif selectionDragging == true:
		if selectedPipes != []:
			for index in selectedPipes.size():
				draw_rect(Rect2(selectedPipes[index], FactoryGlobal.CELL_SIZE), FactoryGlobal.GRID_HIGHLIGHT_COLOR)
		
		draw_rect(Rect2(selectionDragStart, get_local_mouse_position() - selectionDragStart), FactoryGlobal.GRID_SELECTION_OUTLINE_COLOR, false, FactoryGlobal.GRID_BOX_OUTLLINE_THICKNESS)
	#endregion

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
	var playerLocation := get_player_location()
	if playerLocation.distance_to(trueLocation) <= FactoryGlobal.buildAreaRadius \
	or playerLocation.distance_to(Vector2(trueLocation.x + FactoryGlobal.CELL_SIZE.x, trueLocation.y)) <= FactoryGlobal.buildAreaRadius \
	or playerLocation.distance_to(Vector2(trueLocation.x + FactoryGlobal.CELL_SIZE.x, trueLocation.y + FactoryGlobal.CELL_SIZE.y)) <= FactoryGlobal.buildAreaRadius \
	or playerLocation.distance_to(Vector2(trueLocation.x, trueLocation.y + FactoryGlobal.CELL_SIZE.y)) <= FactoryGlobal.buildAreaRadius:
		return true
	else:
		return false

func get_player_location() -> Vector2:
	return Vector2(FactoryGlobal.player.position.x, FactoryGlobal.player.position.y - 62)

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
func create_preview_path() -> void:
	var currentStart = get_end_chain_start()
	
	if previewStart == Vector2.INF:
		previewStart = cursor_snap()
	
	elif previewDirection == Vector2.INF and cursor_snap().distance_to(currentStart) >= FactoryGlobal.CELL_SIZE.x:
		previewDirection = currentStart.direction_to(cursor_snap())
		
		if previewDirection != Vector2.UP \
		and previewDirection != Vector2.DOWN \
		and previewDirection != Vector2.LEFT \
		and previewDirection != Vector2.RIGHT:
			previewDirection = Vector2.INF
		
		if anchorPointsDictionary != {} and anchorPointsArray != []:
			var currentAnchor : Vector2 = anchorPointsArray[-1]
			var previousDirection : Vector2 = anchorPointsDictionary[currentAnchor]
			var previousAnchor : Vector2
			if anchorPointsArray.size() == 1:
				previousAnchor = previewStart
			else:
				previousAnchor = anchorPointsArray[-2]
			
			if makingIllegalMove == true:
				illegalMoveCursorPosition = cursor_snap()
				if abs(previousDirection.x) > abs(previousDirection.y):
					if previousAnchor.y > currentAnchor.y:
						previewDirection = Vector2(0, 1)
					elif previousAnchor.y < currentAnchor.y:
						previewDirection = Vector2(0, -1)
					elif previousAnchor.y == currentAnchor.y:
						previewDirection = previousDirection * -1
				else:
					if previousAnchor.x > currentAnchor.x:
						previewDirection = Vector2(1, 0)
					elif previousAnchor.x < currentAnchor.x:
						previewDirection = Vector2(-1, 0)
					elif previousAnchor.x == currentAnchor.x:
						previewDirection = previousDirection * -1
			
			if abs(previousDirection.x) > abs(previousDirection.y):
				if previousAnchor.y > currentAnchor.y and previewDirection == Vector2(0, 1):
					if illegalMoveCursorPosition != Vector2.INF and currentAnchor.x > illegalMoveCursorPosition.x:
						previewDirection = Vector2(-1, 0)
						makingIllegalMove = false
						illegalMoveCursorPosition = Vector2.INF
					elif illegalMoveCursorPosition != Vector2.INF and currentAnchor.x < illegalMoveCursorPosition.x:
						previewDirection = Vector2(1, 0)
						makingIllegalMove = false
						illegalMoveCursorPosition = Vector2.INF
					else:
						previewDirection = Vector2.INF
						makingIllegalMove = true
				elif previousAnchor.y < currentAnchor.y and previewDirection == Vector2(0, -1):
					if illegalMoveCursorPosition != Vector2.INF and currentAnchor.x > illegalMoveCursorPosition.x:
						previewDirection = Vector2(-1, 0)
						makingIllegalMove = false
						illegalMoveCursorPosition = Vector2.INF
					elif illegalMoveCursorPosition != Vector2.INF and currentAnchor.x < illegalMoveCursorPosition.x:
						previewDirection = Vector2(1, 0)
						makingIllegalMove = false
						illegalMoveCursorPosition = Vector2.INF
					else:
						previewDirection = Vector2.INF
						makingIllegalMove = true
			
				elif previousAnchor.y == currentAnchor.y and previewDirection == previousDirection * -1:
					if illegalMoveCursorPosition != Vector2.INF and currentAnchor.y > illegalMoveCursorPosition.y:
						previewDirection = Vector2(0, -1)
						makingIllegalMove = false
						illegalMoveCursorPosition = Vector2.INF
					elif illegalMoveCursorPosition != Vector2.INF and currentAnchor.y < illegalMoveCursorPosition.y:
						previewDirection = Vector2(0, 1)
						makingIllegalMove = false
						illegalMoveCursorPosition = Vector2.INF
					else:
						previewDirection = Vector2.INF
						makingIllegalMove = true
			else:
				if previousAnchor.x > currentAnchor.x and previewDirection == Vector2(1, 0):
					if illegalMoveCursorPosition != Vector2.INF and currentAnchor.y > illegalMoveCursorPosition.y:
						previewDirection = Vector2(0, -1)
						makingIllegalMove = false
						illegalMoveCursorPosition = Vector2.INF
					elif illegalMoveCursorPosition != Vector2.INF and currentAnchor.y < illegalMoveCursorPosition.y:
						previewDirection = Vector2(0, 1)
						makingIllegalMove = false
						illegalMoveCursorPosition = Vector2.INF
					else:
						previewDirection = Vector2.INF
						makingIllegalMove = true
				elif previousAnchor.x < currentAnchor.x and previewDirection == Vector2(-1, 0):
					if illegalMoveCursorPosition != Vector2.INF and currentAnchor.y > illegalMoveCursorPosition.y:
						previewDirection = Vector2(0, -1)
						makingIllegalMove = false
						illegalMoveCursorPosition = Vector2.INF
					elif illegalMoveCursorPosition != Vector2.INF and currentAnchor.y < illegalMoveCursorPosition.y:
						previewDirection = Vector2(0, 1)
						makingIllegalMove = false
						illegalMoveCursorPosition = Vector2.INF
					else:
						previewDirection = Vector2.INF
						makingIllegalMove = true
				elif previousAnchor.x == currentAnchor.x and previewDirection == previousDirection * -1:
					if illegalMoveCursorPosition != Vector2.INF and currentAnchor.x > illegalMoveCursorPosition.x:
						previewDirection = Vector2(-1, 0)
						makingIllegalMove = false
						illegalMoveCursorPosition = Vector2.INF
					elif illegalMoveCursorPosition != Vector2.INF and currentAnchor.x < illegalMoveCursorPosition.x:
						previewDirection = Vector2(1, 0)
						makingIllegalMove = false
						illegalMoveCursorPosition = Vector2.INF
					else:
						previewDirection = Vector2.INF
						makingIllegalMove = true
		
		if makingIllegalMove == false:
			currentPreview = cursor_snap()
		else:
			currentPreview = anchorPointsArray[-1]
			illegalMoveCursorPosition = cursor_snap()
	
	elif currentPreview != Vector2.INF and previewDirection != Vector2.INF and cursor_snap().distance_to(currentPreview) >= FactoryGlobal.CELL_SIZE.x and cursor_snap() != currentStart:
		currentPreview = cursor_snap()
	
	elif cursor_snap() == currentStart and currentStart != Vector2.INF and previewDirection != Vector2.INF:
		previewDirection = Vector2.INF
		currentPreview = cursor_snap()

func handle_pipe_dragging(startPoint : Vector2, endPoint : Vector2, direction : Vector2) -> void:
	if buildingPreviewInstance:
		buildingPreviewInstance.queue_free()
	
	if startPoint != endPoint:
		draggedPathPipes.append(startPoint)
		transformPipe = false
		
		var coordCheck := startPoint
		var previewPlace : float
		var previewChange : float
		var pointCheck : float
		var farthestPoint : float
		
		if abs(direction.x) > abs(direction.y):
			pointCheck = startPoint.x
			farthestPoint = endPoint.x
			if endPoint.x > startPoint.x:
				previewChange = FactoryGlobal.CELL_SIZE.x
			else:
				previewChange = -FactoryGlobal.CELL_SIZE.x
			
		else:
			pointCheck = startPoint.y
			farthestPoint = endPoint.y
			if endPoint.y > startPoint.y:
				previewChange = FactoryGlobal.CELL_SIZE.y
			else:
				previewChange = -FactoryGlobal.CELL_SIZE.y
			
		previewPlace = previewChange
		if is_inside_build_area(startPoint) == false:
			outsideBuildAreaPipes.append(startPoint)
		
		while pointCheck != farthestPoint:
			if abs(direction.x) > abs(direction.y):
				coordCheck = Vector2(startPoint.x + previewPlace, startPoint.y)
			else: 
				coordCheck = Vector2(startPoint.x, startPoint.y + previewPlace)
			
			draggedPathPipes.append(coordCheck)
			if is_inside_build_area(coordCheck) == false:
				outsideBuildAreaPipes.append(coordCheck)
			
			previewPlace += previewChange
			pointCheck += previewChange
		
		if abs(direction.x) > abs(direction.y):
			pointCheck = startPoint.y
			farthestPoint = endPoint.y
			if endPoint.y > startPoint.y:
				previewChange = FactoryGlobal.CELL_SIZE.y
			else:
				previewChange = -FactoryGlobal.CELL_SIZE.y
			
		else:
			pointCheck = startPoint.x
			farthestPoint = endPoint.x
			if endPoint.x > startPoint.x:
				previewChange = FactoryGlobal.CELL_SIZE.x
			else:
				previewChange = -FactoryGlobal.CELL_SIZE.x
					
		previewPlace = previewChange
		
		while pointCheck != farthestPoint:
			if abs(direction.x) > abs(direction.y):
				coordCheck = Vector2(endPoint.x, startPoint.y + previewPlace)
			else: 
				coordCheck = Vector2(startPoint.x + previewPlace, endPoint.y)
			
			draggedPathPipes.append(coordCheck)
			if is_inside_build_area(coordCheck) == false:
				outsideBuildAreaPipes.append(coordCheck)
				
			previewPlace += previewChange
			pointCheck += previewChange

func check_existing_buildings_for_pipe_drag() -> void:
	var pipeFacing : Vector2
	
	if abs(previewDirection.x) > abs(previewDirection.y):
		pipeFacing = previewStart.direction_to(Vector2(currentPreview.x, previewStart.y))
	else: 
		pipeFacing = previewStart.direction_to(Vector2(previewStart.x, currentPreview.y))
			
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
		
		if draggedPathPipes.has(pipe.position - FactoryGlobal.HALF_CELL_SIZE):
			overlappingPipes.append(pipe.position - FactoryGlobal.HALF_CELL_SIZE)

func handle_pipe_chain(currentChainDirection : Vector2, currentStart : Vector2, currentEnd : Vector2) -> void:
	var currentBuildings : Array = %Buildings.get_children()
	var previewPipesStart : Array[Vector2] = create_dragged_pipes_start(currentChainDirection, currentStart, currentEnd)
	var previewPipesEnd : Array[Vector2] = create_dragged_pipes_end(currentChainDirection, currentStart, currentEnd)
	var currentBuilding = null
	
	for pipe in previewPipesStart:
		# Remember if performance issue
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
					rotate_dragged_straight_pipes(currentChainDirection, currentStart, currentEnd)
			
			else:
				handle_first_pipe_special_cases(currentChainDirection, currentStart, currentEnd)
					
		
		elif previewPipesStart[-1] == pipe: 
			if previewPipesEnd != []:
				selectedBuilding = FactoryGlobal.turnPipe
				selectedBuildingIndex = TurnPipe.BUILDING_INDEX
				rotate_drgged_turn_pipes(currentChainDirection, currentStart, currentEnd)
			elif previewPipesEnd == [] and anchorPointsArray != []:
				if anchorPointsDictionary.has(pipe):
					selectedBuilding = FactoryGlobal.turnPipe
					selectedBuildingIndex = TurnPipe.BUILDING_INDEX
					var nextAnchor : Vector2
					var anchorCurveStart : Vector2
					var anchorCurveEnd : Vector2 = pipe
					var isStraightLine : bool = false
					if pipe != anchorPointsArray[-1]:
						var currentIndex : int = anchorPointsArray.find(pipe)
						nextAnchor = anchorPointsArray[currentIndex + 1]
					else:
						nextAnchor = previewEnd
					
					if abs(currentChainDirection.x) > abs(currentChainDirection.y):
						if nextAnchor.y > pipe.y:
							anchorCurveEnd.y += 1
						elif nextAnchor.y < pipe.y:
							anchorCurveEnd.y -= 1
						else:
							isStraightLine = true
					else:
						if nextAnchor.x > pipe.x:
							anchorCurveEnd.x += 1
						elif nextAnchor.x < pipe.x:
							anchorCurveEnd.x -= 1
						else:
							isStraightLine = true
					
					if pipe != anchorPointsArray[0]:
						var currentIndex : int = anchorPointsArray.find(pipe)
						anchorCurveStart = anchorPointsArray[currentIndex - 1]
					else:
						anchorCurveStart = previewStart
					
					if isStraightLine == false:
						rotate_drgged_turn_pipes(currentChainDirection, anchorCurveStart, anchorCurveEnd)
					else:
						selectedBuilding = FactoryGlobal.normalPipe
						selectedBuildingIndex = NormalPipe.BUILDING_INDEX
			else:
				selectedBuilding = FactoryGlobal.normalPipe
				selectedBuildingIndex = NormalPipe.BUILDING_INDEX
		else:
			selectedBuilding = FactoryGlobal.normalPipe
			selectedBuildingIndex = NormalPipe.BUILDING_INDEX
			
			flip = false
			rotate_dragged_straight_pipes(currentChainDirection, currentStart, currentEnd)
		
		if pipeInfo.has(var_to_str(pipe)) == false:
			spawn_building(var_to_str(pipe))
	
	selectedBuilding = FactoryGlobal.normalPipe
	selectedBuildingIndex = NormalPipe.BUILDING_INDEX
	flip = false
	if reversePath == false:
		if abs(currentChainDirection.x) > abs(currentChainDirection.y):
			if currentEnd.y > currentStart.y:
				buildingRotation = 0
			else: 
				buildingRotation = 180
		else:
			if currentPreview.x > currentStart.x:
				buildingRotation = 270
			else: 
				buildingRotation = 90
	else:
		if abs(currentChainDirection.x) > abs(currentChainDirection.y):
			if currentEnd.y > currentStart.y:
				buildingRotation = 180
			else: 
				buildingRotation = 0
		else:
			if currentPreview.x > currentStart.x:
				buildingRotation = 90
			else: 
				buildingRotation = 270
	
	for pipe in previewPipesEnd:
		if anchorPointsArray != [] and pipe == previewPipesEnd[-1]:
			if anchorPointsDictionary.has(pipe):
				var nextDirection : Vector2
				if pipe != anchorPointsArray[-1]:
					var currentIndex : int = anchorPointsArray.find(pipe)
					var nextAnchor : Vector2 = anchorPointsArray[currentIndex + 1]
					nextDirection = anchorPointsDictionary.get(nextAnchor)
				else:
					nextDirection = previewDirection
				
				if abs(currentChainDirection.x) > abs(currentChainDirection.y):
					if abs(nextDirection.x) > abs(nextDirection.y):
						selectedBuilding = FactoryGlobal.turnPipe
						selectedBuildingIndex = TurnPipe.BUILDING_INDEX
						var anchorDirection : Vector2
						var anchorCurveStart : Vector2 = previewPipesStart[-1]
						var anchorCurveEnd : Vector2 = pipe
						
						if anchorCurveStart.y > anchorCurveEnd.y:
							anchorDirection = Vector2.UP
						else:
							anchorDirection = Vector2.DOWN
						if nextDirection.x > 0:
							anchorCurveEnd.x += 1
						else:
							anchorCurveEnd.x -= 1
						rotate_drgged_turn_pipes(anchorDirection, anchorCurveStart, anchorCurveEnd)
				else:
					if abs(nextDirection.y) > abs(nextDirection.x):
						selectedBuilding = FactoryGlobal.turnPipe
						selectedBuildingIndex = TurnPipe.BUILDING_INDEX
						var anchorDirection : Vector2
						var anchorCurveStart : Vector2 = previewPipesEnd[0]
						var anchorCurveEnd : Vector2 = pipe
						
						if anchorCurveStart.x > anchorCurveEnd.x:
							anchorDirection = Vector2.LEFT
						else:
							anchorDirection = Vector2.RIGHT
						if nextDirection.y > 0:
							anchorCurveEnd.y += 1
						else:
							anchorCurveEnd.y -= 1
						rotate_drgged_turn_pipes(anchorDirection, anchorCurveStart, anchorCurveEnd)
		if pipeInfo.has(var_to_str(pipe)) == false:
			spawn_building(var_to_str(pipe))

	overlappingPipes.clear()
	outsideBuildAreaPipes.clear()

func rotate_dragged_straight_pipes(currentChainDirection : Vector2, currentStart : Vector2, currentEnd : Vector2) -> void:
	if reversePath == false:
		if abs(currentChainDirection.x) > abs(currentChainDirection.y):
			if currentEnd.x > currentStart.x:
				buildingRotation = 270
			else:
				buildingRotation = 90
		else:
			if currentEnd.y > currentStart.y:
				buildingRotation = 0
			else: 
				buildingRotation = 180
	else:
		if abs(currentChainDirection.x) > abs(currentChainDirection.y):
			if currentEnd.x > currentStart.x:
				buildingRotation = 90
			else:
				buildingRotation = 270
		else:
			if currentEnd.y > currentStart.y:
				buildingRotation = 180
			else: 
				buildingRotation = 0

func rotate_drgged_turn_pipes(currentChainDirection : Vector2, currentStart : Vector2, currentEnd : Vector2) -> void:
	if reversePath == false:
		if abs(currentChainDirection.x) > abs(currentChainDirection.y):
			if currentEnd.x > currentStart.x:
				if currentEnd.y > currentStart.y:
					buildingRotation = 90
					flip = true
				else:
					buildingRotation = 270
					flip = false
			else:
				if currentEnd.y > currentStart.y:
					buildingRotation = 90
					flip = false
				else:
					buildingRotation = 270
					flip = true
		else:
			if currentEnd.y > currentStart.y:
				if currentEnd.x > currentStart.x:
					buildingRotation = 0
					flip = false
				else: 
					buildingRotation = 0
					flip = true
			else: 
				if currentEnd.x > currentStart.x:
					buildingRotation = 180
					flip = true
				else:
					buildingRotation = 180
					flip = false
	else:
		if abs(currentChainDirection.x) > abs(currentChainDirection.y):
			if currentEnd.x > currentStart.x:
				if currentEnd.y > currentStart.y:
					buildingRotation = 180
					flip = false
				else:
					buildingRotation = 0
					flip = true
			else:
				if currentEnd.y > currentStart.y:
					buildingRotation = 180
					flip = true
				else:
					buildingRotation = 0
					flip = false
		else:
			if currentEnd.y > currentStart.y:
				if currentEnd.x > currentStart.x:
					buildingRotation = 270
					flip = true
				else: 
					buildingRotation = 270
					flip = false
			else: 
				if currentEnd.x > currentStart.x:
					buildingRotation = 90
					flip = false
				else:
					buildingRotation = 90
					flip = true

func get_end_chain_start() -> Vector2:
	if anchorPointsArray == []:
		return previewStart
	else:
		return anchorPointsArray[-1]

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

func handle_first_pipe_special_cases(currentChainDirection : Vector2, currentStart : Vector2, currentEnd : Vector2) -> void:
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
		rotate_dragged_straight_pipes(currentChainDirection, currentStart, currentEnd)

func create_preview_path_start() -> Rect2:
	var endChainStart = get_end_chain_start()
	
	if previewDirection == Vector2.INF:
		return Rect2(endChainStart, FactoryGlobal.CELL_SIZE)
	else:
		if abs(previewDirection.x) > abs(previewDirection.y):
			return Rect2(endChainStart.x, endChainStart.y, currentPreview.x - endChainStart.x, FactoryGlobal.CELL_SIZE.y)
		else:
			return Rect2(endChainStart.x, endChainStart.y, FactoryGlobal.CELL_SIZE.x, currentPreview.y - endChainStart.y)

func create_preview_path_end() -> Rect2:
	var endChainStart = get_end_chain_start()
	
	if previewDirection == Vector2.INF:
		return Rect2(endChainStart, FactoryGlobal.CELL_SIZE)
	else:
		if abs(previewDirection.x) > abs(previewDirection.y):
			return Rect2(cursor_snap().x, cursor_snap().y, FactoryGlobal.CELL_SIZE.x, endChainStart.y - cursor_snap().y)
		else:
			return Rect2(currentPreview.x, currentPreview.y, endChainStart.x - cursor_snap().x, FactoryGlobal.CELL_SIZE.y)
	
func create_dragged_pipes_start(currentChainDirection : Vector2, currentStart : Vector2, currentEnd : Vector2) -> Array[Vector2]:
	var previewPipePath : Array[Vector2] = []
	var previewCount : float
	var previewPlace : float
	
	previewPipePath.append(currentStart)
	
	if abs(currentChainDirection.x) > abs(currentChainDirection.y):
		if currentEnd.x > currentStart.x:
			previewPlace = FactoryGlobal.CELL_SIZE.x
		else:
			previewPlace = -FactoryGlobal.CELL_SIZE.x
		
		previewCount = abs(currentStart.x - currentEnd.x)
		
		while previewCount > 0:
			previewPipePath.append(Vector2(currentStart.x + previewPlace, currentStart.y))
			previewCount -= FactoryGlobal.CELL_SIZE.x
			if currentEnd.x > currentStart.x:
				previewPlace += FactoryGlobal.CELL_SIZE.x
			else:
				previewPlace -= FactoryGlobal.CELL_SIZE.x
	
	else:
		if currentEnd.y > currentStart.y:
			previewPlace = FactoryGlobal.CELL_SIZE.x
		else:
			previewPlace = -FactoryGlobal.CELL_SIZE.x
		
		previewCount = abs(currentStart.y - currentEnd.y)
		
		while previewCount > 0:
			previewPipePath.append(Vector2(currentStart.x, currentStart.y + previewPlace))
			previewCount -= FactoryGlobal.CELL_SIZE.y
			if currentEnd.y > currentStart.y:
				previewPlace += FactoryGlobal.CELL_SIZE.y
			else:
				previewPlace -= FactoryGlobal.CELL_SIZE.y
	
	return previewPipePath

func create_dragged_pipes_end(currentChainDirection : Vector2, currentStart : Vector2, currentEnd : Vector2) -> Array[Vector2]:
	var previewPipePath : Array[Vector2] = []
	var previewCount : float
	var previewPlace : float
	
	if abs(currentChainDirection.x) > abs(currentChainDirection.y):
		previewCount = abs(currentEnd.y - currentStart.y)
		
		if currentEnd.y > currentStart.y:
			previewPlace = FactoryGlobal.CELL_SIZE.y
		else:
			previewPlace = -FactoryGlobal.CELL_SIZE.y
		
		while previewCount > 0:
			previewPipePath.append(Vector2(currentEnd.x, currentStart.y + previewPlace))
			previewCount -= FactoryGlobal.CELL_SIZE.y
			if currentEnd.y > currentStart.y:
				previewPlace += FactoryGlobal.CELL_SIZE.y
			else:
				previewPlace -= FactoryGlobal.CELL_SIZE.y
				
	else:
		previewCount = abs(currentEnd.x - currentStart.x)
		
		if currentEnd.x > currentStart.x:
			previewPlace = FactoryGlobal.CELL_SIZE.x
		else:
			previewPlace = -FactoryGlobal.CELL_SIZE.x
		
		while previewCount > 0:
			previewPipePath.append(Vector2(currentStart.x + previewPlace, currentEnd.y))
			previewCount -= FactoryGlobal.CELL_SIZE.x
			if currentEnd.x > currentStart.x:
				previewPlace += FactoryGlobal.CELL_SIZE.x
			else:
				previewPlace -= FactoryGlobal.CELL_SIZE.x
	
	return previewPipePath

func get_overlapping_preview_pipes(dragStart : Vector2, dragEnd : Vector2, ) -> Array:
	selectionRect.extents = abs(dragEnd - dragStart) / 2
	var selectionSpace = get_world_2d().direct_space_state
	var selectionQuery = PhysicsShapeQueryParameters2D.new()
	selectionQuery.collide_with_areas = true
	selectionQuery.shape = selectionRect
	selectionQuery.transform = Transform2D(0, ((dragEnd + dragStart) / 2) + menuOffset)
	selectedBodies = selectionSpace.intersect_shape(selectionQuery, 2048)
	return selectedBodies
#endregion

#region Building functions
# Builds the building. Puts it on the grid and gives the game all the info it needs about the building.
func spawn_building(location : String) -> void:
	var trueLocation = str_to_var(location)
	
	#if is_inside_build_area(trueLocation) == true:
	if 1 == 1:
		#if pipeInfo.has(location) == false:
		if 1 == 1: # Look, I just don't want to fix my inditation in case this idea I have doesn't work
			var canBuild = false
			var buildingScene : String
			var nameBuilding : String
			var recieves : String
			var mergeRecieves : String = var_to_str(Vector2.INF)
			var gives : String
			var splitGives : String = var_to_str(Vector2.INF)
			var sourceDictionary : Dictionary[String, float] = {}
			
			for element in FactoryGlobal.elementArray:
				sourceDictionary[element] = 0
				
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
			
			# Underground Pipes, plz fix
			if selectedBuilding == FactoryGlobal.undergroundPipeStart:
				canBuild = true
				buildingScene = "uid://u56j8q2q6t43"
				nameBuilding = "Underground Pipe Start"
				var vectorRecieves = get_grid_coordinates(trueLocation) + NormalPipe.get_recieves(buildingRotation, flip)
				recieves = var_to_str(get_grid_position(vectorRecieves))
				
			if selectedBuilding == FactoryGlobal.undergroundPipeEnd:
				canBuild = true
				buildingScene = "uid://cxy7k3037vmg4"
				nameBuilding = "Underground Pipe End"
				recieves = "Vector2(inf, inf)"
				var vectorGives = get_grid_coordinates(trueLocation) + NormalPipe.get_gives(buildingRotation, flip)
				gives = var_to_str(get_grid_position(vectorGives))
				#pipeInfo[undergroundLocation]["Gives"] = location
			
			if selectedBuilding == FactoryGlobal.vaporizer:
				canBuild = true
				buildingScene = "uid://ct6w6os54d0fy"
				nameBuilding = "Vaporizer"
				var vectorRecieves = get_grid_coordinates(trueLocation) + Vaporizer.get_recieves(buildingRotation, flip)
				recieves = var_to_str(get_grid_position(vectorRecieves))
				
			elif selectedBuilding == FactoryGlobal.extractor: 
				for source in sourceArray:
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
			
			elif selectedBuilding == FactoryGlobal.phylactery:
				if pipeInfo.size() != 0:
					for item in pipeInfo:
						var valueArray = pipeInfo[item].values()
						if valueArray.has("Phylactery") == true:
							return
				
				canBuild = true
				buildingScene = "uid://rwrddigeppfh"
				nameBuilding = "Phylactery"
				var vectorRecieves = get_grid_coordinates(trueLocation) + Phylactery.get_recieves(buildingRotation, flip)
				recieves = var_to_str(get_grid_position(vectorRecieves))
				gives = var_to_str(Vector2.ZERO)
			
			if canBuild == true:
				for exit in exitArray:
					var exitCoords := get_grid_coordinates(exit.position)
					exitCoords = get_grid_position(exitCoords)
					
					if exitCoords == trueLocation:
						handle_room_transition_pipes(nameBuilding, gives, recieves, exit)
				
				var building = selectedBuilding.instantiate()
					
				# Populates the pipe dictionary
				# Scene, UID of pipe scene
				# Name, name of the building
				# X, x location in pixels
				# Y, y location in pixels
				# Rotation, building rotation in increments of 90 degrees
				# Flip, whether or not the building had to be flipped horizontally
				# Recieves, which tile the pipe gets its resources from
				# Merge Recieves, for mergers, since they get resources from two locations
				# Gives, which tile the pipe sends its resource to
				# Split Gives, for splitters since they send resources to two locations
				# Elements, the list of resources in the pipe, only extractors have this populated at the beginning
				# Calculation, placeholder for calculating flow before finalizing the amount and putting into Elements
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
					"Elements" : sourceDictionary.duplicate(),
					"Calculation" : sourceDictionary.duplicate(),
				}
				
				%Buildings.add_child(building)
				building.position = trueLocation + FactoryGlobal.HALF_CELL_SIZE
				if flip == true:
					building.scale.x = -1
				building.get_node("Sprite2D").rotate(deg_to_rad(buildingRotation))
				building.add_to_group("Buildings")
				
				FactoryGlobal.activePipeLayout[get_parent().name] = pipeInfo.duplicate(true)

func delete_building(location : String) -> void:
	if pipeInfo.has(location) == true:
		if exitPipesArray.has(location):
			exitPipesArray.erase(location)
		
		for exit in %Exits.get_children():
			var exitCoords := get_grid_coordinates(exit.position)
			exitCoords = get_grid_position(exitCoords)
			
			if var_to_str(exitCoords) == location:
				usedExitsArray.erase(exit)
				if FactoryGlobal.activeFlowBetweenRooms.has(get_parent().name) == true:
					if FactoryGlobal.activeFlowBetweenRooms[get_parent().name].has("Exit Info"):
						FactoryGlobal.activeFlowBetweenRooms[get_parent().name]["Exit Info"].erase(var_to_str(exitCoords))
				
				if FactoryGlobal.activeFlowBetweenRooms.has(get_parent().name) == true:
					if FactoryGlobal.activeFlowBetweenRooms[get_parent().name].has(exit.connectingRoom) == true:
						for element in FactoryGlobal.elementArray:
							FactoryGlobal.activeFlowBetweenRooms[get_parent().name][exit.connectingRoom]["Amount"][element] = 0
						
						if FactoryGlobal.activeFlowBetweenRooms.has(exit.connectingRoom):
							if FactoryGlobal.activeFlowBetweenRooms[exit.connectingRoom].has(get_parent().name):
								var startingPipe : String = FactoryGlobal.activeFlowBetweenRooms[exit.connectingRoom][get_parent().name]["Start"]
								for element in FactoryGlobal.elementArray:
									FactoryGlobal.activePipeLayout[exit.connectingRoom][startingPipe]["Elements"][element] = 0
						
							recalculate_factory(FactoryGlobal.activePipeLayout[exit.connectingRoom], exit.connectingRoom, {}, true)
							finalize_elements()
							finalize_global_dictionaries()
				break
		
		for body in %Buildings.get_children():
			if body.position - FactoryGlobal.HALF_CELL_SIZE == str_to_var(location):
				pipeInfo.erase(location)
				body.queue_free()
				break
		
		recalculate_factory(pipeInfo, get_parent().name, {}, true)
		recalulate_downstream_flow()
		finalize_elements()
		finalize_global_dictionaries()

func select_building(index : int) -> void:
	pipeDragging = false
	copying = false
	selectionDragging = false
	var holder = get_node_or_null("Holder")
	if holder:
		holder.queue_free()
	
	if selectedBuildingIndex != -1:
		selectedBuildingIndex = index
		selectedBuilding = FactoryGlobal.buildingArray[selectedBuildingIndex]
	else: 
		selectedBuilding = null
	
	FactoryGlobal.selectedBuildingBetweenRooms = selectedBuilding
	FactoryGlobal.selectedBuildingIndexBetweenRooms = selectedBuildingIndex
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
	
	FactoryGlobal.rotationBetweenRooms = buildingRotation

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
	FactoryGlobal.flipBetweenRooms = flip

func display_pipe_info(location : String) -> void:
	var existingTooltip = get_parent().get_node_or_null("PipeTooltip")
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
	await get_tree().process_frame
	if get_local_mouse_position().y > get_viewport_rect().size.y - tooltip.get_child(0).size.y:
		tooltip.global_position.y -= tooltip.get_child(0).size.y
	if get_local_mouse_position().x > get_viewport_rect().size.x - tooltip.get_child(0).size.x:
		tooltip.global_position.x -= tooltip.get_child(0).size.x

func handle_room_transition_pipes(pipeName : String, gives : String, recieves : String, exit : PipeExit) -> void:
	exit.flowDirection = exit.DIRECTION.INSIDE
	if pipeName == "Split Pipe":
		if exit.get_side() == "LEFT" or exit.get_side() == "RIGHT":
			if str_to_var(gives).x != exit.position.x:
				exitPipesArray.append(var_to_str(exit.position))
				usedExitsArray.append(exit)
				exit.flowDirection = exit.DIRECTION.OUTSIDE
			elif str_to_var(recieves).x < exit.position.x and exit.get_side() == "LEFT":
				exitPipesArray.append(var_to_str(exit.position))
				usedExitsArray.append(exit)
			elif str_to_var(recieves).x > exit.position.x and exit.get_side() == "RIGHT":
				exitPipesArray.append(var_to_str(exit.position))
				usedExitsArray.append(exit)
		
		elif exit.get_side() == "TOP" or exit.get_side() == "BOTTOM":
			if str_to_var(gives).y != exit.position.y:
				exitPipesArray.append(var_to_str(exit.position))
				usedExitsArray.append(exit)
				exit.flowDirection = exit.DIRECTION.OUTSIDE
			elif str_to_var(recieves).y < exit.position.y and exit.get_side() == "TOP":
				exitPipesArray.append(var_to_str(exit.position))
				usedExitsArray.append(exit)
			elif str_to_var(recieves).y > exit.position.y and exit.get_side() == "BOTTOM":
				exitPipesArray.append(var_to_str(exit.position))
				usedExitsArray.append(exit)
	
	elif pipeName == "Merge Pipe":
		if exit.get_side() == "LEFT" or exit.get_side() == "RIGHT":
			if str_to_var(recieves).x != exit.position.x:
				exitPipesArray.append(var_to_str(exit.position))
				usedExitsArray.append(exit)
			elif str_to_var(gives).x < exit.position.x and exit.get_side() == "LEFT":
				exitPipesArray.append(var_to_str(exit.position))
				usedExitsArray.append(exit)
				exit.flowDirection = exit.DIRECTION.OUTSIDE
			elif str_to_var(gives).x > exit.position.x and exit.get_side() == "RIGHT":
				exitPipesArray.append(var_to_str(exit.position))
				usedExitsArray.append(exit)
				exit.flowDirection = exit.DIRECTION.OUTSIDE
		
		elif exit.get_side() == "TOP" or exit.get_side() == "BOTTOM":
			if str_to_var(recieves).y != exit.position.y:
				exitPipesArray.append(var_to_str(exit.position))
				usedExitsArray.append(exit)
			elif str_to_var(gives).y < exit.position.y and exit.get_side() == "TOP":
				exitPipesArray.append(var_to_str(exit.position))
				usedExitsArray.append(exit)
				exit.flowDirection = exit.DIRECTION.OUTSIDE
			elif str_to_var(gives).y > exit.position.y and exit.get_side() == "BOTTOM":
				exitPipesArray.append(var_to_str(exit.position))
				usedExitsArray.append(exit)
				exit.flowDirection = exit.DIRECTION.OUTSIDE
	
	elif exit.get_side() == "LEFT" or exit.get_side() == "RIGHT":
		if str_to_var(gives).x != exit.position.x:
			exitPipesArray.append(var_to_str(exit.position))
			usedExitsArray.append(exit)
			
			if exit.get_side() == "LEFT" and str_to_var(gives).x < exit.position.x:
				exit.flowDirection = exit.DIRECTION.OUTSIDE
			elif exit.get_side() == "RIGHT" and str_to_var(gives).x > exit.position.x:
				exit.flowDirection = exit.DIRECTION.OUTSIDE
	else:
		if str_to_var(gives).y != exit.position.y:
			exitPipesArray.append(var_to_str(exit.position))
			usedExitsArray.append(exit)
			
			if exit.get_side() == "TOP" and str_to_var(gives).y < exit.position.y:
				exit.flowDirection = exit.DIRECTION.OUTSIDE
			elif exit.get_side() == "BOTTOM" and str_to_var(gives).y > exit.position.y:
				exit.flowDirection = exit.DIRECTION.OUTSIDE
#endregion

#region Element Calculations
# THE LOOPS JUST WON'T STOP
# How do I stop them?
# Step by step on how pipe math is done
# First, we reset all of the current resource amounts
# Then, we reset all of the phylactery locations (I clear the list)
# Find starting points, and calculate from there (starting points that connect rooms need a bit of logic to make sure they have correct resource amounts)
# Follow basic pipe logic (push resource downstream, split on splitters) until end is reached
# If there are loops keep looping through until only a tiny amount is unaccounted for
# If the pipe connects to another room then do the same thing with the pipe dictionary of that room intead
# This is where pipe loop between rooms logic probably has to go, but I don't have it right now
# Update dictionaries that keep track of all the stuff going on between rooms
# Alright, so what do I need to do?
# The only that's really going wrong is that I need to recalulate things downstream from the room that's being edited
# That needs to happen because if you delete some pipes and cut off the flow from somewhere (or otherwise change it) then everything downstream needs to reflect that
# I don't think I can just do that recalculation when pipes are deleted because what if the change is a splitter?
# When do I actually need to recalculate for things like that?
# This is a very specific type of recalulation
# I sees if there's a pipe going outside
func recalculate_factory(pipeDictionary : Dictionary, roomName : String, foundPipes : Dictionary[String, Array], isStartingRoom : bool):
	# Every non-extractor pipe needs to have its resource amounts reset
	print("")
	print("")
	print("")
	print("")
	print("")
	print("")
	print("")
	print("")
	print("##################")
	print("Recalculating Factory")
	print("##################")
	for pipe in pipeDictionary:
		if is_starting_point(pipeDictionary, pipe, roomName) == false:
			for element in FactoryGlobal.elementArray:
				pipeDictionary[pipe]["Elements"][element] = 0
				pipeDictionary[pipe]["Calculation"][element] = 0
	
	if isStartingRoom:
		phylacteryLocations = {}
	
	for item in pipeDictionary:
		#print("Finding Starting Pipes")
		#print(roomName)
		#print(item)
		#print(is_starting_point(pipeDictionary, item, roomName))
		#print("---")
		if is_starting_point(pipeDictionary, item, roomName) == true:
			if isStartingRoom == true and pipeDictionary[item]["Name"] == "Extractor":
				foundPipes.clear()
			print("Start")
			print(roomName)
			print(item)
			print("**********************")
			print("")
			
			if does_path_exist(pipeDictionary, item, roomName, true, []):
				if pipeDictionary[item]["Name"] != "Extractor":
					if roomName == get_parent().name:
						for exit in usedExitsArray:
							var exitCoords := get_grid_coordinates(exit.position)
							exitCoords = get_grid_position(exitCoords)
							
							if exit.position == str_to_var(item):
								var connectedRoom = exit.connectingRoom
								if FactoryGlobal.activeFlowBetweenRooms.has(connectedRoom):
									if FactoryGlobal.activeFlowBetweenRooms[connectedRoom].has(roomName):
										if FactoryGlobal.activeFlowBetweenRooms[connectedRoom][roomName]["Direction"] == "OUTSIDE" and exit.get_direction() == "INSIDE":
											if is_splitter_balanced(FactoryGlobal.activePipeLayout[connectedRoom], FactoryGlobal.activeFlowBetweenRooms[connectedRoom][roomName]["Start"], connectedRoom):
												for element in FactoryGlobal.elementArray:
													pipeDictionary[item]["Calculation"][element] = FactoryGlobal.activeFlowBetweenRooms[connectedRoom][roomName]["Amount"][element] / 2
											else:
												for element in FactoryGlobal.elementArray:
													pipeDictionary[item]["Calculation"][element] = FactoryGlobal.activeFlowBetweenRooms[connectedRoom][roomName]["Amount"][element]
						
					else:
						for exit in FactoryGlobal.activeFlowBetweenRooms[roomName]["Exit Info"]:
							if item == exit:
								var connectedRoom : String = FactoryGlobal.activeFlowBetweenRooms[roomName]["Exit Info"][exit]
								if FactoryGlobal.activeFlowBetweenRooms.has(connectedRoom):
									if FactoryGlobal.activeFlowBetweenRooms[connectedRoom].has(roomName) and FactoryGlobal.activeFlowBetweenRooms[roomName].has(connectedRoom):
										if FactoryGlobal.activeFlowBetweenRooms[connectedRoom][roomName]["Direction"] == "OUTSIDE" and FactoryGlobal.activeFlowBetweenRooms[roomName][connectedRoom]["Direction"] == "INSIDE":
											if is_splitter_balanced(FactoryGlobal.activePipeLayout[connectedRoom], FactoryGlobal.activeFlowBetweenRooms[connectedRoom][roomName]["Start"], connectedRoom):
												for element in FactoryGlobal.elementArray:
													pipeDictionary[item]["Calculation"][element] = FactoryGlobal.activeFlowBetweenRooms[connectedRoom][roomName]["Amount"][element]
											else:
												for element in FactoryGlobal.elementArray:
													pipeDictionary[item]["Calculation"][element] = FactoryGlobal.activeFlowBetweenRooms[connectedRoom][roomName]["Amount"][element]
								
				# If a path is found, calculate how many resources are going through the pipe path
				print("Calculating Flow")
				calculate_flow(pipeDictionary, item, item, roomName, foundPipes)
				
				# This won't work
				# This assumes that only extractors can have pipe loops connected to them
				# Pipes coming from another room can also have pipe loops connected to them
				# So I need to find a way to find the starting point the pipe loop is connected to
				if pipeDictionary[item]["Name"] == "Extractor":
					var hasPipeLoop : bool = false
					var samplePipe : String = ""
					var sampleElement = ""
					for pipe in pipeDictionary:
						var elementDictionary : Dictionary[String, float]
						elementDictionary.assign(pipeDictionary[pipe]["Calculation"])
						if is_endpoint(pipeDictionary, pipe, roomName, true) == false and is_starting_point(pipeDictionary, pipe, roomName) == false and are_elements_empty(elementDictionary) == false:
							hasPipeLoop = true
							samplePipe = pipe
							for element in FactoryGlobal.elementArray:
								if pipeDictionary[pipe]["Calculation"][element] != 0:
									sampleElement = element
									break
							break
					
					if hasPipeLoop == true:
						print("*****************")
						print("RECURSIVE LOOP DETECTED")
						print("Handling it now")
						print(roomName)
						print(samplePipe)
						print(sampleElement)
						print("*****************")
						if sampleElement != "":
							while pipeDictionary[samplePipe]["Calculation"][sampleElement] > pipeDictionary[item]["Elements"][sampleElement] * flowMarginOfError:
								calculate_flow(pipeDictionary, pipeDictionary[item]["Gives"], item, roomName, {})

					for pipe in pipeDictionary:
						if pipeDictionary[pipe]["Elements"] != pipeDictionary[pipe]["Calculation"]:
							for element in FactoryGlobal.elementArray:
								pipeDictionary[pipe]["Elements"][element] = pipeDictionary[pipe]["Calculation"][element]
				
	FactoryGlobal.activePipeLayout[roomName] = pipeDictionary.duplicate(true)

func calculate_flow(pipeDictionary : Dictionary, startingPoint : String, previousPipe : String, roomName : String, foundPipes : Dictionary[String, Array]) -> void:
	var currentPipe : String = startingPoint
	var loopCounter = 0
	
	while 1 == 1:
		if pipeDictionary.has(currentPipe) == false:
			break
		if currentPipe == previousPipe and loopCounter > 0:
			break
		
		loopCounter += 1
		print("")
		print("---------------------")
		print("Loop: " + str(loopCounter))
		print(pipeDictionary[currentPipe]["Name"] + ": " + currentPipe)
		var gives = pipeDictionary[currentPipe]["Gives"]
		if foundPipes.has(roomName) == false:
			foundPipes[roomName] = []
		
		#print("Found Pipes")
		#print(foundPipes)
		#print("")
		if foundPipes[roomName].has(currentPipe):
			print("")
			print("#######################")
			print("WARNING WARNING")
			print("RECURSIVE PIPE DETECTED")
			print("ABORT ABORT ABORT")
			print(roomName)
			print(currentPipe)
			print(pipeDictionary[currentPipe]["Calculation"])
			if pipeDictionary.has(Vector2(200, 450)):
				print(pipeDictionary[Vector2(200, 450)]["Calculation"])
			print("#######################")
			print("")
			break
		else:
			foundPipes[roomName].append(currentPipe)

		if pipeDictionary[currentPipe]["Name"] == "Split Pipe":
			var splitGives = pipeDictionary[currentPipe]["Split Gives"]
			if is_splitter_balanced(pipeDictionary, currentPipe, roomName) == true:
				if pipeDictionary.has(gives):
					for element in FactoryGlobal.elementArray:
						pipeDictionary[gives]["Calculation"][element] += pipeDictionary[currentPipe]["Calculation"][element] / 2
				if pipeDictionary.has(splitGives):
					for element in FactoryGlobal.elementArray:
						pipeDictionary[splitGives]["Calculation"][element] += pipeDictionary[currentPipe]["Calculation"][element] / 2
				for element in FactoryGlobal.elementArray:
					pipeDictionary[currentPipe]["Calculation"][element] = 0
				
				calculate_flow(pipeDictionary, splitGives, currentPipe, roomName, foundPipes)
				
			else:
				if pipeDictionary.has(gives) and does_path_exist(pipeDictionary, gives, roomName, false, []):
					if is_endpoint(pipeDictionary, gives, roomName, false) == true or pipeDictionary[gives]["Recieves"] == currentPipe or pipeDictionary[gives]["Merge Recieves"] == currentPipe:
						for element in FactoryGlobal.elementArray:
							pipeDictionary[gives]["Calculation"][element] += pipeDictionary[currentPipe]["Calculation"][element]
				
				var calculateSplitGives : bool = false
				if pipeDictionary.has(splitGives) and does_path_exist(pipeDictionary, splitGives, roomName, false, []):
					calculateSplitGives = true
					if pipeDictionary[splitGives]["Recieves"] == currentPipe or pipeDictionary[splitGives]["Merge Recieves"] == currentPipe:
						for element in FactoryGlobal.elementArray:
							pipeDictionary[splitGives]["Calculation"][element] += pipeDictionary[currentPipe]["Calculation"][element]
				
				for element in FactoryGlobal.elementArray:
					pipeDictionary[currentPipe]["Calculation"][element] = 0
				
				if calculateSplitGives == true:
					calculate_flow(pipeDictionary, splitGives, currentPipe, roomName, foundPipes)

		else:
			if pipeDictionary.has(gives):
				if is_endpoint(pipeDictionary, gives, roomName, false) == true or pipeDictionary[gives]["Recieves"] == currentPipe or pipeDictionary[gives]["Merge Recieves"] == currentPipe:
					for element in FactoryGlobal.elementArray:
						pipeDictionary[gives]["Calculation"][element] += pipeDictionary[currentPipe]["Calculation"][element]
		
		var isOnExit : bool = false
		var currentExit : String = ""
		var startingPipe : String = ""
		
		if roomName == get_parent().name:
			for exit in usedExitsArray:
				var exitCoords := get_grid_coordinates(exit.position)
				exitCoords = get_grid_position(exitCoords)
				
				if currentPipe == var_to_str(exitCoords) and exit.get_direction() == "OUTSIDE":
					currentExit = exit.connectingRoom
					isOnExit = true
					if FactoryGlobal.activeFlowBetweenRooms.has(currentExit):
						if FactoryGlobal.activeFlowBetweenRooms[currentExit].has(roomName):
							startingPipe = FactoryGlobal.activeFlowBetweenRooms[currentExit][roomName]["Start"]
					break
		
		else:
			if FactoryGlobal.activeFlowBetweenRooms.has(roomName):
				for exit in FactoryGlobal.activeFlowBetweenRooms[roomName]["Exit Info"]:
					if exit == currentPipe:
						currentExit = FactoryGlobal.activeFlowBetweenRooms[roomName]["Exit Info"][exit]
						if FactoryGlobal.activeFlowBetweenRooms[roomName].has(currentExit):
							if FactoryGlobal.activeFlowBetweenRooms[roomName][currentExit]["Direction"] == "OUTSIDE":
								if FactoryGlobal.activeFlowBetweenRooms.has(currentExit):
									if FactoryGlobal.activeFlowBetweenRooms[currentExit].has(roomName):
										isOnExit = true
										startingPipe = FactoryGlobal.activeFlowBetweenRooms[currentExit][roomName]["Start"]
										break
		
		if isOnExit == true and startingPipe != "":
			if foundPipes.has(currentExit):
				if foundPipes[currentExit].has(startingPipe):
					print("#################")
					print("WARNING WARNING")
					print("CIRCULAR ROOM STRUCTURE")
					print("!!!!!!!!!!!!!!!!!")
					print("ABORT ABORT ABORT")
					print("#################")
					break
			if roomName == get_parent().name:
				var checkExit : PipeExit = null
				for exit in usedExitsArray:
					var exitCoords := get_grid_coordinates(exit.position)
					exitCoords = get_grid_position(exitCoords)
				
					if currentPipe == var_to_str(exitCoords) and exit.get_direction() == "OUTSIDE":
						checkExit = exit
				
				if checkExit != null and FactoryGlobal.activeFlowBetweenRooms.has(currentExit):
					if FactoryGlobal.activeFlowBetweenRooms[currentExit].has(roomName):
						if FactoryGlobal.activeFlowBetweenRooms[currentExit][roomName]["Direction"] == "INSIDE":
							var newStartingPipe : String = FactoryGlobal.activeFlowBetweenRooms[currentExit][roomName]["Start"]
							if pipeDictionary[currentPipe]["Name"] == "Split Pipe":
								if is_splitter_balanced(pipeDictionary, currentPipe, roomName):
									for element in FactoryGlobal.elementArray:
										FactoryGlobal.activePipeLayout[currentExit][newStartingPipe]["Calculation"][element] = pipeDictionary[currentPipe]["Calculation"][element] / 2
								else:
									for element in FactoryGlobal.elementArray:
										FactoryGlobal.activePipeLayout[currentExit][newStartingPipe]["Calculation"][element] = pipeDictionary[currentPipe]["Calculation"][element]
							else:
								for element in FactoryGlobal.elementArray:
									FactoryGlobal.activePipeLayout[currentExit][newStartingPipe]["Calculation"][element] = pipeDictionary[currentPipe]["Calculation"][element]
									
							previousPipe = currentPipe
							print("")
							print("~~~~~~~~~~")
							print("Leaving: " + roomName)
							print("Entering: " + currentExit)
							print("")
							print(foundPipes)
							print("~~~~~~~~~~")
							recalculate_factory(FactoryGlobal.activePipeLayout[currentExit], currentExit, foundPipes, false)
							break
							
			elif FactoryGlobal.activeFlowBetweenRooms.has(roomName) and FactoryGlobal.activeFlowBetweenRooms.has(currentExit):
				if FactoryGlobal.activeFlowBetweenRooms[roomName].has(currentExit) and FactoryGlobal.activeFlowBetweenRooms[currentExit].has(roomName):
					var newStartingPipe : String = FactoryGlobal.activeFlowBetweenRooms[currentExit][roomName]["Start"]
					if FactoryGlobal.activePipeLayout[currentExit].has(newStartingPipe) and FactoryGlobal.activeFlowBetweenRooms[currentExit][roomName]["Direction"] == "INSIDE":
						if pipeDictionary[currentPipe]["Name"] == "Split Pipe":
							if is_splitter_balanced(pipeDictionary, currentPipe, roomName):
								for element in FactoryGlobal.elementArray:
									FactoryGlobal.activeFlowBetweenRooms[roomName][currentExit]["Amount"][element] = pipeDictionary[currentPipe]["Calculation"][element] / 2
									FactoryGlobal.activePipeLayout[currentExit][newStartingPipe]["Calculation"][element] = pipeDictionary[currentPipe]["Calculation"][element] / 2
							else:
								for element in FactoryGlobal.elementArray:
									FactoryGlobal.activeFlowBetweenRooms[roomName][currentExit]["Amount"][element] = pipeDictionary[currentPipe]["Calculation"][element]
									FactoryGlobal.activePipeLayout[currentExit][newStartingPipe]["Calculation"][element] = pipeDictionary[currentPipe]["Calculation"][element]
						else:
							for element in FactoryGlobal.elementArray:
								FactoryGlobal.activeFlowBetweenRooms[roomName][currentExit]["Amount"][element] = pipeDictionary[currentPipe]["Calculation"][element]
								FactoryGlobal.activePipeLayout[currentExit][newStartingPipe]["Calculation"][element] = pipeDictionary[currentPipe]["Calculation"][element]
								
						previousPipe = currentPipe
						print("")
						print("~~~~~~~~~~")
						print("Leaving: " + roomName)
						print("Entering: " + currentExit)
						print("")
						print(foundPipes)
						print("~~~~~~~~~~")
						recalculate_factory(FactoryGlobal.activePipeLayout[currentExit], currentExit, foundPipes, false)
						break
					else:
						print("Does not have starting pipe")
						break
				else:
					print("Does not have connection")
					print(FactoryGlobal.activeFlowBetweenRooms)
					break
			else:
				print("Does not have entry")
				break
					
		elif pipeDictionary.has(gives):
			if is_starting_point(pipeDictionary, currentPipe, roomName) == false:
				for element in FactoryGlobal.elementArray:
					pipeDictionary[currentPipe]["Calculation"][element] = 0
			
			if pipeDictionary[gives]["Name"] == "Phylactery":
				print("Found Phylactery")
				phylacteryLocations[roomName] = gives
			
			if pipeDictionary[gives]["Recieves"] == currentPipe or pipeDictionary[gives]["Merge Recieves"] == currentPipe:
				print("Continuing pipe chain")
				previousPipe = currentPipe
				currentPipe = gives
			else:
				print("Pipe chain ended")
				break
		elif pipeDictionary.has(pipeDictionary[currentPipe]["Split Gives"]):
			if is_starting_point(pipeDictionary, currentPipe, roomName) == false:
				for element in FactoryGlobal.elementArray:
					pipeDictionary[currentPipe]["Calculation"][element] = 0
			
			if pipeDictionary[pipeDictionary[currentPipe]["Split Gives"]]["Name"] == "Phylactery":
				print("Found Phylactery")
				phylacteryLocations[roomName] = pipeDictionary[currentPipe]["Split Gives"]
			
			if pipeDictionary[pipeDictionary[currentPipe]["Split Gives"]]["Recieves"] == currentPipe or pipeDictionary[pipeDictionary[currentPipe]["Split Gives"]]["Merge Recieves"] == currentPipe:
				print("Continuing pipe chain (Split Gives)")
				previousPipe = currentPipe
				currentPipe = pipeDictionary[currentPipe]["Split Gives"]
			else:
				print("Pipe chain ended")
				break
		else: 
			print("Didn't find exit")
			print(pipeDictionary[currentPipe]["Calculation"])
			break

func recalulate_downstream_flow() -> void:
	var roomName = get_parent().name

	for exit in usedExitsArray:
		var exitCoords := get_grid_coordinates(exit.position)
		exitCoords = get_grid_position(exitCoords)
		
		for pipe in exitPipesArray:
			if pipe == var_to_str(exitCoords) and exit.get_direction() == "OUTSIDE":
				if FactoryGlobal.activeFlowBetweenRooms.has(roomName) == true and FactoryGlobal.activeFlowBetweenRooms.has(exit.connectingRoom) == true:
					if FactoryGlobal.activeFlowBetweenRooms[roomName].has(exit.connectingRoom) == true:
						var otherPipe = FactoryGlobal.activeFlowBetweenRooms[exit.connectingRoom][roomName]["Start"]
						if FactoryGlobal.activePipeLayout[exit.connectingRoom].has(otherPipe) == true and FactoryGlobal.activeFlowBetweenRooms[exit.connectingRoom][roomName]["Direction"] == "INSIDE":
							if FactoryGlobal.activePipeLayout[roomName][pipe]["Elements"] != FactoryGlobal.activePipeLayout[exit.connectingRoom][otherPipe]["Elements"]:
								for element in FactoryGlobal.elementArray:
									FactoryGlobal.activePipeLayout[exit.connectingRoom][FactoryGlobal.activeFlowBetweenRooms[exit.connectingRoom][roomName]["Start"]]["Elements"][element] = FactoryGlobal.activeFlowBetweenRooms[roomName][exit.connectingRoom]["Amount"][element]
								
								print("#############################")
								print("WARNING WARNING")
								print("POTENTIAL RECURSIVE SHENANIGANS")
								print("Doing another factory recalculation")
								print("#############################")
								recalculate_factory(FactoryGlobal.activePipeLayout[exit.connectingRoom], exit.connectingRoom, {}, true)

func finalize_elements() -> void:
	if phylacteryLocations.has(get_parent().name) == false:
		FactoryGlobal.activePhylacteryValues.erase(get_parent().name)
	
	for room in phylacteryLocations:
		var pipeDictionary = FactoryGlobal.activePipeLayout[room]
		var playerElements : Dictionary[String, float] = {}
		
		for element in FactoryGlobal.elementArray:
			playerElements[element] = pipeDictionary[phylacteryLocations[room]]["Elements"][element]
		FactoryGlobal.activePhylacteryValues[room] = playerElements
	
	FactoryGlobal.get_elements_total()

func finalize_global_dictionaries() -> void:
	var roomName = get_parent().name
	FactoryGlobal.activeFlowBetweenRooms.erase(roomName)
	
	if usedExitsArray != []:
		var roomDictionary : Dictionary = {}
		var exitDictionary : Dictionary = {}
		for exit in usedExitsArray:
			var exitCoords := get_grid_coordinates(exit.position)
			exitCoords = get_grid_position(exitCoords)
			
			roomDictionary[exit.connectingRoom] = {
				"Direction" : exit.get_direction(),
				"Amount" : {},
				"Start" : var_to_str(exitCoords),
			}
			for element in FactoryGlobal.elementArray:
				roomDictionary[exit.connectingRoom]["Amount"][element] = pipeInfo[var_to_str(exitCoords)]["Elements"][element]
			
			exitDictionary[var_to_str(exit.position)] = exit.connectingRoom

		FactoryGlobal.activeFlowBetweenRooms[get_parent().name] = roomDictionary.duplicate(true)
		FactoryGlobal.activeFlowBetweenRooms[get_parent().name]["Exit Info"] = exitDictionary.duplicate(true)

	# Dictionary
	# Keys -> Rooms
	# Values -> Connections -> Dictionary
	# Keys -> Direction, Amount
	# Dictionary -> TestingRoom -> TestingRoom2 -> Direction - Inside
	#											-> Amount - 100
	#											-> Start - Vector2
	#							-> TestingRoom3 -> Direction - Outside
	#											-> Amount - 50
	
	#			 -> TestingRoom2 -> TestingRoom
	#			 				 -> TestingRoom3
	#			 -> TestingRoom3 -> TestingRoom
	#							 -> TestingRoom3

func are_elements_empty(elementDictionary : Dictionary[String, float]) -> bool:
	for element in FactoryGlobal.elementArray:
		if elementDictionary[element] != 0:
			return false
	
	return true

func is_splitter_balanced(pipeDictionary : Dictionary, startingPipe : String, roomName : String) -> bool:
	var gives : String = pipeDictionary[startingPipe]["Gives"]
	var splitGives : String = pipeDictionary[startingPipe]["Split Gives"]
	if pipeDictionary.has(gives) \
	and pipeDictionary.has(splitGives):
		if (pipeDictionary[gives]["Recieves"] == startingPipe or pipeDictionary[gives]["Merge Recieves"] == startingPipe) \
		and (pipeDictionary[splitGives]["Recieves"] == startingPipe or pipeDictionary[splitGives]["Merge Recieves"] == startingPipe):
			if does_path_exist(pipeDictionary, gives, roomName, false, []) == true \
			and does_path_exist(pipeDictionary, splitGives, roomName, false, []) == true:
				return true
			else:
				# Pipe loop shenanigans later
				return false
		else: 
			if is_endpoint(pipeDictionary, gives, roomName, false) and is_endpoint(pipeDictionary, splitGives, roomName, false):
				return true
			elif is_endpoint(pipeDictionary, gives, roomName, false) and does_path_exist(pipeDictionary, splitGives, roomName, false, []) == true:
				return true
			elif is_endpoint(pipeDictionary, splitGives, roomName, false) and does_path_exist(pipeDictionary, gives, roomName, false, []) == true:
				return true
			else:
				return false
	else:
		if is_endpoint(pipeDictionary, startingPipe, roomName, true) == true:
			var doesCurrentRoomHavePath : bool = false
			var doesOtherRoomHavePath : bool = false
			var connectedRoom : String = ""
			if pipeDictionary.has(gives):
				doesCurrentRoomHavePath = does_path_exist(pipeDictionary, gives, roomName, false, [])
			elif pipeDictionary.has(splitGives):
				doesCurrentRoomHavePath = does_path_exist(pipeDictionary, splitGives, roomName, false, [])
			else:
				return false
	
			if roomName == get_parent().name:
				for exit in usedExitsArray:
						connectedRoom = exit.connectingRoom
						if FactoryGlobal.activeFlowBetweenRooms.has(connectedRoom) and exit.get_direction() == "OUTSIDE":
							if FactoryGlobal.activeFlowBetweenRooms[connectedRoom].has(roomName):
								if FactoryGlobal.activeFlowBetweenRooms[connectedRoom][roomName]["Direction"] == "INSIDE":
									doesOtherRoomHavePath = does_path_exist(FactoryGlobal.activePipeLayout[connectedRoom], FactoryGlobal.activeFlowBetweenRooms[connectedRoom][roomName]["Start"], connectedRoom, false, [])
						break
			else:
				for exit in FactoryGlobal.activeFlowBetweenRooms[roomName]["Exit Info"]:
					if startingPipe == exit:
						connectedRoom = FactoryGlobal.activeFlowBetweenRooms[roomName]["Exit Info"][exit]
						if FactoryGlobal.activeFlowBetweenRooms.has(connectedRoom):
							if FactoryGlobal.activeFlowBetweenRooms[connectedRoom].has(roomName) and FactoryGlobal.activeFlowBetweenRooms[roomName].has(connectedRoom):
								if FactoryGlobal.activeFlowBetweenRooms[connectedRoom][roomName]["Direction"] == "INSIDE" and FactoryGlobal.activeFlowBetweenRooms[roomName][connectedRoom]["Direction"] == "OUTSIDE":
									doesOtherRoomHavePath = does_path_exist(FactoryGlobal.activePipeLayout[connectedRoom], FactoryGlobal.activeFlowBetweenRooms[connectedRoom][roomName]["Start"], connectedRoom, false, [])
						break
						
			if doesCurrentRoomHavePath == true and doesOtherRoomHavePath == true:
				return true
			else: 
				return false
		else:
			return false

func is_starting_point(pipeDictionary, pipeLocation : String, roomName : String) -> bool:
	if pipeDictionary.has(pipeLocation):
		if pipeDictionary[pipeLocation]["Name"] == "Extractor":
			return true
		else:
			if roomName == get_parent().name:
				if exitPipesArray.has(pipeLocation):
					for exit in exitArray:
						var exitCoords := get_grid_coordinates(exit.position)
						exitCoords = get_grid_position(exitCoords)
								
						if exitCoords == str_to_var(pipeLocation):
							if exit.get_direction() == "INSIDE":
								return true
							else:
								return false
			else:
				if FactoryGlobal.activeFlowBetweenRooms[roomName]["Exit Info"].has(pipeLocation):
					for exit in FactoryGlobal.activeFlowBetweenRooms[roomName]["Exit Info"]:
						if exit == pipeLocation:
							var connectingRoom = FactoryGlobal.activeFlowBetweenRooms[roomName]["Exit Info"][exit]
							if FactoryGlobal.activeFlowBetweenRooms[roomName][connectingRoom]["Direction"] == "INSIDE":
								return true
							else:
								return false
	
	return false

func is_endpoint(pipeDictionary, pipeLocation : String, roomName : String, areExitsEnds : bool) -> bool:
	if pipeDictionary.has(pipeLocation):
		if pipeDictionary[pipeLocation]["Name"] == "Phylactery" \
		or pipeDictionary[pipeLocation]["Name"] == "Vaporizer":
			return true
		else:
			if roomName == get_parent().name:
				if exitPipesArray.has(pipeLocation):
					for exit in exitArray:
						var exitCoords := get_grid_coordinates(exit.position)
						exitCoords = get_grid_position(exitCoords)
								
						if exitCoords == str_to_var(pipeLocation):
							if exit.get_direction() == "OUTSIDE" and areExitsEnds == true:
								return true
							else:
								return false
			else:
				if FactoryGlobal.activeFlowBetweenRooms[roomName]["Exit Info"].has(pipeLocation):
					for exit in FactoryGlobal.activeFlowBetweenRooms[roomName]["Exit Info"]:
						if exit == pipeLocation:
							var connectingRoom = FactoryGlobal.activeFlowBetweenRooms[roomName]["Exit Info"][exit]
							if FactoryGlobal.activeFlowBetweenRooms[roomName][connectingRoom]["Direction"] == "OUTSIDE" and areExitsEnds == true:
								return true
							else:
								return false
		
	return false

func does_path_exist(pipeDictionary : Dictionary, item : String, roomName : String, areExitsEnds : bool, mergerList : Array[String]) -> bool:
	var current = pipeDictionary[item]
	var currentCoords = item
	var previous = null
	var check = pipeDictionary[item]["Name"]
	var next = pipeDictionary[item]["Gives"]
	
	# Need an extra check in case starting pipe is splitter
	if is_endpoint(pipeDictionary, currentCoords, roomName, true) == true:
		if areExitsEnds == false:
			if is_endpoint(pipeDictionary, currentCoords, roomName, false) == true:
				return true
			else:
				if pipeDictionary[currentCoords]["Name"] == "Split Pipe":
					if  pipeDictionary.has(next):
						if does_path_exist(pipeDictionary, next, roomName, false, mergerList) == true:
							return true
					elif pipeDictionary.has(pipeDictionary[currentCoords]["Split Gives"]):
						if does_path_exist(pipeDictionary, pipeDictionary[currentCoords]["Split Gives"], roomName, false, mergerList) == true:
							return true
				
				var checkExit = false
				var connectedRoom = ""
				if roomName == get_parent().name:
					for exit in usedExitsArray:
						var exitCoords := get_grid_coordinates(exit.position)
						exitCoords = get_grid_position(exitCoords)
					
						if exitCoords == str_to_var(item):
							connectedRoom = exit.connectingRoom
							if FactoryGlobal.activeFlowBetweenRooms.has(connectedRoom) and exit.get_direction() == "OUTSIDE":
								if FactoryGlobal.activeFlowBetweenRooms[connectedRoom].has(roomName):
									if FactoryGlobal.activeFlowBetweenRooms[connectedRoom][roomName]["Direction"] == "INSIDE":
										checkExit = true
				else:
					if FactoryGlobal.activeFlowBetweenRooms.has(roomName):
						for exit in FactoryGlobal.activeFlowBetweenRooms[roomName]["Exit Info"]:
							if exit == currentCoords:
								connectedRoom = FactoryGlobal.activeFlowBetweenRooms[roomName]["Exit Info"][exit]
								if FactoryGlobal.activeFlowBetweenRooms[roomName].has(connectedRoom):
									if FactoryGlobal.activeFlowBetweenRooms[roomName][connectedRoom]["Direction"] == "OUTSIDE":
										checkExit = true
				if checkExit == true:
					if does_path_exist(FactoryGlobal.activePipeLayout[connectedRoom], FactoryGlobal.activeFlowBetweenRooms[connectedRoom][roomName]["Start"], connectedRoom, areExitsEnds, []) == true:
						return true
					else: 
						return false
				else: 
					return false
		else:
			return true
	elif check == "Split Pipe":
		if pipeDictionary.has(pipeDictionary[item]["Split Gives"]):
			if does_path_exist(pipeDictionary, pipeDictionary[item]["Split Gives"], roomName, areExitsEnds, mergerList) == true:
				return true
	
	while 1 == 1:
		if previous == current:
			return false
		
		previous = current
		
		for pipe in pipeDictionary:
			if pipe == next:
				if is_endpoint(pipeDictionary, pipe, roomName, true) == true:
					if areExitsEnds == false:
						if is_endpoint(pipeDictionary, pipe, roomName, false) == true:
							return true
						else: 
							if pipeDictionary[pipe]["Name"] == "Split Pipe":
								if  pipeDictionary.has(pipeDictionary[pipe]["Gives"]):
									if does_path_exist(pipeDictionary, pipeDictionary[pipe]["Gives"], roomName, false, mergerList) == true:
										return true
								elif pipeDictionary.has(pipeDictionary[pipe]["Split Gives"]):
									if does_path_exist(pipeDictionary, pipeDictionary[pipe]["Split Gives"], roomName, false, mergerList) == true:
										return true
							
							var checkExit = false
							var connectedRoom = ""
							if roomName == get_parent().name:
								for exit in usedExitsArray:
									var exitCoords := get_grid_coordinates(exit.position)
									exitCoords = get_grid_position(exitCoords)

									if exitCoords == str_to_var(pipe):
										connectedRoom = exit.connectingRoom
										if FactoryGlobal.activeFlowBetweenRooms.has(connectedRoom) and exit.get_direction() == "OUTSIDE":
											if FactoryGlobal.activeFlowBetweenRooms[connectedRoom].has(roomName):
												if FactoryGlobal.activeFlowBetweenRooms[connectedRoom][roomName]["Direction"] == "INSIDE":
													checkExit = true
							else:
								if FactoryGlobal.activeFlowBetweenRooms.has(roomName):
									for exit in FactoryGlobal.activeFlowBetweenRooms[roomName]["Exit Info"]:
										if exit == pipe:
											connectedRoom = FactoryGlobal.activeFlowBetweenRooms[roomName]["Exit Info"][exit]
											if FactoryGlobal.activeFlowBetweenRooms[roomName].has(connectedRoom):
												if FactoryGlobal.activeFlowBetweenRooms[roomName][connectedRoom]["Direction"] == "OUTSIDE":
													checkExit = true
							if checkExit == true:
								if does_path_exist(FactoryGlobal.activePipeLayout[connectedRoom], FactoryGlobal.activeFlowBetweenRooms[connectedRoom][roomName]["Start"], connectedRoom, areExitsEnds, []) == true:
									return true
								else: 
									return false
							else: 
								return false
					else:
						return true

				if pipeDictionary[pipe]["Recieves"] == currentCoords \
				or pipeDictionary[pipe]["Merge Recieves"] == currentCoords:
					check = pipeDictionary[pipe]["Name"]
					next = pipeDictionary[pipe]["Gives"]
					current = pipeDictionary[pipe]
					currentCoords = pipe
					
					if check == "Merge Pipe":
						if mergerList.has(currentCoords):
							return false
						
						mergerList.append(currentCoords)

					elif check == "Split Pipe":
						if does_path_exist(pipeDictionary, pipe, roomName, areExitsEnds, mergerList) == true:
							return true
						else:
							next = pipeDictionary[pipe]["Split Gives"]
					
					break
	
	return true
#endregion
