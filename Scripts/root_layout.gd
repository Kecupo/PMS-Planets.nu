extends Node

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hovered: Control = get_viewport().gui_get_hovered_control()
		if hovered:
			print("GUI hovered:", hovered.name, " path:", hovered.get_path())
		else:
			print("GUI hovered: <none>")
