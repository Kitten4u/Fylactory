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
var phylactery = preload("uid://rwrddigeppfh")
var buildingArray = []
var sourceArray : Array[Source]

# Build Mode Information
var selectedBuilding = normalPipe
var selectedBuildingIndex : int = 0
var buildingPreviewInstance
var pipeInfo : Dictionary
var buildingRotation : int = 0
var buildingFlipHorizontal : bool = false
var buildingFlipVertical : bool = false

# Total Element Counters
var waterAmount = 0
var fireAmount = 0
var airAmount = 0
var earthAmount = 0

func _ready() -> void:
	# Add Buildings to the buildingArray
	buildingArray.append(normalPipe)
	buildingArray.append(extractor)
	buildingArray.append(turnPipe)
	buildingArray.append(phylactery)
	
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
		flip_building("Horizontal")
	elif Input.is_action_just_pressed("flip_vertical"):
		flip_building("Vertical")
	
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
	# Check to see if there's a pipe at that location
	if pipeInfo.has(location) == false:
		# Keeps track of whether or not building can be built on that tile
		var canBuild = false
		
		# Variables for pipe dictionary
		var name : String
		var recieves : Vector2
		var gives : Vector2
		var sourceType : String
		var sourceAmount : float
		
		# Keeps track of building facing
		#var facing : int = get_building_facing()
		
		# If there's nothing there, build the selected building
		if selectedBuilding == normalPipe:
			canBuild = true
			name = "Normal Pipe"
			recieves = normalPipe
			gives = get_grid_coordinates(location) + Vector2(1, 0)
		
		elif selectedBuilding == turnPipe:
			canBuild = true
			name = "Turn Pipe"
			recieves = Vector2(0, 0)
			gives = Vector2(0, 0)
			
		elif selectedBuilding == extractor: 
			# Check where all the sources are
			for source in sourceArray:
				# Check to see if the buildingPreview overlaps with the source
				for body in source.get_overlapping_areas():
					if body == buildingPreviewInstance:
						canBuild = true
						name = "Extractor"
						gives = get_grid_position(gives)
						recieves = Vector2.ZERO
						sourceType = source.type
						sourceAmount = source.amount
						continue
						
		elif selectedBuilding == phylactery:
			if pipeInfo.size() != 0:
				for item in pipeInfo:
					var valueArray = pipeInfo[item].values()
					if valueArray.has("Phylactery") == true:
						return
			
			canBuild = true
			name = "Phylactery"
			recieves = Vector2(0, 0)
			gives = Vector2.ZERO
				
		if canBuild == true:
			var building = selectedBuilding.instantiate()
			
			pipeInfo[location] = {
				"Name" : name, 
				"X" : location.x, 
				"Y" : location.y, 
				"Rotation" : buildingRotation, 
				"Flip H" : buildingFlipHorizontal, 
				"Flip V" : buildingFlipVertical, 
				"Recieves" : recieves, 
				"Gives" : gives, 
				"Type" : sourceType, 
				"Amount" : sourceAmount
			}
			
			get_parent().add_child(building)
			building.position = cursor_snap() + (CELL_SIZE / 2)
			if buildingFlipHorizontal == true:
				building.scale.x = -1
			if buildingFlipVertical == true:
				building.scale.y = -1
			building.rotate(deg_to_rad(buildingRotation))
			building.add_to_group("Buildings")
			
			recalculate_factory()

func delete_building(location : Vector2) -> void:
	if pipeInfo.has(location) == true:
		for body in buildingPreviewInstance.get_overlapping_areas():
			if body.is_in_group("Buildings"):
				body.queue_free()
				pipeInfo.erase(location)

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
	if buildingFlipHorizontal == true:
		buildingPreviewInstance.scale.x = -1
	if buildingFlipVertical == true:
		buildingPreviewInstance.scale.y = -1
	buildingPreviewInstance.rotate(deg_to_rad(buildingRotation))
	buildingPreviewInstance.modulate.a = 0.7

func rotate_building(direction : int) -> void:
	buildingRotation += direction
	if buildingRotation >= 360 or buildingRotation <= -360:
		buildingRotation = 0
	buildingPreviewInstance.rotate(deg_to_rad(direction))

func flip_building(type : String) -> void:
	# Rotate building back to default before flipping
	buildingPreviewInstance.rotate(deg_to_rad(-buildingRotation))
	
	if type == "Horizontal":
		if buildingFlipHorizontal == false:
			buildingPreviewInstance.get_node("Sprite2D").scale.x = -1
		else:
			buildingPreviewInstance.get_node("Sprite2D").scale.x = 1
		buildingFlipHorizontal = !buildingFlipHorizontal
	else:
		if buildingFlipVertical == false:
			buildingPreviewInstance.get_node("Sprite2D").scale.y = -1
		else:
			buildingPreviewInstance.get_node("Sprite2D").scale.y = 1
		buildingFlipVertical = !buildingFlipVertical
	
	# Rotate building back after flipping
	buildingPreviewInstance.rotate(deg_to_rad(buildingRotation))

func get_grid_position(cellPosition : Vector2) -> Vector2:
	return cellPosition * CELL_SIZE

func get_grid_coordinates(gridPosition : Vector2) -> Vector2:
	return floor(gridPosition / CELL_SIZE)

func cursor_snap() -> Vector2:
	var cursorPosition := Vector2(get_global_mouse_position().x, get_global_mouse_position().y)
	var cursorCoords := get_grid_coordinates(cursorPosition)
	return get_grid_position(cursorCoords)

func recalculate_factory():
	# Iterate through extrators first
	for item in pipeInfo:
		if pipeInfo[item]["Name"] == "Extractor":
			
			if build_pipe_path(item) == true:
				print(pipeInfo[item]["Type"])
				if pipeInfo[item]["Type"] == "Water":
					waterAmount += pipeInfo[item]["Amount"]
				elif pipeInfo[item]["Type"] == "Fire":
					fireAmount += pipeInfo[item]["Amount"]
				elif pipeInfo[item]["Type"] == "Air":
					airAmount += pipeInfo[item]["Amount"]
				elif pipeInfo[item]["Type"] == "Earth":
					earthAmount += pipeInfo[item]["Amount"]
	
	FactoryGlobal.get_total_water(waterAmount)
	FactoryGlobal.get_total_fire(fireAmount)
	FactoryGlobal.get_total_air(airAmount)
	FactoryGlobal.get_total_earth(earthAmount)

func build_pipe_path(item : Vector2) -> bool:
	var current = pipeInfo[item]
	var previous = null
	var check = pipeInfo[item]["Name"]
	var next = pipeInfo[item]["Gives"]
	
	# Check to see if you've gotten to the Phylactery
	while check != "Phylactery":
		# Escape the loop if Phylactery is not found
		if previous == current:
			return false
		previous = current
		for pipe in pipeInfo:
			if pipeInfo[pipe]["Recieves"] == next:
				check = pipeInfo[pipe]["Name"]
				next = pipeInfo[pipe]["Gives"]
				current = pipeInfo[pipe]
	
	return true
