extends Node

@onready var vp := get_viewport()

func _ready() -> void:
	print("VIEWPORT PROBE READY. vp:", vp)
	vp.gui_focus_changed.connect(_on_focus_changed)

func _on_focus_changed(control: Control) -> void:
	print("GUI focus changed:", control, " path:", control.get_path() if control else "<none>")

func _process(_delta: float) -> void:
	pass

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		print("NODE _input MouseButton:", event.button_index, " pressed:", event.pressed, " pos:", event.position)

func _notification(what: int) -> void:
	# This one is key: it fires even when the scene tree input callbacks don't.
	if what == NOTIFICATION_WM_MOUSE_ENTER:
		print("WM mouse enter")
	elif what == NOTIFICATION_WM_MOUSE_EXIT:
		print("WM mouse exit")
