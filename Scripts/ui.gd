extends Node

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		print("GLOBAL INPUT:", event.button_index, " pos:", event.position, " handled:", event.is_handled())
