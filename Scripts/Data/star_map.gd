extends Node2D

@onready var game_state = get_node("/root/GameState")
@onready var overlay: Control = get_node("%OverlayRoot") as Control
const PLANET_RADIUS_DRAW: float = 9.0
@export var click_radius_pixels: float = 21.0
const HOVER_PANEL_WIDTH: float = 390.0
const HOVER_PANEL_MARGIN: float = 12.0
const Minefield_Data = preload("res://Scripts/Data/MinefieldData.gd")
const IonStorm_Data = preload("res://Scripts/Data/IonStormData.gd")
const IonStormCircle_Data = preload("res://Scripts/Data/IonStormCircleData.gd")
const ION_STORM_BASE_COLOR: Color = Color(0.78, 0.70, 0.18, 1.0)
const NEBULA_BASE_COLOR: Color = Color(0.86, 0.88, 0.90, 1.0)
const NEBULA_OUTLINE_COLOR: Color = Color(0.72, 0.76, 0.80, 0.42)
const STARCLUSTER_CORE_COLOR: Color = Color(0.92, 0.92, 0.95, 0.95)
const STARCLUSTER_INNER_GLOW_COLOR: Color = Color(0.80, 0.80, 0.84, 0.18)
const STARCLUSTER_RADIATION_COLOR: Color = Color(0.82, 0.84, 0.88, 0.08)
const STARCLUSTER_OUTLINE_COLOR: Color = Color(0.80, 0.82, 0.86, 0.55)
var hover_layer: CanvasLayer = null
var hover_panel: PanelContainer = null
var hover_label: Label = null

func _ready() -> void:
	set_process_input(true)
	_create_hover_overlay()
	GameState.turn_loaded.connect(_on_turn_loaded)
	GameState.orders_changed.connect(func() -> void:
		queue_redraw()
)
func _on_turn_loaded() -> void:
	var center := Vector2(
		(game_state.map_min_x + game_state.map_max_x) * 0.5,
		(game_state.map_min_y + game_state.map_max_y) * 0.5
	)
	$Camera2D.position = center   # lokal, weil Camera2D Kind der StarMap ist
	queue_redraw()

	
func _process(_delta: float) -> void:
	queue_redraw()
	_update_hover_info(get_viewport().get_mouse_position())

func _draw() -> void:
	if game_state.planets.is_empty() \
	and game_state.minefields.is_empty() \
	and game_state.ionstorms.is_empty() \
	and game_state.nebulas.is_empty():
		return
	_draw_starclusters()
	_draw_nebulas()
	_draw_ionstorms()
	_draw_minefields()
	for p in game_state.planets:
		var center: Vector2 = _map_to_world(p)
		var col: Color = _planet_color(p)
		
		var radius: float = _get_planet_draw_radius(p)

		if _is_debris_disk_anchor(p):
			_draw_debris_disk_outline(p)

		draw_circle(center, radius, col)
		col.a = 0.4
		draw_circle(center, radius - 3, col)
		
		if game_state.planet_has_starbase(int(p.planet_id)):
			if _is_debris_planetoid(p):
				_draw_debris_station_marker(center, col)
			elif _is_in_starcluster_radiation_zone(p):
				_draw_radiation_station_marker(center, col)
			else:
				_draw_starbase_marker(center, col)
	# 3) Highlight ganz oben
	var sel: PlanetData = game_state.get_selected_planet()
	if sel != null:
		_draw_selected_highlight(sel)
		
func _draw_starbase_marker(center: Vector2, color: Color) -> void:
	var r: float = PLANET_RADIUS_DRAW + 5.5

	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(0.0, -r),
		center + Vector2(r, 0.0),
		center + Vector2(0.0, r),
		center + Vector2(-r, 0.0),
		center + Vector2(0.0, -r)
	])

	draw_polyline(points, color, 2.0)
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

func _create_hover_overlay() -> void:
	hover_layer = CanvasLayer.new()
	hover_layer.name = "MapHoverInfoLayer"
	hover_layer.layer = 3
	add_child(hover_layer)

	hover_panel = PanelContainer.new()
	hover_panel.name = "MapHoverInfoPanel"
	hover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_panel.visible = false
	hover_panel.custom_minimum_size = Vector2(HOVER_PANEL_WIDTH, 0.0)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.045, 0.055, 0.86)
	style.border_color = Color(0.45, 0.56, 0.62, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin(SIDE_LEFT, 10.0)
	style.set_content_margin(SIDE_TOP, 8.0)
	style.set_content_margin(SIDE_RIGHT, 10.0)
	style.set_content_margin(SIDE_BOTTOM, 8.0)
	hover_panel.add_theme_stylebox_override("panel", style)
	hover_layer.add_child(hover_panel)

	hover_label = Label.new()
	hover_label.name = "MapHoverInfoLabel"
	hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_label.custom_minimum_size = Vector2(HOVER_PANEL_WIDTH - 20.0, 0.0)
	hover_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hover_label.add_theme_color_override("font_color", Color(0.90, 0.96, 0.98, 1.0))
	hover_panel.add_child(hover_label)
	_position_hover_panel()

func _position_hover_panel() -> void:
	if hover_panel == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	hover_panel.position = Vector2(
		maxf(HOVER_PANEL_MARGIN, viewport_size.x - HOVER_PANEL_WIDTH - HOVER_PANEL_MARGIN),
		HOVER_PANEL_MARGIN
	)

func _update_hover_info(screen_pos: Vector2) -> void:
	if hover_label == null or hover_panel == null:
		return

	_position_hover_panel()

	if game_state.planets.is_empty() \
	and game_state.minefields.is_empty() \
	and game_state.ionstorms.is_empty() \
	and game_state.nebulas.is_empty() \
	and game_state.starclusters.is_empty():
		hover_panel.visible = false
		return

	var world_pos: Vector2 = _screen_to_world(screen_pos)
	var map_pos: Vector2 = _world_to_map(world_pos)
	var lines: PackedStringArray = _build_hover_lines(world_pos, map_pos)

	hover_label.text = "\n".join(lines)
	hover_panel.visible = true

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var inv: Transform2D = $Camera2D.get_canvas_transform().affine_inverse()
	return inv * screen_pos

func _world_to_map(world_pos: Vector2) -> Vector2:
	return Vector2(
		world_pos.x,
		game_state.map_max_y + game_state.map_min_y - world_pos.y
	)

func _build_hover_lines(world_pos: Vector2, map_pos: Vector2) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Coords: %d / %d" % [int(round(map_pos.x)), int(round(map_pos.y))])

	_append_planet_hover(lines, world_pos)
	_append_ionstorm_hover(lines, world_pos)
	_append_nebula_hover(lines, world_pos)
	_append_minefield_hover(lines, world_pos)
	_append_starcluster_hover(lines, map_pos)

	return lines

func _append_planet_hover(lines: PackedStringArray, world_pos: Vector2) -> void:
	var radius_world: float = click_radius_pixels * $Camera2D.zoom.x
	var picked_id: int = _pick_planet(world_pos, radius_world)
	if picked_id == -1:
		return

	var p: PlanetData = _get_planet_by_id(picked_id)
	if p == null:
		return

	lines.append("Planet: %s (%s)" % [p.name, _planet_owner_label(p)])

func _append_ionstorm_hover(lines: PackedStringArray, world_pos: Vector2) -> void:
	var total_voltage: float = 0.0
	var count: int = 0

	for storm: IonStormData in game_state.ionstorms:
		if storm == null:
			continue

		if _point_in_ionstorm(storm, world_pos):
			total_voltage += storm.voltage
			count += 1

	if count <= 0:
		return

	lines.append("Ion Storms: strength %d" % int(round(total_voltage)))

func _append_nebula_hover(lines: PackedStringArray, world_pos: Vector2) -> void:
	var total_visibility: float = 0.0
	var count: int = 0

	for nebula: NebulaData in game_state.nebulas:
		if nebula == null:
			continue

		for circle: NebulaCircleData in nebula.circles:
			if circle == null or circle.radius <= 0.0:
				continue

			if _nebula_circle_to_world(circle).distance_to(world_pos) <= circle.radius:
				total_visibility += circle.intensity
				count += 1

	if count <= 0:
		return

	lines.append("Nebulae: visibility %d" % int(round(total_visibility)))

func _append_minefield_hover(lines: PackedStringArray, world_pos: Vector2) -> void:
	for mf: MinefieldData in game_state.minefields:
		if mf == null:
			continue

		if mf.ishidden or mf.radius <= 0.0:
			continue

		if _minefield_to_world(mf).distance_to(world_pos) > mf.radius:
			continue

		var kind: String = "Web Minefield" if mf.isweb else "Minefield"
		lines.append(
			"%s #%d: %.0f mines, R %.0f, %s" % [
				kind,
				mf.minefield_id,
				mf.units,
				mf.radius,
				_player_owner_label(mf.ownerid)
			]
		)

func _append_starcluster_hover(lines: PackedStringArray, map_pos: Vector2) -> void:
	for star: StarClusterData in game_state.starclusters:
		if star == null:
			continue

		var voltage: int = get_starcluster_radiation_at_point(star, map_pos.x, map_pos.y)
		if voltage <= 0:
			continue

		var label_name: String = star.name
		if label_name.is_empty():
			label_name = "#" + str(star.star_id)

		lines.append("Star Cluster %s: voltage %d" % [label_name, voltage])

func _point_in_ionstorm(storm: IonStormData, world_pos: Vector2) -> bool:
	for circle: IonStormCircleData in storm.circles:
		if circle == null or circle.radius <= 0.0:
			continue

		if _ionstorm_circle_to_world(circle).distance_to(world_pos) <= circle.radius:
			return true

	return false

func _get_planet_by_id(planet_id: int) -> PlanetData:
	for p: PlanetData in game_state.planets:
		if int(p.planet_id) == planet_id:
			return p
	return null

func _planet_owner_label(p: PlanetData) -> String:
	if p == null or int(p.ownerid) <= 0:
		return "unowned"
	return _player_owner_label(int(p.ownerid))

func _player_owner_label(player_id: int) -> String:
	if player_id <= 0:
		return "unowned"

	var race_id: int = game_state.get_race_id_of_player(player_id)
	if race_id <= 0:
		return "Player %d" % player_id

	return "%s / Player %d" % [
		game_state.config.get_owner_abbrev(race_id),
		player_id
	]

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

func _minefield_to_world(mf: MinefieldData) -> Vector2:
	return Vector2(
		mf.x,
		game_state.map_max_y + game_state.map_min_y - mf.y
	)
func _minefield_color(mf: MinefieldData) -> Color:
	var race_id: int = game_state.get_race_id_of_player(mf.ownerid)
	if race_id <= 0:
		return Color.WHITE
	return RandAI_Config.get_race_color(race_id)
	
func _draw_minefields() -> void:
	for mf: MinefieldData in game_state.minefields:
		if mf == null:
			continue

		if mf.ishidden:
			continue

		if mf.radius <= 0.0:
			continue

		var center: Vector2 = _minefield_to_world(mf)
		var color: Color = _minefield_color(mf)
		color.a = 0.24

		if mf.isweb:
			var fill_color: Color = color
			fill_color.a = 0.18
			draw_circle(center, mf.radius, fill_color)
			_draw_web_mine_hatching(center, mf.radius, color)

		draw_circle(center, mf.radius, color)
		
func _planet_color(p: PlanetData) -> Color:
	var race_id: int = GameState.get_owner_race_id_of_planet(p)
	var color: Color = Color.WHITE
	if race_id <= 0:
		color = Color.from_string(RandAI_Config.neutral_color, Color.WHITE)
	else:
		color = RandAI_Config.get_race_color(race_id)
	return color

func _ionstorm_circle_to_world(circle: IonStormCircleData) -> Vector2:
	return Vector2(
		circle.x,
		game_state.map_max_y + game_state.map_min_y - circle.y
	)
	
func _ionstorm_fill_alpha(voltage: float) -> float:
	return clampf(voltage / 260.0, 0.04, 0.22)

func _ionstorm_border_alpha(voltage: float) -> float:
	return clampf(voltage / 210.0, 0.14, 0.45)

func _ionstorm_fill_color(voltage: float) -> Color:
	var c: Color = ION_STORM_BASE_COLOR
	c.a = _ionstorm_fill_alpha(voltage)
	return c

func _ionstorm_border_color(voltage: float) -> Color:
	var c: Color = ION_STORM_BASE_COLOR
	c.a = _ionstorm_border_alpha(voltage)
	return c

func _draw_ionstorms() -> void:
	for storm: IonStormData in game_state.ionstorms:
		if storm == null:
			continue

		_draw_ionstorm(storm)

func _draw_ionstorm(storm: IonStormData) -> void:
	for i: int in range(storm.circles.size()):
		var circle: IonStormCircleData = storm.circles[i]
		if circle == null or circle.radius <= 0.0:
			continue

		var center: Vector2 = _ionstorm_circle_to_world(circle)

		var fill_color: Color = _ionstorm_fill_color(storm.voltage)
		if i > 0:
			fill_color.a *= 0.96

		draw_circle(center, circle.radius, fill_color)

	_draw_ionstorm_outer_outline(storm)
	_draw_ionstorm_heading(storm)

func _draw_ionstorm_outer_outline(storm: IonStormData) -> void:
	var border_color: Color = _ionstorm_border_color(storm.voltage)

	for i: int in range(storm.circles.size()):
		var circle: IonStormCircleData = storm.circles[i]
		if circle == null or circle.radius <= 0.0:
			continue

		if _is_ionstorm_circle_mostly_internal(storm, i):
			continue

		var center: Vector2 = _ionstorm_circle_to_world(circle)
		draw_arc(center, circle.radius, 0.0, TAU, 96, border_color, 2.0)

func _draw_ionstorm_heading(storm: IonStormData) -> void:
	if storm.circles.is_empty():
		return

	var root_circle: IonStormCircleData = storm.circles[0]
	var center: Vector2 = _ionstorm_circle_to_world(root_circle)

	var heading_rad: float = deg_to_rad(storm.heading - 90.0)
	var dir: Vector2 = Vector2(cos(heading_rad), sin(heading_rad)).normalized()

	var line_length: float = maxf(26.0, storm.warp * 8.0)
	var start: Vector2 = center
	var tip: Vector2 = start + dir * line_length

	var color: Color = _ionstorm_border_color(storm.voltage)
	color.a = minf(1.0, color.a + 0.20)

	var line_width: float = 3.0
	draw_line(start, tip, color, line_width)

	var head_length: float = 10.0
	var head_angle: float = deg_to_rad(28.0)

	var left_dir: Vector2 = dir.rotated(PI - head_angle)
	var right_dir: Vector2 = dir.rotated(PI + head_angle)

	var left_point: Vector2 = tip + left_dir * head_length
	var right_point: Vector2 = tip + right_dir * head_length

	draw_line(tip, left_point, color, line_width)
	draw_line(tip, right_point, color, line_width)

func _nebula_circle_to_world(circle: NebulaCircleData) -> Vector2:
	return Vector2(
		circle.x,
		game_state.map_max_y + game_state.map_min_y - circle.y
	)

func _nebula_fill_alpha(intensity: float) -> float:
	return clampf(intensity / 170.0, 0.05, 0.18)
	
func _nebula_outline_alpha() -> float:
	return 0.42
	
func _nebula_fill_color(intensity: float) -> Color:
	var c: Color = NEBULA_BASE_COLOR
	c.a = _nebula_fill_alpha(intensity)
	return c

func _nebula_outline_color() -> Color:
	var c: Color = NEBULA_BASE_COLOR
	c.a = _nebula_outline_alpha()
	return c

func _draw_nebulas() -> void:
	for nebula: NebulaData in game_state.nebulas:
		if nebula == null:
			continue

		_draw_nebula(nebula)
		
func _draw_nebula(nebula: NebulaData) -> void:
	for circle: NebulaCircleData in nebula.circles:
		if circle == null or circle.radius <= 0.0:
			continue

		var center: Vector2 = _nebula_circle_to_world(circle)
		draw_circle(center, circle.radius, _nebula_fill_color(circle.intensity))

	_draw_nebula_outer_outline(nebula)
func _draw_nebula_outer_outline(nebula: NebulaData) -> void:
	for i: int in range(nebula.circles.size()):
		var circle: NebulaCircleData = nebula.circles[i]
		if circle == null or circle.radius <= 0.0:
			continue

		if _is_nebula_circle_mostly_internal(nebula, i):
			continue

		var center: Vector2 = _nebula_circle_to_world(circle)
		draw_arc(center, circle.radius, 0.0, TAU, 96, NEBULA_OUTLINE_COLOR, 2.0)
		
func _is_ionstorm_circle_mostly_internal(storm: IonStormData, index: int) -> bool:
	var a: IonStormCircleData = storm.circles[index]
	var center_a: Vector2 = Vector2(a.x, a.y)

	for j: int in range(storm.circles.size()):
		if j == index:
			continue

		var b: IonStormCircleData = storm.circles[j]
		if b == null:
			continue

		var center_b: Vector2 = Vector2(b.x, b.y)
		var dist: float = center_a.distance_to(center_b)

		if dist + a.radius <= b.radius * 0.98:
			return true

	return false

func _is_nebula_circle_mostly_internal(nebula: NebulaData, index: int) -> bool:
	var a: NebulaCircleData = nebula.circles[index]
	var center_a: Vector2 = Vector2(a.x, a.y)

	for j: int in range(nebula.circles.size()):
		if j == index:
			continue

		var b: NebulaCircleData = nebula.circles[j]
		if b == null:
			continue

		var center_b: Vector2 = Vector2(b.x, b.y)
		var dist: float = center_a.distance_to(center_b)

		# Kreis A liegt weitgehend innerhalb von B
		if dist + a.radius <= b.radius * 0.98:
			return true

	return false

func _starcluster_to_world(star: StarClusterData) -> Vector2:
	return Vector2(
		star.x,
		game_state.map_max_y + game_state.map_min_y - star.y
	)

func _draw_starclusters() -> void:
	for star: StarClusterData in game_state.starclusters:
		if star == null:
			continue

		_draw_starcluster(star)

func _draw_starcluster(star: StarClusterData) -> void:
	var center: Vector2 = _starcluster_to_world(star)
	var core_radius: float = star.radius
	var outer_radius: float = _get_starcluster_outer_radius(star)

	if core_radius <= 0.0 or outer_radius <= core_radius:
		return

	# 1) äußerer Radiation-Glow
	_draw_starcluster_soft_ring(center, core_radius, outer_radius)

	# 2) Linie des inneren Kerns
	draw_arc(center, core_radius, 0.0, TAU, 128, STARCLUSTER_OUTLINE_COLOR, 2.0)

	# 3) äußere Linie der Radiation-Zone
	var outer_outline: Color = STARCLUSTER_OUTLINE_COLOR
	outer_outline.a = 0.35
	draw_arc(center, outer_radius, 0.0, TAU, 128, outer_outline, 2.0)

	# 4) weicher innerer Glow
	_draw_starcluster_core_glow(center, core_radius)

	# 5) heller Kern in der Mitte
	draw_circle(center, maxf(4.0, core_radius * 0.12), STARCLUSTER_CORE_COLOR)

func _draw_starcluster_soft_ring(center: Vector2, inner_radius: float, outer_radius: float) -> void:
	var steps: int = 18

	for i: int in range(steps, 0, -1):
		var t: float = float(i) / float(steps)
		var r: float = lerpf(inner_radius, outer_radius, t)

		var c: Color = STARCLUSTER_RADIATION_COLOR
		c.a *= pow(t, 2.2)

		draw_arc(center, r, 0.0, TAU, 128, c, 2.0)

func _draw_starcluster_core_glow(center: Vector2, core_radius: float) -> void:
	var steps: int = 10

	for i: int in range(steps, 0, -1):
		var t: float = float(i) / float(steps)
		var r: float = core_radius * t

		var c: Color = STARCLUSTER_INNER_GLOW_COLOR
		c.a *= pow(t, 2.0)

		draw_circle(center, r, c)

func _get_starcluster_outer_radius(star: StarClusterData) -> float:
	return sqrt(star.mass)
func _get_starcluster_radiation_at_distance(star: StarClusterData, dist: float) -> int:
	var radiation_radius: float = _get_starcluster_outer_radius(star)
	if radiation_radius <= 0.0:
		return 0

	if dist > radiation_radius:
		return 0

	return int(ceil((star.temp / 100.0) * (1.0 - (dist / radiation_radius))))
	
func get_starcluster_radiation_at_point(star: StarClusterData, x: float, y: float) -> int:
	var dist: float = Vector2(star.x, star.y).distance_to(Vector2(x, y))
	return _get_starcluster_radiation_at_distance(star, dist)

func _is_debris_planetoid(p: PlanetData) -> bool:
	return p.debrisdisk > 0.0
	
func _is_debris_disk_anchor(p: PlanetData) -> bool:
	if p.debrisdisk <= 0.0:
		return false

	return p.name.strip_edges().ends_with(" - 1")

func _get_planet_draw_radius(p: PlanetData) -> float:
	if _is_debris_planetoid(p):
		return PLANET_RADIUS_DRAW * 0.35
	return PLANET_RADIUS_DRAW

func _draw_debris_disk_outline(p: PlanetData) -> void:
	var center: Vector2 = _map_to_world(p)
	var radius: float = 40.0
	var fill_color: Color = Color(0.55, 0.52, 0.44, 0.03)
	var line_color: Color = Color(0.76, 0.73, 0.60, 0.42)

	draw_circle(center, radius, fill_color)
	draw_arc(center, radius, 0.0, TAU, 128, line_color, 2.0)

func _is_in_starcluster_radiation_zone(p: PlanetData) -> bool:
	var pos: Vector2 = Vector2(p.x, p.y)

	for star: StarClusterData in game_state.starclusters:
		if star == null:
			continue

		var center: Vector2 = Vector2(star.x, star.y)
		var dist: float = center.distance_to(pos)
		var radiation_radius: float = sqrt(star.mass)

		if dist <= radiation_radius and dist > star.radius:
			return true

	return false

func _draw_debris_station_marker(center: Vector2, color: Color) -> void:
	var r: float = PLANET_RADIUS_DRAW * 0.4
	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(0.0, -r),
		center + Vector2(r, r),
		center + Vector2(-r, r)
	])

	draw_polyline(PackedVector2Array([
		points[0], points[1], points[2], points[0]
	]), color, 2.0)

func _draw_radiation_station_marker(center: Vector2, color: Color) -> void:
	var r: float = PLANET_RADIUS_DRAW
	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(-r, -r),
		center + Vector2(r, -r),
		center + Vector2(r, r),
		center + Vector2(-r, r),
		center + Vector2(-r, -r)
	])

	draw_polyline(points, color, 2.0)

func _draw_web_mine_hatching(center: Vector2, radius: float, base_color: Color) -> void:
	var hatch_color: Color = base_color
	hatch_color.a = 0.24

	var spacing: float = 10.0
	var half_extent: float = radius + 8.0
	var x: float = -half_extent

	while x <= half_extent:
		var p1: Vector2 = center + Vector2(x, -half_extent)
		var p2: Vector2 = center + Vector2(x + half_extent * 2.0, half_extent)
		_draw_clipped_line_to_circle(center, radius, p1, p2, hatch_color, 1.5)
		x += spacing
	
func _draw_clipped_line_to_circle(
	center: Vector2,
	radius: float,
	from: Vector2,
	to: Vector2,
	color: Color,
	width: float
) -> void:
	var steps: int = 24
	var last_inside: bool = false
	var last_point: Vector2 = from

	for i: int in range(steps + 1):
		var t: float = float(i) / float(steps)
		var point: Vector2 = from.lerp(to, t)
		var inside: bool = center.distance_to(point) <= radius

		if i > 0 and inside and last_inside:
			draw_line(last_point, point, color, width)

		last_inside = inside
		last_point = point
