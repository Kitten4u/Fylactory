extends CanvasLayer

var activeBlueprint : Dictionary
var copyingBlueprint : bool = false
var centerBuilding : Vector2
var firstRun : bool = true

func _ready() -> void:
	centerBuilding = Vector2(snappedf(%Display.size.x / 2, 50), snappedf(%Display.size.y / 2, 50))
	
	if FactoryGlobal.blueprintChunk != {}:
		var prepareBlueprint = FactoryGlobal.blueprintChunk.duplicate(true)
		FactoryGlobal.blueprintChunk = {}
		copyingBlueprint = true
		
		for building in prepareBlueprint:
			var buildingScene = null
			while not buildingScene:
				buildingScene = prepareBlueprint[building]["Type"]
				await get_tree().process_frame
				
			var buildingInstance = load(buildingScene).instantiate()
			buildingInstance.position = Vector2(str_to_var(building)) + FactoryGlobal.HALF_CELL_SIZE + centerBuilding
			if prepareBlueprint[building]["Flip"] == true:
				buildingInstance.scale.x = -1
			buildingInstance.get_node("Sprite2D").rotate(deg_to_rad(prepareBlueprint[building]["Rotation"]))
			%Buildings.add_child(buildingInstance)
			%BuildButton.show()
			
	%BuildButton.hide()
	build_blueprint_buttons()
	firstRun = false

func build_blueprint_buttons() -> void:
	for button in %BlueprintSelect.get_children():
		button.queue_free()
	
	var counter = 0
	if FactoryGlobal.blueprintDictionary.size() > 0:
		for blueprint in FactoryGlobal.blueprintDictionary:
			var button = Button.new()
			button.text = blueprint
			button.pressed.connect(Callable(build_blueprint).bind(blueprint))
			button.position.y = counter * 50
			%BlueprintSelect.add_child(button)
			
			if copyingBlueprint == false:
				%BuildButton.show()
				if counter == 0 and firstRun == true:
					build_blueprint(blueprint)
					activeBlueprint = FactoryGlobal.blueprintDictionary[blueprint]
			
			counter += 1
	
	while counter < 10:
		var emptyButton = Button.new()
		emptyButton.text = "Empty"
		emptyButton.pressed.connect(Callable(self, "_on_clear_button_pressed"))
		emptyButton.position.y = counter * 50
		%BlueprintSelect.add_child(emptyButton)
		counter += 1

func build_blueprint(blueprintName : String) -> void:
	for building in %Buildings.get_children():
		building.queue_free()
	
	var blueprint = FactoryGlobal.blueprintDictionary[blueprintName]
	activeBlueprint = FactoryGlobal.blueprintDictionary[blueprintName]
	
	for building in blueprint:
		var buildingScene = null
		while not buildingScene:
			buildingScene = blueprint[building]["Type"]
			await get_tree().process_frame
			
		var buildingInstance = load(buildingScene).instantiate()
		buildingInstance.position = Vector2(str_to_var(building)) + FactoryGlobal.HALF_CELL_SIZE
		if blueprint[building]["Flip"] == true:
			buildingInstance.scale.x = -1
		buildingInstance.get_node("Sprite2D").rotate(deg_to_rad(blueprint[building]["Rotation"]))
		%Buildings.add_child(buildingInstance)
		%BuildButton.show()

func _on_clear_button_pressed() -> void:
	%BuildButton.hide()
	for building in %Buildings.get_children():
		building.queue_free()

func _on_save_button_pressed() -> void:
	FactoryGlobal.disableInput = true
	var blueprint : Array = %Buildings.get_children()
	
	if blueprint.size() > 0:
		%BlueprintName.text = ""
		%BlueprintName.grab_focus()
		%EnterBlueprintName.visible = true
	else:
		%BlueprintEmptyError.visible = true

func _on_build_button_pressed() -> void:
	%BottomButtons.queue_free()
	FactoryGlobal.selectedBlueprint = activeBlueprint
	_on_close_button_pressed()

func _on_close_button_pressed() -> void:
	%BottomButtons.queue_free()
	%Grid.process_mode = Node.PROCESS_MODE_INHERIT
	get_tree().paused = false
	queue_free()

func _on_blueprint_accept_button_pressed() -> void:
	%EnterBlueprintName.visible = false
	if FactoryGlobal.blueprintDictionary.has(%BlueprintName.text):
		%BlueprintNameError.visible = true
	else:
		create_blueprint()
		%BuildButton.show()
		await get_tree().process_frame
		FactoryGlobal.disableInput = false

func _on_blueprint_cancel_button_pressed() -> void:
	FactoryGlobal.disableInput = false
	%EnterBlueprintName.visible = false

func _on_blueprint_empty_button_pressed() -> void:
	FactoryGlobal.disableInput = false
	%BlueprintEmptyError.visible = false

func _on_blueprint_overwrite_pressed() -> void:
	FactoryGlobal.disableInput = false
	%BlueprintNameError.visible = false
	create_blueprint()

func _on_blueprint_no_overwrite_pressed() -> void:
	%BlueprintNameError.visible = false
	%EnterBlueprintName.visible = true

func create_blueprint() -> void:
	var blueprintPipes : Dictionary
	for building in %Buildings.get_children():
		var flip = false
		if building.scale.x == -1:
			flip = true
		blueprintPipes[var_to_str(building.position - FactoryGlobal.HALF_CELL_SIZE)] = {
			"Type" : building.TYPE,
			"Rotation" : rad_to_deg(building.get_node("Sprite2D").rotation),
			"Flip" : flip,
		}
	
	activeBlueprint = blueprintPipes
	
	FactoryGlobal.blueprintDictionary[%BlueprintName.text] = blueprintPipes.duplicate(true)
	build_blueprint_buttons()

func _on_bottom_buttons_mouse_entered() -> void:
	if %Grid:
		%Grid.process_mode = Node.PROCESS_MODE_DISABLED

func _on_bottom_buttons_mouse_exited() -> void:
	if %Grid:
		%Grid.process_mode = Node.PROCESS_MODE_INHERIT
