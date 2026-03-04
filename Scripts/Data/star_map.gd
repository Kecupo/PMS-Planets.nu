extends Node2D

@onready var game_state = get_node("/root/GameState")
@onready var overlay: Control = get_node("%OverlayRoot") as Control
const PLANET_RADIUS_DRAW: float = 10.0
@export var click_radius_pixels: float = 20.0

func _ready() -> void:
	set_process_input(true)
	GameState.turn_loaded.connect(_on_turn_loaded)
	
func _on_turn_loaded() -> void:
	var center := Vector2(
		(game_state.map_min_x + game_state.map_max_x) * 0.5,
		(game_state.map_min_y + game_state.map_max_y) * 0.5
	)
	$Camera2D.position = center   # lokal, weil Camera2D Kind der StarMap ist
	queue_redraw()

	
func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if game_state.planets.is_empty():
		return

	# 1) Planeten zeichnen
	for p in game_state.planets:
		var col: Color = _planet_color(p)
		draw_circle(_map_to_world(p), PLANET_RADIUS_DRAW, col)

	# 2) Highlight: selektierten Planeten oben drüber zeichnen
	var sel: PlanetData = game_state.get_selected_planet()
	if sel != null:
		_draw_selected_highlight(sel)

func _draw_selected_highlight(p: PlanetData) -> void:
	var pos: Vector2 = _map_to_world(p)

	# Ring (deutlich sichtbar)
	draw_arc(
		pos,
		PLANET_RADIUS_DRAW + 10.0,
		0.0,
		TAU,
		64,
		Color(1.0, 0.9, 0.2, 0.9),
		3.0
	)

	# Optional: zweiter, dünner Ring
	draw_arc(
		pos,
		PLANET_RADIUS_DRAW + 6.0,
		0.0,
		TAU,
		64,
		Color(1.0, 0.9, 0.2, 0.45),
		2.0
	)

func _unhandled_input(event: InputEvent) -> void:
	
	if event is not InputEventMouseButton:
		return

	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return

	# Screen -> World via camera transform (Godot 4)
	var inv: Transform2D = $Camera2D.get_canvas_transform().affine_inverse()
	var world_pos: Vector2 = inv * mb.position

	# Klickradius in Weltkoordinaten, damit er sich bei Zoom "gleich groß" anfühlt
	var radius_world: float = click_radius_pixels * $Camera2D.zoom.x

	var picked_id: int = _pick_planet(world_pos, radius_world)
	if picked_id != -1:
		game_state.select_planet(picked_id)
		# Wichtig: hier KEIN UI-Hover-Filter und keine weiteren Änderungen
		get_viewport().set_input_as_handled()

func _pick_planet(world_pos: Vector2, radius_world: float) -> int:
	var best_id: int = -1
	var best_dist2: float = INF
	var r2: float = radius_world * radius_world

	for p in game_state.planets:
		var wp: Vector2 = _map_to_world(p)
		var dx: float = wp.x - world_pos.x
		var dy: float = wp.y - world_pos.y
		var d2: float = dx * dx + dy * dy
		if d2 <= r2 and d2 < best_dist2:
			best_dist2 = d2
			best_id = p.planet_id

	return best_id

func _map_to_world(p: PlanetData) -> Vector2:
	# Y invertiert (Planets.nu: y fällt nach unten)
	return Vector2(
		p.x,
		game_state.map_max_y + game_state.map_min_y - p.y
	)

func _planet_color(p: PlanetData) -> Color:
	var owner_race: int = GameState.get_owner_race_id_of_planet(p)

	# neutral / unknown
	if owner_race < 0:
		return Color.WHITE

	# eigene Rasse
	if owner_race == GameState.my_race_id:
		return Color(0.2, 0.9, 0.2)  # grün

	# andere Rassen: vorerst feste Palette (später Config)
	return _race_palette(owner_race)

func _race_palette(race_id: int) -> Color:
	# Index 1..11/12 -> Palette; 0/negativ wird vorher abgefangen
	var palette: Array[Color] = [
		Color(0.8, 0.2, 0.2),  # 0 dummy
		Color(0.8, 0.2, 0.2),  # 1
		Color(0.9, 0.5, 0.1),  # 2
		Color(0.9, 0.9, 0.2),  # 3
		Color(0.2, 0.6, 0.9),  # 4
		Color(0.6, 0.2, 0.9),  # 5
		Color(0.2, 0.9, 0.8),  # 6
		Color(0.9, 0.2, 0.6),  # 7
		Color(0.6, 0.6, 0.6),  # 8
		Color(0.3, 0.3, 0.9),  # 9
		Color(0.9, 0.3, 0.3),  # 10
		Color(0.3, 0.9, 0.3),  # 11
	]
	if race_id >= 0 and race_id < palette.size():
		return palette[race_id]
	return Color.WHITE
