extends Node2D

# Grid Information
@export var GRID_SIZE := Vector2(1000, 1000)
const CELL_SIZE := Vector2(50, 50)
var CELL_AMOUNT : Vector2
const GRID_LINE_COLOR : String = "White"
const GRID_HIGHLIGHT_COLOR : String = "Magenta"

# Building Information
var extractor = preload("uid://dxqdm37qygx70")
var normalPipe = preload("uid://b5ljabl0gd3u5")
var turnPipe = preload("uid://cqy8ue3p87kvi")
var mergePipe = preload("uid://cvfg3ivtnqdxs")
var splitPipe = preload("uid://dcktntwmsputu")
var undergroundPipeStart = preload("uid://u56j8q2q6t43")
var undergroundPipeEnd = preload("uid://cxy7k3037vmg4")
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
var isBuildingUnderground : bool = false
var undergroundLocation : Vector2
var phylacteryLocation : Vector2

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
	CELL_AMOUNT = Vector2(GRID_SIZE.x / CELL_SIZE.x, GRID_SIZE.y / CELL_SIZE.y)
	
	# Add Buildings to the buildingArray
	buildingArray.append(normalPipe)
	buildingArray.append(extractor)
	buildingArray.append(turnPipe)
	buildingArray.append(mergePipe)
	buildingArray.append(splitPipe)
	buildingArray.append(undergroundPipeStart)
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
	elif Input.is_action_just_pressed("testing_cycle") and isBuildingUnderground == false:
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

# Builds the building. Puts it on the grid and gives the game all the info it needs about the building.
func spawn_building(location : Vector2) -> void:
	#for buildArea in buildingPreviewInstance.get_overlapping_areas():
	# Placeholder because I don't want to have to take time to enable build mode while I'm testing it
	# Makes it so I don't have to fix indentation later
	if 1 == 1:
		#if buildArea == get_tree().get_first_node_in_group("Player").get_node("BuildArea"):
		# Placeholder because I don't want to have to take time to enable build mode while I'm testing it
		# Makes it so I don't have to fix indentation later
		if 1 == 1:
			# Check to see if there's a pipe at that location already
			if pipeInfo.has(location) == false:
				# Keeps track of whether or not building can be built on that tile
				var canBuild = false
				
				# Variables for pipe dictionary
				# Keeps track of all the info on placed pipes
				
				# Name of the building
				var nameBuilding : String
				
				# Where the pipes connect - which location feeds into this pipe?
				var recieves : Vector2
				
				# Mergers have two locations for this, so they need an extra. 
				# For everyone else it's (-100, -100)
				var mergeRecieves := Vector2(-100, -100)
				
				# Where the pipes connect - which location does this feed out to?
				var gives : Vector2
				
				# Splitters feed out into two locations, so they need an extra one
				# For everyone else it's (-100, -100)
				var splitGives := Vector2(-100, -100)
				
				# The list of resources that can run through the pipes
				# Defaults to an amount of 0 for everything but the things that pull the resource from the environment
				var sourceDictionary : Dictionary[String, float] = {"Water" : 0, "Fire" : 0, "Air" : 0, "Earth" : 0}
				
				# Each pipe has unique info, so check the type of pipe and populate the info accordingly
				# Some have unique circumstances where they can't be placed, so check that too
				# Each pipe has a script that says which direction it's facing. That's used to determine which tiles connect to it
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
				
				# After an underground pipe is placed, the end point must be placed
				# The gives value is set once the end is placed
				if selectedBuilding == undergroundPipeStart:
					canBuild = true
					nameBuilding = "Underground Pipe Start"
					recieves = get_grid_coordinates(location) + NormalPipe.get_normal_pipe_recieves(buildingRotation, flip)
					recieves = get_grid_position(recieves)
					undergroundLocation = cursor_snap()
					isBuildingUnderground = true
				
				# Sets it's recieves variable based on where the first underground was placed
				# Sets the first underground pipe's gives based on its own location
				if selectedBuilding == undergroundPipeEnd:
					canBuild = true
					nameBuilding = "Underground Pipe End"
					recieves = undergroundLocation
					gives = get_grid_coordinates(location) + NormalPipe.get_normal_pipe_gives(buildingRotation, flip)
					gives = get_grid_position(gives)
					pipeInfo[undergroundLocation]["Gives"] = cursor_snap()
				
				if selectedBuilding == vaporizer:
					canBuild = true
					nameBuilding = "Vaporizer"
					recieves = get_grid_coordinates(location) + NormalPipe.get_normal_pipe_recieves(buildingRotation, flip)
					recieves = get_grid_position(recieves)
				
				# Extractors can only be placed on resource tiles
				# The first check makes sure that it is overlapping it (a source)
				# Extractors are the only one to have an element value set on creation as well
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
				
				# Only one phylactery can be placed on each map/scene
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
					
					# Places the visuals for the pipe and adds it to the Building Global Group
					%Buildings.add_child(building)
					building.position = cursor_snap() + (CELL_SIZE / 2)
					if flip == true:
						building.scale.x = -1
					building.get_node("Sprite2D").rotate(deg_to_rad(buildingRotation))
					building.add_to_group("Buildings")
					
					# Need to make sure the end point of an underground pipe is placed immediately after the start point
					if selectedBuilding == undergroundPipeStart or selectedBuilding == undergroundPipeEnd:
						select_building()
						isBuildingUnderground = false
					
					# Calculates the resources running through the factory
					recalculate_factory()

func delete_building(location : Vector2) -> void:
	if pipeInfo.has(location) == true:
		for body in buildingPreviewInstance.get_overlapping_areas():
			if body.is_in_group("Buildings"):
				pipeInfo.erase(location)
				body.queue_free()
				
		recalculate_factory()

func select_building() -> void:
	if isBuildingUnderground == false:
		if selectedBuilding == null or selectedBuilding == undergroundPipeEnd:
			selectedBuilding = normalPipe
			selectedBuildingIndex = 0
		else: 
			selectedBuildingIndex += 1
			if selectedBuildingIndex >= buildingArray.size():
				selectedBuildingIndex = 0
			selectedBuilding = buildingArray[selectedBuildingIndex]
	else:
		selectedBuilding = undergroundPipeEnd
	
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
			var pathArray = find_pipe_path(item, [])
			if pathArray != []:
				# If a path is found, calculate how many resources are going through the pipe path
				calculate_flow(pathArray, [], pipeInfo[item]["Elements"], false)
				
				# If the path includes a phylactery, update the global variables for the values going into it
				if phylacteryLocation != Vector2(-100, -100):
					waterAmount = pipeInfo[phylacteryLocation]["Elements"]["Water"]
					fireAmount = pipeInfo[phylacteryLocation]["Elements"]["Fire"]
					airAmount = pipeInfo[phylacteryLocation]["Elements"]["Air"]
					earthAmount = pipeInfo[phylacteryLocation]["Elements"]["Earth"]
	
	# Update the player's stats based on the resources going through the factory
	# The values are stored in a global class, which then updates the player
	FactoryGlobal.get_total_water(waterAmount)
	FactoryGlobal.get_total_fire(fireAmount)
	FactoryGlobal.get_total_air(airAmount)
	FactoryGlobal.get_total_earth(earthAmount)
	print("Water")
	print(waterAmount)

# Sees if a path to an end point can be found
# Right now, the only end points are the phylactery and vaporizer
# item is the location of the starting pipe
# mergerList is a list of Merge Pipes to check for looping pipes
# Returns an array of pipes connected to each other if an end point is found
# Returns an empty array if no end point is found
func find_pipe_path(item : Vector2, mergerList : Array[Vector2]) -> Array[Vector2]:
	# The array of connected pipes. This is returned if a path is found
	var pathArray : Array[Vector2] = []
	
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
	if check == "Phylactery" or check == "Vaporizer":
		pathArray.append(currentCoords)
		if check == "Phylactery":
			phylacteryLocation = currentCoords
		return pathArray
	
	# Check to see if you've gotten to the Phylactery
	while check != "Phylactery":
		# The current pipe gets added to the array every loop
		pathArray.append(currentCoords)
		
		# Escape the loop if Phylactery is not found
		if previous == current:
			return []
		
		# Update previous to the current pipe. If current and previous are the same we've run out of pipes to look through
		previous = current
		
		# Loop through all the pipes until you've found an end point or the next pipe in the chain
		for pipe in pipeInfo:
			if pipe == next:
				if pipeInfo[pipe]["Name"] == "Phylactery" or pipeInfo[pipe]["Name"] == "Vaporizer":
					pathArray.append(pipe)
					if pipeInfo[pipe]["Name"] == "Phylactery":
						phylacteryLocation = pipe
					
					return pathArray
				
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
							return []
						
						# If it's new, add it to the list just in case this one loops
						mergerList.append(currentCoords)
					
					# If the pipe is a split pipe, we need to check both sides
					# First, check the gives side. If you find something, great a path exists
					# If no end point exists on one path, try the other one
					elif check == "Split Pipe":
						var splitPath : Array[Vector2] = find_pipe_path(pipe, mergerList)
						if splitPath != []:
							pathArray.append_array(splitPath)
							return pathArray
						else:
							next = pipeInfo[pipe]["Split Gives"]
					
					# Don't need to keep looping through the dictinary once we find the next one
					break
	
	return pathArray

# Now that we know a path exists, calculate the resource amounts flowing through the path
# pathArray is an array of pipe locations that make up the found path
# mergerList is a list of Merge Pipes we've passed. There to make sure there's no infinite recursion if there's a chain of pipes that make a circle
# originalAmount is the amount in the initial extractor. Necessary for looping pipes
# recursionLoop checks if we're going through a looping pipe
# Returns nothing, but all the resource values are updated in each pipe
func calculate_flow(pathArray : Array[Vector2], mergerList : Array[Vector2], originalAmount : Dictionary, recursionLoop : bool) -> void:

	# First pipe in the path
	var first = pipeInfo[pathArray[0]]
	
	# The first splitter encountered - stays null if there's no splitters
	var baseSplit = null
	
	# If there's a circle of pipes, get the first merger in the loop
	var recursivePipe := Vector2(-100, 100)
	print("--------------------------")
	
	for index in pathArray.size():
		
		# Check for looping pipes first. They need special logic
		# Their resource is based on what's going through the pipe added to the original amount from the extractor
		if pipeInfo[pathArray[index]]["Name"] == "Merge Pipe":
			if mergerList.has(pathArray[index]):
				print("***!***!***!***!***!***!***!***")
				print("RECURSIVE PIPE ABORT ABORT")
				print("***!***!***!***!***!***!***!***")
				mergerList.clear()
				mergerList.append(pathArray[index])
				recursivePipe = pathArray[index]
				var elementCheck
				
				# Once the difference between the amount of resources from the current loop and previous loop is small, stop looping
				for element in originalAmount:
					if originalAmount[element] > 0:
						elementCheck = element
				
				var previousLoop : float = pipeInfo[pathArray[index]]["Elements"][elementCheck]
				var nextLoop : float = originalAmount[elementCheck] + first["Elements"][elementCheck]
				
				print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
				print(pipeInfo[pathArray[index]])
				print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
				print(nextLoop)
				print(previousLoop)
				print(originalAmount[elementCheck] / 1000)
				print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
				if nextLoop - previousLoop >= originalAmount[elementCheck] / 1000:
					recursionLoop = true
					for element in pipeInfo[pathArray[index]]["Elements"]:
						pipeInfo[pathArray[index]]["Elements"][element] = originalAmount[element] + first["Elements"][element]
				else:
					return
				
				first = pipeInfo[pathArray[index]]
				
			else:
				# If it's a new merger, add it to the mergerList
				mergerList.append(pathArray[index])
		
		# If we're in the middle of a loop of pipes, set it to the amounts in the merger instead of adding it to what's already there
		if recursionLoop == true and first != pipeInfo[pathArray[index]] and pathArray[index] != recursivePipe:
			for element in pipeInfo[pathArray[index]]["Elements"]:
				pipeInfo[pathArray[index]]["Elements"][element] = first["Elements"][element]
		
		# If we're just going through normally, add the value inside the pipe to the value coming through
		# Keeps things accurate if multiple extractors are flowing through this route
		elif first != pipeInfo[pathArray[index]] and pipeInfo[pathArray[index]]["Name"] != "Extractor":
			for element in pipeInfo[pathArray[index]]["Elements"]:
				pipeInfo[pathArray[index]]["Elements"][element] += first["Elements"][element]
		
		#if pipeInfo[pathArray[index]]["Name"] == "Phylactery" or pipeInfo[pathArray[index]]["Name"] == "Vaporizer":
		print(pipeInfo[pathArray[index]])
		print("--------------------------")
		
		# If splitters exist we have to do all kinds of shenanigans
		# This gets the splitter so we can check all its paths
		if pipeInfo[pathArray[index]]["Name"] == "Split Pipe":
			baseSplit = pipeInfo[pathArray[index]]
			break
	
	# If a splitter exists, we must check all its paths
	# Splitter logic is like this
	# If both sides lead somewhere, the resources in it is split equally
	# If one side is a dead end, it becomes a normal pipe
	# 100% of the resources flowing through it go to that side
	# If neither side goes anywhere, it's a dead end and can be ignored
	# If the pipe is looping, we don't add to the existing value, we set it to the value in the first splitter
	# Multiple resources can go in each pipe
	if baseSplit != null:
		var gives = baseSplit["Gives"]
		var splitGives = baseSplit["Split Gives"]
		
		# Both the points that feed out of the splitter have a pipe on the tile
		if pipeInfo.has(gives) == true and pipeInfo.has(splitGives) == true:
			
			# Check to see if both sides actually have a path
			var givesPath : Array[Vector2] = find_pipe_path(gives, [])
			var splitsPath : Array[Vector2] = find_pipe_path(splitGives, [])
			
			# If both sides reach an end point, split the resources in them
			if givesPath != [] and splitsPath != []:
				if recursionLoop == true:
					for element in baseSplit["Elements"]:
						pipeInfo[gives]["Elements"][element] = baseSplit["Elements"][element] / 2
						pipeInfo[splitGives]["Elements"][element] = baseSplit["Elements"][element] / 2
				else:
					for element in baseSplit["Elements"]:
						pipeInfo[gives]["Elements"][element] += baseSplit["Elements"][element] / 2
						pipeInfo[splitGives]["Elements"][element] += baseSplit["Elements"][element] / 2
				
				# Then continue calculating from here
				calculate_flow(givesPath, mergerList, originalAmount, recursionLoop)
				if recursionLoop == false:
					calculate_flow(splitsPath, mergerList, originalAmount, recursionLoop)
			
			# If only one side has an end point, don't divide the resources
			elif givesPath != [] and splitsPath == []:
				if recursionLoop == true:
					for element in baseSplit["Elements"]:
						pipeInfo[gives]["Elements"][element] = baseSplit["Elements"][element]
				else: 
					for element in baseSplit["Elements"]:
						pipeInfo[gives]["Elements"][element] += baseSplit["Elements"][element]
				
				# Then continue calculating from here
				calculate_flow(givesPath, mergerList, originalAmount, recursionLoop)
			
			# If only one side has an end point, don't divide the resources - but for the other side
			elif givesPath == [] and splitsPath != []:
				if recursionLoop == true:
					for element in baseSplit["Elements"]:
						pipeInfo[splitGives]["Elements"][element] = baseSplit["Elements"][element]
				else:
					
					for element in baseSplit["Elements"]:
						pipeInfo[splitGives]["Elements"][element] += baseSplit["Elements"][element]
				
				# Then continue calculating from here
				calculate_flow(splitsPath, mergerList, originalAmount, recursionLoop)
		
		# Only one spot that the splitter feeds out to has a pipe on it
		elif pipeInfo.has(gives) == true and pipeInfo.has(splitGives) == false:
			
			# Make sure a path actually exists and we're not trying to feed into the pipe sideways or something
			var newPath = find_pipe_path(gives, [])
			
			if newPath != []:
				if recursionLoop == true:
					for element in baseSplit["Elements"]:
						pipeInfo[gives]["Elements"][element] = baseSplit["Elements"][element]
				else:
					for element in baseSplit["Elements"]:
						pipeInfo[gives]["Elements"][element] += baseSplit["Elements"][element]
				
				# Then continue calculating from here
				calculate_flow(newPath, mergerList, originalAmount, recursionLoop)
		
		# Only one spot that the splitter feeds out to has a pipe on it - but it's the other side from the above
		elif pipeInfo.has(gives) == false and pipeInfo.has(splitGives) == true:
			
			# Make sure a path actually exists and we're not trying to feed into the pipe sideways or something
			var newPath = find_pipe_path(splitGives, [])
			
			if newPath != []:
				if recursionLoop == true:
					for element in baseSplit["Elements"]:
						pipeInfo[splitGives]["Elements"][element] = baseSplit["Elements"][element]
				else:
					for element in baseSplit["Elements"]:
						pipeInfo[splitGives]["Elements"][element] += baseSplit["Elements"][element]
				
				# Then continue calculating from here
				calculate_flow(newPath, mergerList, originalAmount, recursionLoop)
