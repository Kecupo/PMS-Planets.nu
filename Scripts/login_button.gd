extends Button

func _ready() -> void:
	print("Probe ready on:", name, " rect:", get_global_rect())
	pressed.connect(_on_pressed)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		print("GUI INPUT on", name, " button:", event.button_index, " at:", event.position)

func _on_pressed() -> void:
	print("PRESSED on", name)
