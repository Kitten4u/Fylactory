extends Node

const SLOTS : Array[String] = [
	"save1", "save2", "save3"
]

var currentSlot : int = 0
var saveData : Dictionary
var discoveredAreas : Array = []
var persistentData : Dictionary = {}

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_I:
			print("Temp Save")
			save_game()
		elif event.keycode == KEY_O:
			print("Temp Load")
			load_game()

func create_new_game_save() -> void:
	var newGameScene : String = "uid://dpxba218vm1lf"
	discoveredAreas.append(newGameScene)
	
	saveData = {
		"Scene" : newGameScene,
		"X" : 587.0,
		"Y" : 603.0,
		"HP" : 20,
		"Factory" : {},
		"Blueprints" : {},
		"Elements" : ["Water", "Fire", "Air", "Earth"],
		"Discovered Areas" : discoveredAreas,
		"Persistent Data" : persistentData
	}
	
	var saveFile = FileAccess.open(get_file_name(), FileAccess.WRITE)
	saveFile.store_line(JSON.stringify(saveData))

func save_game() -> void:
	var player : Player = get_tree().get_first_node_in_group("Player")
	
	saveData = {
		"Scene" : SceneManager.currentSceneUID,
		"X" : player.global_position.x,
		"Y" : player.global_position.y,
		"HP" : player.health,
		"Factory" : FactoryGlobal.activePipeLayout,
		"Blueprints" : FactoryGlobal.blueprintDictionary,
		"Elements" : FactoryGlobal.elementArray,
		"Discovered Areas" : discoveredAreas,
		"Persistent Data" : persistentData
	}
	
	var saveFile = FileAccess.open(get_file_name(), FileAccess.WRITE)
	saveFile.store_line(JSON.stringify(saveData, "", false, false))

func load_game() -> void:
	if not FileAccess.file_exists(get_file_name()):
		return
	
	var saveFile = FileAccess.open(get_file_name(), FileAccess.READ)
	saveData = JSON.parse_string(saveFile.get_as_text())
	var scenePath = saveData.get("Scene", "uid://dpxba218vm1lf")
	
	FactoryGlobal.activePipeLayout = saveData.get("Factory", {}).duplicate(true)
	FactoryGlobal.blueprintDictionary = saveData.get("Blueprints", {}).duplicate(true)
	FactoryGlobal.elementArray = saveData.get("Elements", ["Water", "Fire", "Air", "Earth"]).duplicate()
	discoveredAreas = saveData.get("Discovered Areas", [])
	persistentData = saveData.get("Persistent Data", {})
	
	SceneManager.transition_scene(scenePath, "", Vector2.ZERO, "Up")
	await SceneManager.newSceneReady
	
	var player : Player = null
	while not player:
		player = get_tree().get_first_node_in_group("Player")
		await get_tree().process_frame
	
	player.health = saveData.get("HP", 20)

func get_file_name() -> String:
	return "user://" + SLOTS[currentSlot] + ".sav"
