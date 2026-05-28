extends CanvasLayer

signal loadSceneStarted
signal newSceneReady(targetName : String, offset : Vector2)
signal loadSceneFinished
signal sceneEntered(uid : String)

var currentSceneUID : String = "uid://dpxba218vm1lf"

func _ready() -> void:
	await get_tree().process_frame
	loadSceneFinished.emit()

func transition_scene(newScene : String, targetArea : String, playerOffset : Vector2, _direction : String) -> void:
	loadSceneStarted.emit()
	await get_tree().process_frame
	
	get_tree().change_scene_to_file(newScene)
	currentSceneUID = ResourceUID.path_to_uid(newScene)
	sceneEntered.emit(currentSceneUID)
	
	await get_tree().scene_changed
	newSceneReady.emit(targetArea, playerOffset)
	loadSceneFinished.emit()
