extends CanvasLayer

func _ready() -> void:
	build_blueprint_buttons()

func build_blueprint_buttons() -> void:
	for button in %BlueprintSelect.get_children():
		button.queue_free()
	
	var counter = 0
	if FactoryGlobal.blueprintDictionary.size() > 0:
		for blueprint in FactoryGlobal.blueprintDictionary:
			var button = Button.new()
			button.text = blueprint
			button.pressed.connect(Callable(buildBlueprint).bind(blueprint))
			button.position.y = counter * 50
			%BlueprintSelect.add_child(button)
			counter += 1
	
	while counter < 10:
		var emptyButton = Button.new()
		emptyButton.text = "Empty"
		emptyButton.pressed.connect(Callable(self, "_on_clear_button_pressed"))
		emptyButton.position.y = counter * 50
		%BlueprintSelect.add_child(emptyButton)
		counter += 1

func buildBlueprint(blueprintName : String) -> void:
	for building in %Buildings.get_children():
		building.queue_free()
	
	var blueprint = FactoryGlobal.blueprintDictionary[blueprintName]
	
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

func _on_clear_button_pressed() -> void:
	for building in %Buildings.get_children():
		building.queue_free()

func _on_save_button_pressed() -> void:
	var blueprint : Array = %Buildings.get_children()
	
	if blueprint.size() > 0:
		%BlueprintName.text = ""
		%BlueprintName.grab_focus()
		%EnterBlueprintName.visible = true
	else:
		%BlueprintEmptyError.visible = true

func _on_close_button_pressed() -> void:
	get_tree().paused = false
	queue_free()

func _on_blueprint_accept_button_pressed() -> void:
	%EnterBlueprintName.visible = false
	if FactoryGlobal.blueprintDictionary.has(%BlueprintName.text):
		%BlueprintNameError.visible = true
	else:
		create_blueprint()

func _on_blueprint_empty_button_pressed() -> void:
	%BlueprintEmptyError.visible = false

func _on_blueprint_overwrite_pressed() -> void:
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
	
	FactoryGlobal.blueprintDictionary[%BlueprintName.text] = blueprintPipes.duplicate(true)
	build_blueprint_buttons()
