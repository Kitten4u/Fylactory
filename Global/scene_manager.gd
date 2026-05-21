extends CanvasLayer

signal loadSceneStarted
signal newSceneReady(targetName : String, offset : Vector2)
signal loadSceneFinished

func _ready() -> void:
	await get_tree().process_frame
	loadSceneFinished.emit()

func transition_scene(newScene : String, targetArea : String, playerOffset : Vector2, _direction : String) -> void:
	loadSceneStarted.emit()
	await get_tree().process_frame
	
	get_tree().change_scene_to_file(newScene)
	
	await get_tree().scene_changed
	newSceneReady.emit(targetArea, playerOffset)
	loadSceneFinished.emit()
