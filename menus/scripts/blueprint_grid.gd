extends Grid

func _ready() -> void:
	# calculate grid size
	GRID_SIZE = Vector2(500, 500)
	CELL_AMOUNT = Vector2(GRID_SIZE.x / FactoryGlobal.CELL_SIZE.x, GRID_SIZE.y / FactoryGlobal.CELL_SIZE.y)
	menuOffset = Vector2(300, 100)
	gridParent = get_parent().get_parent()
	
	# Create the building preview
	selectedBuilding = FactoryGlobal.selectedBuildingBetweenRooms
	selectedBuildingIndex = FactoryGlobal.selectedBuildingIndexBetweenRooms
	if selectedBuilding:
		buildingPreviewInstance = selectedBuilding.instantiate()
		add_child(buildingPreviewInstance)
		buildingPreviewInstance.modulate.a = 0.7

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_W:
			for building in %Buildings.get_children():
				building.position.y -= FactoryGlobal.CELL_SIZE.y
		elif event.keycode == KEY_A:
			for building in %Buildings.get_children():
				building.position.x -= FactoryGlobal.CELL_SIZE.x
		elif event.keycode == KEY_S:
			for building in %Buildings.get_children():
				building.position.y += FactoryGlobal.CELL_SIZE.y
		elif event.keycode == KEY_D:
			for building in %Buildings.get_children():
				building.position.x += FactoryGlobal.CELL_SIZE.x

func spawn_building(location : String) -> void:
	if selectedBuilding:
		%BuildButton.hide()
		var trueLocation = str_to_var(location)
		var currentBuildings = %Buildings.get_children()
		for building in currentBuildings:
			if building.position - FactoryGlobal.HALF_CELL_SIZE == trueLocation:
				if forceBuild == true:
					delete_building(location)
				else:
					return
		
		var building = selectedBuilding.instantiate()
		building.position = trueLocation + FactoryGlobal.HALF_CELL_SIZE
		if flip == true:
			building.scale.x = -1
		building.get_node("Sprite2D").rotate(deg_to_rad(buildingRotation))
		%Buildings.add_child(building)
		building.add_to_group("Buildings")
		
		# Need to make sure the end point of an underground pipe is placed immediately after the start point
		if selectedBuilding == FactoryGlobal.undergroundPipeStart or selectedBuilding == FactoryGlobal.undergroundPipeEnd:
			select_building(0)

func delete_building(location : String) -> void:
	for body in %Buildings.get_children():
		if body.position - FactoryGlobal.HALF_CELL_SIZE == str_to_var(location):
			body.queue_free()
			break
