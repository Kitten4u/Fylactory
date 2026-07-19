extends Control


func _on_button_pressed() -> void:
	queue_free()

func _on_button_mouse_entered() -> void:
	get_parent().get_node("Grid").process_mode = Node.PROCESS_MODE_DISABLED

func _on_button_mouse_exited() -> void:
	get_parent().get_node("Grid").process_mode = Node.PROCESS_MODE_INHERIT
