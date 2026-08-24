extends Node

# Global Factory Constants
const CELL_SIZE := Vector2(50, 50)
const HALF_CELL_SIZE := Vector2(25, 25)
const GRID_LINE_COLOR : String = "White"
const GRID_HIGHLIGHT_COLOR : String = "Magenta"
const GRID_GOOD_COLOR : String = "Green"
const GRID_ERROR_COLOR : String = "Red"
const GRID_OUTSIDE_BUILD_AREA_COLOR : String = "Cyan"
const GRID_TRANSFORM_COLOR : String = "Blue"
const GRID_REPLACE_COLOR : String = "Purple"
const GRID_SELECTION_OUTLINE_COLOR : String = "Black"
const GRID_BOX_OUTLLINE_THICKNESS : float = 5.0
const factoryOpacity : float = .75
const buildAreaRadius : float = 285.0

# Buildings
var buildingArray = []
var extractor = preload("uid://dxqdm37qygx70")
var normalPipe = preload("uid://b5ljabl0gd3u5")
var turnPipe = preload("uid://cqy8ue3p87kvi")
var mergePipe = preload("uid://cvfg3ivtnqdxs")
var splitPipe = preload("uid://dcktntwmsputu")
var undergroundPipeStart = preload("uid://u56j8q2q6t43")
var undergroundPipeEnd = preload("uid://cxy7k3037vmg4")
var phylactery = preload("uid://rwrddigeppfh")
var vaporizer = preload("uid://ct6w6os54d0fy")

# Player Stats
var elementArray
var waterAmount : float = 0
var fireAmount : float = 0
var airAmount : float = 0
var earthAmount : float = 0

var player : Player
var activePipeLayout : Dictionary
var activeFlowBetweenRooms : Dictionary
var activePhylacteryValues : Dictionary
var blueprintDictionary : Dictionary
var selectedBlueprint : Dictionary
var blueprintChunk : Dictionary
var selectedBuildingBetweenRooms
var selectedBuildingIndexBetweenRooms : int
var rotationBetweenRooms : int
var flipBetweenRooms : bool
var isGridOn : bool = true
var disableInput : bool = false

func _ready() -> void:
	buildingArray.append(normalPipe)
	buildingArray.append(extractor)
	buildingArray.append(turnPipe)
	buildingArray.append(mergePipe)
	buildingArray.append(splitPipe)
	buildingArray.append(undergroundPipeStart)
	buildingArray.append(phylactery)
	buildingArray.append(vaporizer)
	
	if elementArray == null:
		elementArray = ["Water", "Fire", "Earth", "Air"]
	
	if not selectedBuildingBetweenRooms:
		selectedBuildingBetweenRooms = normalPipe
	
	player = null
	
	while not player:
		await get_tree().process_frame
		player = get_tree().get_first_node_in_group("Player")

func get_elements_total():
	waterAmount = 0
	fireAmount = 0
	airAmount = 0
	earthAmount = 0
	
	for room in activePhylacteryValues:
		for element in activePhylacteryValues[room]:
			if element == "Water":
				waterAmount += activePhylacteryValues[room][element]
			elif element == "Fire":
				fireAmount += activePhylacteryValues[room][element]
			elif element == "Air":
				airAmount += activePhylacteryValues[room][element]
			elif element == "Earth":
				earthAmount += activePhylacteryValues[room][element]

	player.update_stats()
