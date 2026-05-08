extends Node2D

# Grid Information
var GRID_SIZE := Vector2(1000, 1000)
const CELL_SIZE := Vector2(50, 50)
var CELL_AMOUNT := Vector2(GRID_SIZE.x / CELL_SIZE.x, GRID_SIZE.y / CELL_SIZE.y)
const GRID_LINE_COLOR : String = "White"
const GRID_HIGHLIGHT_COLOR : String = "Magenta"

# Building Information
var extractor = preload("uid://dxqdm37qygx70")
var normalPipe = preload("uid://b5ljabl0gd3u5")
var turnPipe = preload("uid://cqy8ue3p87kvi")
var mergePipe = preload("uid://cvfg3ivtnqdxs")
var splitPipe = preload("uid://dcktntwmsputu")
var phylactery = preload("uid://rwrddigeppfh")
var vaporizer = preload("uid://ct6w6os54d0fy")
var buildingArray = []
var sourceArray : Array[Source]

# Build Mode Information
var selectedBuilding = normalPipe
var selectedBuildingIndex : int = 0
var buildingPreviewInstance
var pipeInfo : Dictionary
var buildingRotation : int = 0
var flip : bool = false
var hasSplitters : bool = false
var pathArray :Array = []

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
	# Add Buildings to the buildingArray
	buildingArray.append(normalPipe)
	buildingArray.append(extractor)
	buildingArray.append(turnPipe)
	buildingArray.append(mergePipe)
	buildingArray.append(splitPipe)
	buildingArray.append(phylactery)
	buildingArray.append(vaporizer)
	
	# Create the building preview
	buildingPreviewInstance = selectedBuilding.instantiate()
	add_child(buildingPreviewInstance)
	buildingPreviewInstance.modulate.a = 0.7
	
	# Add Sources to sourceArray
	for source in %Sources.get_children():
		if source is Source:
			sourceArray.append(source)

func _process(_delta: float) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		spawn_building(cursor_snap())
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		delete_building(cursor_snap())
	elif Input.is_action_just_pressed("rotate_left"):
		rotate_building(-90)
	elif Input.is_action_just_pressed("rotate_right"):
		rotate_building(90)
	elif Input.is_action_just_pressed("testing_cycle"):
		select_building()
	elif Input.is_action_just_pressed("flip_horizontal"):
		flip_building()
	
	buildingPreviewInstance.position = cursor_snap() + CELL_SIZE / 2
	
	queue_redraw()

func _draw() -> void:
	for i in CELL_AMOUNT.x:
		var lineTop := Vector2(i * CELL_SIZE.x, 0)
		var lineBottom := Vector2(i * CELL_SIZE.x, GRID_SIZE.y)
		draw_line(lineTop, lineBottom, GRID_LINE_COLOR)
	
	for i in CELL_AMOUNT.y:
		var lineLeft := Vector2(0, CELL_SIZE.y * i)
		var lineRight := Vector2(GRID_SIZE.x, lineLeft.y)
		draw_line(lineLeft, lineRight, GRID_LINE_COLOR)
	
	draw_rect(highlight_cell(), GRID_HIGHLIGHT_COLOR)

func highlight_cell() -> Rect2:
	return Rect2(cursor_snap(), CELL_SIZE)

func spawn_building(location : Vector2) -> void:
	#for buildArea in buildingPreviewInstance.get_overlapping_areas():
	if 1 == 1:
		#if buildArea == get_tree().get_first_node_in_group("Player").get_node("BuildArea"):
		if 1 == 1:
			# Check to see if there's a pipe at that location
			if pipeInfo.has(location) == false:
				# Keeps track of whether or not building can be built on that tile
				var canBuild = false
				
				# Variables for pipe dictionary
				var nameBuilding : String
				var recieves : Vector2
				var mergeRecieves : Vector2
				var gives : Vector2
				var splitGives : Vector2
				var sourceDictionary : Dictionary[String, float] = {"Water" : 0, "Fire" : 0, "Air" : 0, "Earth" : 0}
				
				# If there's nothing there, build the selected building
				if selectedBuilding == normalPipe:
					canBuild = true
					nameBuilding = "Normal Pipe"
					recieves = get_grid_coordinates(location) + NormalPipe.get_normal_pipe_recieves(buildingRotation, flip)
					recieves = get_grid_position(recieves)
					gives = get_grid_coordinates(location) + NormalPipe.get_normal_pipe_gives(buildingRotation, flip)
					gives = get_grid_position(gives)
				
				elif selectedBuilding == turnPipe:
					canBuild = true
					nameBuilding = "Turn Pipe"
					recieves = get_grid_coordinates(location) + TurnPipe.get_turn_pipe_recieves(buildingRotation, flip)
					recieves = get_grid_position(recieves)
					gives = get_grid_coordinates(location) + TurnPipe.get_turn_pipe_gives(buildingRotation, flip)
					gives = get_grid_position(gives)
				
				elif selectedBuilding == mergePipe:
					canBuild = true
					nameBuilding = "Merge Pipe"
					recieves = get_grid_coordinates(location) + MergePipe.get_merge_pipe_recieves(buildingRotation, flip)
					recieves = get_grid_position(recieves)
					mergeRecieves = get_grid_coordinates(location) + MergePipe.get_merge_pipe_merges(buildingRotation, flip)
					mergeRecieves = get_grid_position(mergeRecieves)
					gives = get_grid_coordinates(location) + MergePipe.get_merge_pipe_gives(buildingRotation, flip)
					gives = get_grid_position(gives)
				
				elif selectedBuilding == splitPipe:
					canBuild = true
					nameBuilding = "Split Pipe"
					recieves = get_grid_coordinates(location) + SplitPipe.get_split_pipe_recieves(buildingRotation, flip)
					recieves = get_grid_position(recieves)
					gives = get_grid_coordinates(location) + SplitPipe.get_split_pipe_gives(buildingRotation, flip)
					gives = get_grid_position(gives)
					splitGives = get_grid_coordinates(location) + SplitPipe.get_split_pipe_splits(buildingRotation, flip)
					splitGives = get_grid_position(splitGives)
				
				if selectedBuilding == vaporizer:
					canBuild = true
					nameBuilding = "Vaporizer"
					recieves = get_grid_coordinates(location) + NormalPipe.get_normal_pipe_recieves(buildingRotation, flip)
					recieves = get_grid_position(recieves)
					
				elif selectedBuilding == extractor: 
					# Check where all the sources are
					for source in sourceArray:
						# Check to see if the buildingPreview overlaps with the source
						for body in source.get_overlapping_areas():
							if body == buildingPreviewInstance:
								canBuild = true
								nameBuilding = "Extractor"
								gives = get_grid_coordinates(location) + Extractor.get_extractor_gives(buildingRotation, flip)
								gives = get_grid_position(gives)
								recieves = Vector2.ZERO
								var elementCounter = 0
								for type in source.type:
									sourceDictionary[type] = source.amount[elementCounter]
									elementCounter += 1
								continue
								
				elif selectedBuilding == phylactery:
					if pipeInfo.size() != 0:
						for item in pipeInfo:
							var valueArray = pipeInfo[item].values()
							if valueArray.has("Phylactery") == true:
								return
					
					canBuild = true
					nameBuilding = "Phylactery"
					recieves = get_grid_coordinates(location) + Phylactery.get_phylactery_recieves(buildingRotation)
					recieves = get_grid_position(recieves)
					gives = Vector2.ZERO
						
				if canBuild == true:
					var building = selectedBuilding.instantiate()
					
					pipeInfo[location] = {
						"Name" : nameBuilding, 
						"X" : location.x, 
						"Y" : location.y, 
						"Rotation" : buildingRotation, 
						"Flip" : flip, 
						"Recieves" : recieves, 
						"Merge Recieves" : mergeRecieves,
						"Gives" : gives, 
						"Split Gives" : splitGives,
						"Elements" : sourceDictionary, 
					}
					
					get_parent().add_child(building)
					building.position = cursor_snap() + (CELL_SIZE / 2)
					if flip == true:
						building.scale.x = -1
					building.get_node("Sprite2D").rotate(deg_to_rad(buildingRotation))
					building.add_to_group("Buildings")
					
					recalculate_factory()

func delete_building(location : Vector2) -> void:
	if pipeInfo.has(location) == true:
		for body in buildingPreviewInstance.get_overlapping_areas():
			if body.is_in_group("Buildings"):
				pipeInfo.erase(location)
				body.queue_free()
				
		recalculate_factory()

func select_building() -> void:
	if selectedBuilding == null:
		selectedBuilding = normalPipe
		selectedBuildingIndex = 0
	else: 
		selectedBuildingIndex += 1
		if selectedBuildingIndex >= buildingArray.size():
			selectedBuildingIndex = 0
		selectedBuilding = buildingArray[selectedBuildingIndex]
	
	# Delete old preview
	buildingPreviewInstance.queue_free()
	
	# Generate new preview
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
	return cellPosition * CELL_SIZE

func get_grid_coordinates(gridPosition : Vector2) -> Vector2:
	return floor(gridPosition / CELL_SIZE)

func cursor_snap() -> Vector2:
	var cursorPosition := Vector2(get_global_mouse_position().x, get_global_mouse_position().y)
	var cursorCoords := get_grid_coordinates(cursorPosition)
	return get_grid_position(cursorCoords)

func recalculate_factory():
	# Reset energy
	waterAmount = 0
	fireAmount = 0
	airAmount = 0
	earthAmount = 0
	
	for pipe in pipeInfo:
		if pipeInfo[pipe]["Name"] != "Extractor":
			for element in pipeInfo[pipe]["Elements"]:
				pipeInfo[pipe]["Elements"][element] = 0
	
	# Iterate through extrators first
	for item in pipeInfo:
		if pipeInfo[item]["Name"] == "Extractor":
			pathArray.clear()
			
			# How much energy is coming out of the sources
			# Whether there is a valid path 
			# Above is all I need if no splitters
			# For Splitters to work
			# Does splitter exist
			# Do both sides end in something that uses energy
			# How much energy is going through them OR potentially just number of splits?
			if find_pipe_path(item) == true:
				if hasSplitters == false:
					calculate_flow(pathArray)
					
					var last = pipeInfo[pathArray[-1]]
					if last["Name"] == "Phylactery":
						waterAmount = last["Elements"]["Water"]
						fireAmount = last["Elements"]["Fire"]
						airAmount = last["Elements"]["Air"]
						earthAmount = last["Elements"]["Earth"]
				else:
					# Do shenanigans
					pass
	
	FactoryGlobal.get_total_water(waterAmount)
	FactoryGlobal.get_total_fire(fireAmount)
	FactoryGlobal.get_total_air(airAmount)
	FactoryGlobal.get_total_earth(earthAmount)
	print("Water")
	print(waterAmount)

func find_pipe_path(item : Vector2) -> bool:
	var current = pipeInfo[item]
	var currentCoords = item
	var previous = null
	var check = pipeInfo[item]["Name"]
	var next = pipeInfo[item]["Gives"]
	
	# Check to see if you've gotten to the Phylactery
	while check != "Phylactery":
		pathArray.append(currentCoords)
		# Escape the loop if Phylactery is not found
		if previous == current:
			return false
		previous = current
		for pipe in pipeInfo:
			if pipe == next:
				if pipeInfo[pipe]["Name"] == "Phylactery" or pipeInfo[pipe]["Name"] == "Vaporizer":
					pathArray.append(pipe)
					return true
				
				if pipeInfo[pipe]["Recieves"] == currentCoords \
				or pipeInfo[pipe]["Merge Recieves"] == currentCoords:
					check = pipeInfo[pipe]["Name"]
					next = pipeInfo[pipe]["Gives"]
					current = pipeInfo[pipe]
					currentCoords = pipe
					
					if check == "Split Pipe":
						hasSplitters = true
						if find_pipe_path(pipe) == true:
							return true
						else:
							next = pipeInfo[pipe]["Split Gives"]
	
	return true

func calculate_flow(pipeArray : Array) -> void:
	var first = pipeInfo[pipeArray[0]]
	for pipe in pipeArray:
		if pipeInfo[pipe]["Name"] != "Extractor":
			for element in pipeInfo[pipe]["Elements"]:
				pipeInfo[pipe]["Elements"][element] += first["Elements"][element]
