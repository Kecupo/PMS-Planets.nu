extends Camera2D

@export var zoom_step: float = 1.15
@export var min_zoom: float = 0.2
@export var max_zoom: float = 5.0
@onready var game_state: GameState = get_node("/root/GameState")
var _dragging: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO
const PAN_SPEED: float = 2.0
func _input(event: InputEvent) -> void:
	# Mouse buttons
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton

		# Zoom
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_at_screen_point(mb.position, 1.0 / zoom_step)
				get_viewport().set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_at_screen_point(mb.position, zoom_step)
				get_viewport().set_input_as_handled()
			return

		# Drag mit rechter Maustaste
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = mb.pressed
			_last_mouse_pos = mb.position
			get_viewport().set_input_as_handled()
			return

	# Mausbewegung beim Drag
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion

		if _dragging:
			# Bewegung invertieren, damit die Karte "mitgezogen" wird
			position -= mm.relative * zoom.x * PAN_SPEED

			_last_mouse_pos = mm.position
			get_viewport().set_input_as_handled()
	
func _zoom_at_screen_point(_screen_pos: Vector2, factor: float) -> void:
	# World position under the mouse before zoom
	var world_before: Vector2 = get_global_mouse_position()

	# Apply new zoom (uniform)
	var new_zoom: float = clamp(zoom.x * factor, min_zoom, max_zoom)
	zoom = Vector2(new_zoom, new_zoom)

	# World position under the mouse after zoom
	var world_after: Vector2 = get_global_mouse_position()

	# Move camera so the point under the cursor stays under the cursor
	position += (world_before - world_after)



func _ready() -> void:
	set_process_input(true)
	center_on_galaxy()


func center_on_galaxy() -> void:
	position = Vector2(
		(game_state.map_min_x + game_state.map_max_x) * 0.5,
		(game_state.map_min_y + game_state.map_max_y) * 0.5
	)
