extends Node2D

@onready var game_state = get_node("/root/GameState")
@onready var overlay: Control = get_node("%OverlayRoot") as Control
const PLANET_RADIUS_DRAW: float = 7.5
@export var click_radius_pixels: float = 21.0
const HOVER_PANEL_WIDTH: float = 270.0
const HOVER_PANEL_MARGIN: float = 12.0
const HOVER_INFO_SEPARATOR: String = "------------------------------"
const MERGED_SHAPE_SEGMENTS: int = 36
const FIELD_CELL_SIZE: float = 28.0
const DEBRIS_DISK_RADIUS: float = 40.0
const NEBULA_VISIBILITY_DENSITY_FACTOR: float = 5000.0
const NEBULA_MAX_VISIBILITY: int = 2000
const SHIP_RADIUS_DRAW: float = 5.5
const SHIP_GROUP_RADIUS_PIXELS: float = 46.0
const SHIP_SUMMARY_LABEL_ZOOM: float = 0.35
const SHIP_COMPACT_LABEL_ZOOM: float = 0.80
const SHIP_FULL_DETAIL_ZOOM: float = 1.80
const SHIP_LABEL_FONT_SIZE: int = 15
const SHIP_MAX_LABELS_PER_GROUP: int = 4
const SHIP_LABEL_PADDING_PIXELS: float = 5.0
const SHIP_MODE_DOT: int = 0
const SHIP_MODE_SUMMARY: int = 1
const SHIP_MODE_COMPACT: int = 2
const SHIP_MODE_FULL: int = 3
const Minefield_Data = preload("res://Scripts/Data/MinefieldData.gd")
const Starship_Data = preload("res://Scripts/Data/StarshipData.gd")
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
var _last_hover_mouse_pos: Vector2 = Vector2(INF, INF)
var _last_hover_camera_pos: Vector2 = Vector2(INF, INF)
var _last_hover_camera_zoom: Vector2 = Vector2(INF, INF)
var _ship_label_screen_rects: Array[Rect2] = []

func _ready() -> void:
	set_process_input(true)
	_create_hover_overlay()
	GameState.turn_loaded.connect(_on_turn_loaded)
	GameState.selection_changed.connect(_on_selection_changed)
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

func _on_selection_changed(kind: String, _selected_id: int) -> void:
	if kind == "planet" or kind == "ship" or kind == "starbase" or kind == "none":
		_center_camera_on_selection(kind)
		queue_redraw()

func _center_camera_on_selection(kind: String) -> void:
	match kind:
		"planet":
			var p: PlanetData = game_state.get_selected_planet()
			if p != null:
				$Camera2D.position = _map_to_world(p)
		"ship":
			var ship: StarshipData = game_state.get_selected_ship()
			if ship != null:
				$Camera2D.position = _ship_to_world(ship)
		"starbase":
			var sb_planet: PlanetData = _get_planet_by_id(game_state.selected_starbase_planet_id)
			if sb_planet != null:
				$Camera2D.position = _map_to_world(sb_planet)

	
func _process(_delta: float) -> void:
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var camera: Camera2D = $Camera2D

	var zoom_changed: bool = camera.zoom != _last_hover_camera_zoom
	if mouse_pos == _last_hover_mouse_pos \
	and camera.position == _last_hover_camera_pos \
	and not zoom_changed:
		return

	_last_hover_mouse_pos = mouse_pos
	_last_hover_camera_pos = camera.position
	_last_hover_camera_zoom = camera.zoom
	if zoom_changed:
		queue_redraw()
	_update_hover_info(mouse_pos)

func _draw() -> void:
	if game_state.planets.is_empty() \
	and game_state.starships.is_empty() \
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
	elif game_state.selected_starbase_planet_id >= 0:
		var sb_planet: PlanetData = _get_planet_by_id(game_state.selected_starbase_planet_id)
		if sb_planet != null:
			_draw_selected_highlight(sb_planet)

	_draw_starships()
	_draw_selected_ship_highlight()
		
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
	var base_radius: float = _get_planet_draw_radius(p)
	var outer_padding: float = 10.0
	var inner_padding: float = 6.0
	if _is_debris_planetoid(p):
		outer_padding = 5.0
		inner_padding = 2.5

	# Ring (deutlich sichtbar)
	draw_arc(
		pos,
		base_radius + outer_padding,
		0.0,
		TAU,
		64,
		Color(1.0, 0.9, 0.2, 0.9),
		3.0
	)

	draw_arc(
		pos,
		base_radius + inner_padding,
		0.0,
		TAU,
		64,
		Color(1.0, 0.9, 0.2, 0.45),
		2.0
	)

func _draw_selected_ship_highlight() -> void:
	var ship: StarshipData = game_state.get_selected_ship()
	if ship == null:
		return

	var pos: Vector2 = _ship_to_world(ship)
	var outer_radius: float = _screen_px_to_world(13.0)
	var inner_radius: float = _screen_px_to_world(9.0)
	var outer_width: float = _screen_px_to_world(2.4)
	var inner_width: float = _screen_px_to_world(1.4)

	draw_arc(pos, outer_radius, 0.0, TAU, 48, Color(1.0, 0.9, 0.2, 0.95), outer_width)
	draw_arc(pos, inner_radius, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.55), inner_width)

	# Optional: zweiter, dünner Ring
func _unhandled_input(event: InputEvent) -> void:
	
	if event is not InputEventMouseButton:
		return

	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return

	if _is_screen_pos_over_blocking_ui(mb.position):
		return

	# Screen -> World via camera transform (Godot 4)
	var world_pos: Vector2 = _screen_to_world(mb.position)

	# Klickradius in Weltkoordinaten, damit er sich bei Zoom "gleich groß" anfühlt
	var radius_world: float = click_radius_pixels * $Camera2D.zoom.x

	var selection_mode: String = game_state.get_selection_mode()
	match selection_mode:
		"ship":
			var picked_ship_id: int = _pick_ship_cycle(world_pos, _screen_px_to_world(maxf(22.0, SHIP_RADIUS_DRAW * 3.0)))
			if picked_ship_id != -1:
				game_state.select_ship(picked_ship_id)
				get_viewport().set_input_as_handled()
		"starbase":
			var picked_starbase_planet_id: int = _pick_starbase(world_pos, radius_world)
			if picked_starbase_planet_id != -1:
				game_state.select_starbase(picked_starbase_planet_id)
				get_viewport().set_input_as_handled()
		_:
			var picked_id: int = _pick_planet(world_pos, radius_world)
			if picked_id != -1:
				game_state.select_planet(picked_id)
				get_viewport().set_input_as_handled()
		# Wichtig: hier KEIN UI-Hover-Filter und keine weiteren Änderungen

func _is_screen_pos_over_blocking_ui(screen_pos: Vector2) -> bool:
	var planet_panel: Control = _get_planet_info_panel()
	if planet_panel != null and planet_panel.visible and planet_panel.get_global_rect().has_point(screen_pos):
		return true

	var hovered: Control = get_viewport().gui_get_hovered_control()
	if hovered == null:
		return false

	if hover_panel != null and (hovered == hover_panel or hover_panel.is_ancestor_of(hovered)):
		return false

	var node: Node = hovered
	while node != null:
		if node.is_in_group("map_blocking_ui"):
			return true
		node = node.get_parent()

	return planet_panel != null and (hovered == planet_panel or planet_panel.is_ancestor_of(hovered))

func _get_planet_info_panel() -> Control:
	if overlay == null:
		return null
	return overlay.get_node_or_null("PlanetInfoPanel") as Control

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
	hover_label.custom_minimum_size = Vector2(HOVER_PANEL_WIDTH - 20.0, 0.0)
	hover_label.size = Vector2(HOVER_PANEL_WIDTH - 20.0, 0.0)
	hover_panel.custom_minimum_size = Vector2(HOVER_PANEL_WIDTH, 0.0)
	hover_panel.size = Vector2(HOVER_PANEL_WIDTH, 0.0)
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
	_append_debris_disk_hover(lines, world_pos)
	_append_starship_hover(lines, world_pos)
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

	_append_hover_separator(lines)
	lines.append("Planet: %s (%s)" % [p.name, _planet_owner_label(p)])

func _append_debris_disk_hover(lines: PackedStringArray, world_pos: Vector2) -> void:
	for p: PlanetData in game_state.planets:
		if p == null:
			continue

		if not _is_debris_disk_anchor(p):
			continue

		if _map_to_world(p).distance_to(world_pos) > DEBRIS_DISK_RADIUS:
			continue

		_append_hover_separator(lines)
		lines.append("Asteroid Field: %s (R %.0f)" % [_debris_disk_label(p), DEBRIS_DISK_RADIUS])

func _append_starship_hover(lines: PackedStringArray, world_pos: Vector2) -> void:
	var radius_world: float = SHIP_GROUP_RADIUS_PIXELS / maxf($Camera2D.zoom.x, 0.001)
	var hits: Array[StarshipData] = []

	for ship: StarshipData in game_state.starships:
		if ship == null or ship.ishidden:
			continue

		if _ship_to_world(ship).distance_to(world_pos) <= radius_world:
			hits.append(ship)

	if hits.is_empty():
		return

	if hits.size() > 3 and _ship_display_mode() != SHIP_MODE_FULL:
		_append_hover_separator(lines)
		lines.append("Ships: %d" % hits.size())
		return

	for ship: StarshipData in hits:
		_append_hover_separator(lines)
		lines.append("Ship #%d P%d: %s" % [ship.ship_id, ship.ownerid, ship.display_hull_name()])

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

	_append_hover_separator(lines)
	lines.append("Ion Storms: strength %d" % int(round(total_voltage)))

func _append_nebula_hover(lines: PackedStringArray, world_pos: Vector2) -> void:
	var circle_specs: Array = []

	for nebula: NebulaData in game_state.nebulas:
		if nebula == null:
			continue

		for circle: NebulaCircleData in nebula.circles:
			if circle == null or circle.radius <= 0.0:
				continue
			circle_specs.append([_nebula_circle_to_world(circle), circle.radius, circle.intensity])

	var density: float = _nebula_density_at(world_pos, circle_specs)
	if density <= 0.0:
		return

	var visibility: int = _nebula_visibility_from_density(density)
	_append_hover_separator(lines)
	lines.append("Nebulae: visibility %d ly" % visibility)

func _append_minefield_hover(lines: PackedStringArray, world_pos: Vector2) -> void:
	for mf: MinefieldData in game_state.minefields:
		if mf == null:
			continue

		if mf.ishidden or mf.radius <= 0.0:
			continue

		if _minefield_to_world(mf).distance_to(world_pos) > mf.radius:
			continue

		var kind: String = "Web Minefield" if mf.isweb else "Minefield"
		_append_hover_separator(lines)
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

		_append_hover_separator(lines)
		lines.append("Star Cluster %s: voltage %d" % [label_name, voltage])

func _append_hover_separator(lines: PackedStringArray) -> void:
	if lines.size() <= 0:
		return
	if lines[lines.size() - 1] == HOVER_INFO_SEPARATOR:
		return
	lines.append(HOVER_INFO_SEPARATOR)

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

func _pick_ship(world_pos: Vector2, radius_world: float) -> int:
	var best_id: int = -1
	var best_dist2: float = INF
	var r2: float = radius_world * radius_world

	for ship: StarshipData in game_state.starships:
		if ship == null or ship.ishidden:
			continue
		var d2: float = _ship_to_world(ship).distance_squared_to(world_pos)
		if d2 <= r2 and d2 < best_dist2:
			best_dist2 = d2
			best_id = int(ship.ship_id)

	return best_id

func _pick_ship_cycle(world_pos: Vector2, radius_world: float) -> int:
	var hits: Array[StarshipData] = []
	var r2: float = radius_world * radius_world

	for ship: StarshipData in game_state.starships:
		if ship == null or ship.ishidden:
			continue
		if _ship_to_world(ship).distance_squared_to(world_pos) <= r2:
			hits.append(ship)

	if hits.is_empty():
		return -1

	hits.sort_custom(func(a: StarshipData, b: StarshipData) -> bool:
		if a.x == b.x:
			if a.y == b.y:
				return int(a.ship_id) < int(b.ship_id)
			return a.y < b.y
		return a.x < b.x
	)

	var current_id: int = game_state.selected_ship_id
	for i: int in range(hits.size()):
		if int(hits[i].ship_id) == current_id:
			return int(hits[(i + 1) % hits.size()].ship_id)

	return int(hits[0].ship_id)

func _pick_starbase(world_pos: Vector2, radius_world: float) -> int:
	var best_id: int = -1
	var best_dist2: float = INF
	var r2: float = radius_world * radius_world

	for p: PlanetData in game_state.planets:
		if p == null or not game_state.planet_has_starbase(int(p.planet_id)):
			continue
		var d2: float = _map_to_world(p).distance_squared_to(world_pos)
		if d2 <= r2 and d2 < best_dist2:
			best_dist2 = d2
			best_id = int(p.planet_id)

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

func _ship_to_world(ship: StarshipData) -> Vector2:
	return Vector2(
		ship.x,
		game_state.map_max_y + game_state.map_min_y - ship.y
	)

func _ship_target_to_world(ship: StarshipData) -> Vector2:
	return Vector2(
		ship.targetx,
		game_state.map_max_y + game_state.map_min_y - ship.targety
	)

func _minefield_color(mf: MinefieldData) -> Color:
	var race_id: int = game_state.get_race_id_of_player(mf.ownerid)
	return RandAI_Config.get_player_color(mf.ownerid, race_id)
	
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

func _draw_starships() -> void:
	if game_state.starships.is_empty():
		return

	var mode: int = _ship_display_mode()
	var groups: Array = _build_ship_groups(mode)
	_ship_label_screen_rects.clear()

	for group_v: Variant in groups:
		var group: Array = group_v as Array
		if group.is_empty():
			continue

		_draw_ship_group(group, mode)

func _ship_display_mode() -> int:
	var z: float = $Camera2D.zoom.x
	if z >= SHIP_FULL_DETAIL_ZOOM:
		return SHIP_MODE_FULL
	if z >= SHIP_COMPACT_LABEL_ZOOM:
		return SHIP_MODE_COMPACT
	if z >= SHIP_SUMMARY_LABEL_ZOOM:
		return SHIP_MODE_SUMMARY
	return SHIP_MODE_DOT

func _build_ship_groups(mode: int) -> Array:
	var ships: Array = []
	for ship: StarshipData in game_state.starships:
		if ship == null or ship.ishidden:
			continue
		ships.append(ship)

	var groups: Array = []
	var used: Array[bool] = []
	used.resize(ships.size())
	for i: int in range(used.size()):
		used[i] = false

	var grouping_pixels: float = 80.0 if mode >= SHIP_MODE_COMPACT else SHIP_GROUP_RADIUS_PIXELS
	var radius_world: float = grouping_pixels / maxf($Camera2D.zoom.x, 0.001)
	var radius2: float = radius_world * radius_world

	for i: int in range(ships.size()):
		if used[i]:
			continue

		var ship: StarshipData = ships[i]
		var group: Array = [ship]
		used[i] = true
		var center: Vector2 = _ship_to_world(ship)

		for j: int in range(i + 1, ships.size()):
			if used[j]:
				continue

			var other: StarshipData = ships[j]
			if center.distance_squared_to(_ship_to_world(other)) <= radius2:
				group.append(other)
				used[j] = true

		groups.append(group)

	return groups

func _draw_ship_group(group: Array, mode: int) -> void:
	var center: Vector2 = _ship_group_center(group)
	for ship_v: Variant in group:
		var ship: StarshipData = ship_v as StarshipData
		_draw_single_ship(ship, mode >= SHIP_MODE_COMPACT)

	if mode == SHIP_MODE_SUMMARY:
		_draw_ship_summary_label(group, center)
		return

	if mode < SHIP_MODE_COMPACT:
		return

	_draw_ship_group_label(group, center)

func _draw_single_ship(ship: StarshipData, draw_vector: bool) -> void:
	var center: Vector2 = _ship_to_world(ship)
	var color: Color = _ship_color(ship)
	var fill: Color = color
	fill.a = 0.82
	var outline: Color = Color.WHITE
	outline.a = 0.78
	var r: float = _screen_px_to_world(SHIP_RADIUS_DRAW)
	var width: float = _screen_px_to_world(1.4)

	draw_circle(center, r, fill)
	draw_arc(center, r, 0.0, TAU, 28, outline, width)
	if draw_vector:
		_draw_ship_vector(ship, center, color)

func _draw_ship_vector(ship: StarshipData, center: Vector2, color: Color) -> void:
	var dir: Vector2 = Vector2.ZERO
	var max_distance: float = ship.warp * ship.warp
	if max_distance <= 0.0:
		return

	if ship.has_target():
		var target: Vector2 = _ship_target_to_world(ship)
		var to_target: Vector2 = target - center
		var target_distance: float = to_target.length()
		if target_distance <= 0.0:
			return
		dir = to_target / target_distance
		max_distance = min(max_distance, target_distance)
	elif ship.heading >= 0.0:
		var heading_rad: float = deg_to_rad(ship.heading - 90.0)
		dir = Vector2(cos(heading_rad), sin(heading_rad)).normalized()

	if dir == Vector2.ZERO:
		return

	var line_color: Color = color
	line_color.a = 0.90
	var tip: Vector2 = center + dir * max_distance
	var width: float = _screen_px_to_world(1.6)
	draw_line(center, tip, line_color, width)

	var head_length: float = _screen_px_to_world(5.0)
	var head_angle: float = deg_to_rad(28.0)
	draw_line(tip, tip + dir.rotated(PI - head_angle) * head_length, line_color, width)
	draw_line(tip, tip + dir.rotated(PI + head_angle) * head_length, line_color, width)

func _draw_ship_group_label(group: Array, center: Vector2) -> void:
	var summary: Array = _ship_group_summary(group)
	var line_step: float = _screen_px_to_world(17.0)
	var line_count: int = min(summary.size(), SHIP_MAX_LABELS_PER_GROUP)
	var lines: Array[Dictionary] = []

	for i: int in range(line_count):
		var item: Dictionary = summary[i] as Dictionary
		lines.append({
			"text": "%d [%d] %s" % [int(item.get("count", 0)), int(item.get("ownerid", 0)), String(item.get("label", ""))],
			"color": item.get("color", Color.WHITE)
		})

	if summary.size() > SHIP_MAX_LABELS_PER_GROUP:
		lines.append({
			"text": "+%d types / %d ships" % [summary.size() - SHIP_MAX_LABELS_PER_GROUP, _count_summary_ships(summary, SHIP_MAX_LABELS_PER_GROUP)],
			"color": Color(0.88, 0.93, 0.96, 0.88)
		})

	var label_pos: Vector2 = _reserve_ship_label_position(center, lines)
	for i: int in range(lines.size()):
		var line: Dictionary = lines[i]
		_draw_map_text(
			label_pos + Vector2(0.0, line_step * float(i)),
			String(line.get("text", "")),
			line.get("color", Color.WHITE)
		)

func _draw_ship_summary_label(group: Array, center: Vector2) -> void:
	var text: String = "1 ship" if group.size() == 1 else "%d ships" % group.size()
	var ship: StarshipData = group[0] as StarshipData
	var lines: Array[Dictionary] = [{"text": text, "color": _ship_color(ship)}]
	_draw_map_text(_reserve_ship_label_position(center, lines), text, _ship_color(ship))

func _draw_map_text(pos: Vector2, text: String, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var scale: float = _screen_px_to_world(1.0)
	draw_set_transform(pos, 0.0, Vector2(scale, scale))
	draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, SHIP_LABEL_FONT_SIZE, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _screen_px_to_world(px: float) -> float:
	return px / maxf($Camera2D.zoom.x, 0.001)

func _world_to_screen(world_pos: Vector2) -> Vector2:
	return $Camera2D.get_canvas_transform() * world_pos

func _reserve_ship_label_position(center: Vector2, lines: Array[Dictionary]) -> Vector2:
	var center_screen: Vector2 = _world_to_screen(center)
	var label_size: Vector2 = _estimate_ship_label_size(lines)
	var offsets: Array[Vector2] = [
		Vector2(18.0, -12.0),
		Vector2(18.0, 14.0),
		Vector2(-label_size.x - 18.0, -12.0),
		Vector2(-label_size.x - 18.0, 14.0),
		Vector2(18.0, -label_size.y - 18.0),
		Vector2(-label_size.x - 18.0, -label_size.y - 18.0),
		Vector2(18.0, 38.0),
		Vector2(-label_size.x - 18.0, 38.0)
	]

	for offset: Vector2 in offsets:
		var candidate: Rect2 = Rect2(center_screen + offset, label_size)
		if not _ship_label_rect_overlaps(candidate):
			_ship_label_screen_rects.append(candidate.grow(SHIP_LABEL_PADDING_PIXELS))
			return _screen_to_world(candidate.position)

	var fallback: Rect2 = Rect2(center_screen + Vector2(18.0, 62.0 + float(_ship_label_screen_rects.size()) * 10.0), label_size)
	_ship_label_screen_rects.append(fallback.grow(SHIP_LABEL_PADDING_PIXELS))
	return _screen_to_world(fallback.position)

func _estimate_ship_label_size(lines: Array[Dictionary]) -> Vector2:
	var max_chars: int = 1
	for line: Dictionary in lines:
		max_chars = max(max_chars, String(line.get("text", "")).length())

	var width: float = float(max_chars) * float(SHIP_LABEL_FONT_SIZE) * 0.62
	var height: float = maxf(1.0, float(lines.size())) * 17.0
	return Vector2(width, height)

func _ship_label_rect_overlaps(rect: Rect2) -> bool:
	var padded: Rect2 = rect.grow(SHIP_LABEL_PADDING_PIXELS)
	for existing: Rect2 in _ship_label_screen_rects:
		if padded.intersects(existing):
			return true
	return false

func _ship_group_center(group: Array) -> Vector2:
	var sum: Vector2 = Vector2.ZERO
	var count: int = 0

	for ship_v: Variant in group:
		var ship: StarshipData = ship_v as StarshipData
		sum += _ship_to_world(ship)
		count += 1

	if count <= 0:
		return Vector2.ZERO

	return sum / float(count)

func _ship_group_summary(group: Array) -> Array:
	var by_key: Dictionary = {}
	var result: Array = []

	for ship_v: Variant in group:
		var ship: StarshipData = ship_v as StarshipData
		var label: String = _ship_hull_short_name(ship)
		var key: String = "%d|%s" % [ship.ownerid, label]
		if not by_key.has(key):
			var item: Dictionary = {
				"ownerid": ship.ownerid,
				"label": label,
				"count": 0,
				"color": _ship_color(ship)
			}
			by_key[key] = item
			result.append(item)

		var summary: Dictionary = by_key[key] as Dictionary
		summary["count"] = int(summary.get("count", 0)) + 1

	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca: int = int(a.get("count", 0))
		var cb: int = int(b.get("count", 0))
		if ca == cb:
			return String(a.get("label", "")) < String(b.get("label", ""))
		return ca > cb
	)

	return result

func _count_summary_ships(summary: Array, start_index: int) -> int:
	var count: int = 0
	for i: int in range(start_index, summary.size()):
		var item: Dictionary = summary[i] as Dictionary
		count += int(item.get("count", 0))
	return count

func _ship_hull_short_name(ship: StarshipData) -> String:
	var raw_name: String = ship.display_hull_name().strip_edges()
	if raw_name.is_empty():
		return "Ship"

	var upper_name: String = raw_name.to_upper()
	if raw_name == upper_name and raw_name.length() <= 12:
		return raw_name

	var words: PackedStringArray = raw_name.split(" ", false)
	var ignored: Dictionary = {
		"CLASS": true,
		"THE": true,
		"OF": true,
		"AND": true
	}
	var initials: String = ""

	for word: String in words:
		var clean: String = word.strip_edges()
		if clean.is_empty():
			continue
		if ignored.has(clean.to_upper()):
			continue
		initials += clean.substr(0, 1).to_upper()

	if initials.length() >= 2 and initials.length() <= 6:
		return initials

	if raw_name.length() <= 14:
		return raw_name

	return raw_name.substr(0, 14)

func _ship_color(ship: StarshipData) -> Color:
	var race_id: int = game_state.get_race_id_of_player(ship.ownerid)
	if ship.ownerid <= 0:
		return Color(0.86, 0.90, 0.94, 1.0)
	return RandAI_Config.get_player_color(ship.ownerid, race_id)
		
func _planet_color(p: PlanetData) -> Color:
	var race_id: int = GameState.get_owner_race_id_of_planet(p)
	var color: Color = Color.WHITE
	if int(p.ownerid) <= 0:
		color = Color.from_string(RandAI_Config.neutral_color, Color.WHITE)
	else:
		color = RandAI_Config.get_player_color(int(p.ownerid), race_id)
	return color

func _ionstorm_circle_to_world(circle: IonStormCircleData) -> Vector2:
	return Vector2(
		circle.x,
		game_state.map_max_y + game_state.map_min_y - circle.y
	)
	
func _ionstorm_fill_alpha(voltage: float) -> float:
	return clampf(voltage / 210.0, 0.06, 0.30)

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
	var circle_specs: Array = []

	for circle: IonStormCircleData in storm.circles:
		if circle == null or circle.radius <= 0.0:
			continue

		var voltage: float = circle.voltage
		if voltage <= 0.0:
			voltage = storm.voltage

		circle_specs.append([_ionstorm_circle_to_world(circle), circle.radius, voltage])

	if not circle_specs.is_empty():
		_draw_merged_circle_shape(
			circle_specs,
			ION_STORM_BASE_COLOR,
			_ionstorm_border_color(storm.voltage),
			2.0,
			"ionstorm"
		)

	_draw_ionstorm_heading(storm)

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
	return clampf(intensity / 135.0, 0.07, 0.26)
	
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
	var circle_specs: Array = []
	var intensity: float = 0.0

	for circle: NebulaCircleData in nebula.circles:
		if circle == null or circle.radius <= 0.0:
			continue

		circle_specs.append([_nebula_circle_to_world(circle), circle.radius, circle.intensity])
		intensity = maxf(intensity, circle.intensity)

	if not circle_specs.is_empty():
		_draw_nebula_shape(circle_specs)

func _draw_nebula_shape(circle_specs: Array) -> void:
	var bounds: Rect2 = _circle_specs_bounds(circle_specs)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return

	_draw_nebula_field_fill(circle_specs, bounds)
	_draw_circle_union_outline(circle_specs, _nebula_outline_color(), 2.0)

func _draw_nebula_field_fill(circle_specs: Array, bounds: Rect2) -> void:
	var cell_size: float = maxf(16.0, maxf(bounds.size.x, bounds.size.y) / 80.0)
	var x_steps: int = int(ceil(bounds.size.x / cell_size))
	var y_steps: int = int(ceil(bounds.size.y / cell_size))

	for xi: int in range(x_steps):
		for yi: int in range(y_steps):
			var p00: Vector2 = bounds.position + Vector2(float(xi) * cell_size, float(yi) * cell_size)
			var p10: Vector2 = bounds.position + Vector2(float(xi + 1) * cell_size, float(yi) * cell_size)
			var p01: Vector2 = bounds.position + Vector2(float(xi) * cell_size, float(yi + 1) * cell_size)
			var p11: Vector2 = bounds.position + Vector2(float(xi + 1) * cell_size, float(yi + 1) * cell_size)
			_draw_nebula_field_triangle(p00, p10, p11, circle_specs)
			_draw_nebula_field_triangle(p00, p11, p01, circle_specs)

func _draw_nebula_field_triangle(a: Vector2, b: Vector2, c: Vector2, circle_specs: Array) -> void:
	var ca: Color = _nebula_color_at(a, circle_specs)
	var cb: Color = _nebula_color_at(b, circle_specs)
	var cc: Color = _nebula_color_at(c, circle_specs)
	if ca.a <= 0.0 and cb.a <= 0.0 and cc.a <= 0.0:
		return
	draw_primitive(PackedVector2Array([a, b, c]), PackedColorArray([ca, cb, cc]), PackedVector2Array())

func _nebula_color_at(pos: Vector2, circle_specs: Array) -> Color:
	var c: Color = NEBULA_BASE_COLOR
	if not _point_in_circle_union(pos, circle_specs):
		c.a = 0.0
		return c

	var density: float = _nebula_density_at(pos, circle_specs)
	if density <= 0.0:
		c.a = 0.0
		return c
	c.a = _nebula_fill_alpha(density)
	return c

func _nebula_density_at(pos: Vector2, circle_specs: Array) -> float:
	var density: float = 0.0
	for spec: Variant in circle_specs:
		if not (spec is Array):
			continue
		var arr: Array = spec as Array
		if arr.size() < 3:
			continue
		var center: Vector2 = arr[0] as Vector2
		var radius: float = float(arr[1])
		var intensity: float = float(arr[2])
		if radius <= 0.0 or intensity <= 0.0:
			continue
		var dist_ratio: float = center.distance_to(pos) / radius
		var falloff: float = _smooth_falloff(dist_ratio)
		if falloff > 0.0:
			density += intensity * falloff
	return density

func _nebula_visibility_from_density(density: float) -> int:
	if density <= 0.0:
		return 0
	return mini(NEBULA_MAX_VISIBILITY, int(round(NEBULA_VISIBILITY_DENSITY_FACTOR / density)))

func _point_in_circle_union(pos: Vector2, circle_specs: Array) -> bool:
	for spec: Variant in circle_specs:
		if not (spec is Array):
			continue
		var arr: Array = spec as Array
		if arr.size() < 2:
			continue
		var center: Vector2 = arr[0] as Vector2
		var radius: float = float(arr[1])
		if radius > 0.0 and center.distance_to(pos) <= radius:
			return true
	return false

func _draw_circle_union_outline(circle_specs: Array, color: Color, width: float) -> void:
	var segments: int = max(72, MERGED_SHAPE_SEGMENTS * 2)
	for i: int in range(circle_specs.size()):
		var arr: Array = circle_specs[i] as Array
		if arr.size() < 2:
			continue
		var center: Vector2 = arr[0] as Vector2
		var radius: float = float(arr[1])
		if radius <= 0.0:
			continue

		var run: PackedVector2Array = PackedVector2Array()
		for step: int in range(segments + 1):
			var angle: float = TAU * float(step) / float(segments)
			var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
			if _is_exposed_circle_boundary_point(point, circle_specs, i):
				run.append(point)
			else:
				if run.size() >= 2:
					draw_polyline(run, color, width)
				run = PackedVector2Array()
		if run.size() >= 2:
			draw_polyline(run, color, width)

func _is_exposed_circle_boundary_point(point: Vector2, circle_specs: Array, own_index: int) -> bool:
	for i: int in range(circle_specs.size()):
		if i == own_index:
			continue
		var arr: Array = circle_specs[i] as Array
		if arr.size() < 2:
			continue
		var center: Vector2 = arr[0] as Vector2
		var radius: float = float(arr[1])
		if radius <= 0.0:
			continue
		if center.distance_to(point) < radius - 0.5:
			return false
	return true

func _circle_specs_bounds(circle_specs: Array) -> Rect2:
	var has_value: bool = false
	var min_x: float = 0.0
	var max_x: float = 0.0
	var min_y: float = 0.0
	var max_y: float = 0.0

	for spec: Variant in circle_specs:
		if not (spec is Array):
			continue
		var arr: Array = spec as Array
		if arr.size() < 2:
			continue
		var center: Vector2 = arr[0] as Vector2
		var radius: float = float(arr[1])
		if radius <= 0.0:
			continue
		if not has_value:
			min_x = center.x - radius
			max_x = center.x + radius
			min_y = center.y - radius
			max_y = center.y + radius
			has_value = true
		else:
			min_x = minf(min_x, center.x - radius)
			max_x = maxf(max_x, center.x + radius)
			min_y = minf(min_y, center.y - radius)
			max_y = maxf(max_y, center.y + radius)

	if not has_value:
		return Rect2()
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func _draw_merged_circle_shape(
	circle_specs: Array,
	fill_color: Color,
	outline_color: Color,
	outline_width: float,
	field_kind: String
) -> void:
	var hull: PackedVector2Array = _build_circle_hull(circle_specs)
	if hull.size() < 3:
		return

	_draw_circle_field_fill(circle_specs, hull, fill_color, field_kind)

	var outline: PackedVector2Array = PackedVector2Array(hull)
	outline.append(hull[0])
	draw_polyline(outline, outline_color, outline_width)

func _draw_circle_field_fill(
	circle_specs: Array,
	hull: PackedVector2Array,
	base_color: Color,
	field_kind: String
) -> void:
	var bounds: Rect2 = _polygon_bounds(hull)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return

	var cell_size: float = _field_cell_size(bounds)
	var x_steps: int = int(ceil(bounds.size.x / cell_size))
	var y_steps: int = int(ceil(bounds.size.y / cell_size))

	for xi: int in range(x_steps):
		for yi: int in range(y_steps):
			var p00: Vector2 = bounds.position + Vector2(float(xi) * cell_size, float(yi) * cell_size)
			var p10: Vector2 = bounds.position + Vector2(float(xi + 1) * cell_size, float(yi) * cell_size)
			var p01: Vector2 = bounds.position + Vector2(float(xi) * cell_size, float(yi + 1) * cell_size)
			var p11: Vector2 = bounds.position + Vector2(float(xi + 1) * cell_size, float(yi + 1) * cell_size)
			var center: Vector2 = (p00 + p11) * 0.5
			if not _point_in_polygon(center, hull):
				continue

			_draw_field_triangle(p00, p10, p11, circle_specs, hull, base_color, field_kind)
			_draw_field_triangle(p00, p11, p01, circle_specs, hull, base_color, field_kind)

func _draw_field_triangle(
	a: Vector2,
	b: Vector2,
	c: Vector2,
	circle_specs: Array,
	hull: PackedVector2Array,
	base_color: Color,
	field_kind: String
) -> void:
	var points: PackedVector2Array = PackedVector2Array([a, b, c])
	var colors: PackedColorArray = PackedColorArray([
		_field_color_at(a, circle_specs, hull, base_color, field_kind),
		_field_color_at(b, circle_specs, hull, base_color, field_kind),
		_field_color_at(c, circle_specs, hull, base_color, field_kind)
	])
	draw_primitive(points, colors, PackedVector2Array())

func _field_color_at(
	pos: Vector2,
	circle_specs: Array,
	hull: PackedVector2Array,
	base_color: Color,
	field_kind: String
) -> Color:
	var c: Color = base_color
	if not _point_in_polygon(pos, hull):
		c.a = 0.0
		return c

	var alpha: float = 0.0
	for spec: Variant in circle_specs:
		if not (spec is Array):
			continue

		var arr: Array = spec as Array
		if arr.size() < 3:
			continue

		var center: Vector2 = arr[0] as Vector2
		var radius: float = float(arr[1])
		var strength: float = float(arr[2])
		if radius <= 0.0 or strength <= 0.0:
			continue

		var dist_ratio: float = center.distance_to(pos) / radius
		var falloff: float = _smooth_falloff(dist_ratio)
		if falloff <= 0.0:
			continue

		var local_alpha: float = _field_alpha_for_strength(strength, field_kind) * falloff
		alpha = maxf(alpha, local_alpha)

	c.a = alpha
	return c

func _field_alpha_for_strength(strength: float, field_kind: String) -> float:
	if field_kind == "ionstorm":
		return _ionstorm_fill_alpha(strength)
	return _nebula_fill_alpha(strength)

func _smooth_falloff(dist_ratio: float) -> float:
	var t: float = clampf(dist_ratio / 1.35, 0.0, 1.0)
	var s: float = t * t * (3.0 - 2.0 * t)
	return 1.0 - s

func _polygon_bounds(poly: PackedVector2Array) -> Rect2:
	if poly.is_empty():
		return Rect2()

	var min_x: float = poly[0].x
	var max_x: float = poly[0].x
	var min_y: float = poly[0].y
	var max_y: float = poly[0].y

	for p: Vector2 in poly:
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)

	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func _field_cell_size(bounds: Rect2) -> float:
	var longest: float = maxf(bounds.size.x, bounds.size.y)
	if longest <= 0.0:
		return FIELD_CELL_SIZE
	return maxf(FIELD_CELL_SIZE, longest / 48.0)

func _point_in_polygon(point: Vector2, poly: PackedVector2Array) -> bool:
	var inside: bool = false
	var j: int = poly.size() - 1

	for i: int in range(poly.size()):
		var pi: Vector2 = poly[i]
		var pj: Vector2 = poly[j]
		var crosses: bool = ((pi.y > point.y) != (pj.y > point.y))
		if crosses:
			var x_at_y: float = (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x
			if point.x < x_at_y:
				inside = not inside
		j = i

	return inside

func _build_circle_hull(circle_specs: Array) -> PackedVector2Array:
	var points: Array[Vector2] = []

	for spec: Variant in circle_specs:
		if not (spec is Array):
			continue

		var arr: Array = spec as Array
		if arr.size() < 2:
			continue

		var center: Vector2 = arr[0] as Vector2
		var radius: float = float(arr[1])
		if radius <= 0.0:
			continue

		for i: int in range(MERGED_SHAPE_SEGMENTS):
			var angle: float = TAU * float(i) / float(MERGED_SHAPE_SEGMENTS)
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)

	return _convex_hull(points)

func _convex_hull(points: Array[Vector2]) -> PackedVector2Array:
	if points.size() < 3:
		return PackedVector2Array(points)

	var sorted: Array[Vector2] = points.duplicate()
	sorted.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		if is_equal_approx(a.x, b.x):
			return a.y < b.y
		return a.x < b.x
	)

	var lower: Array[Vector2] = []
	for p: Vector2 in sorted:
		while lower.size() >= 2 and _hull_cross(lower[lower.size() - 2], lower[lower.size() - 1], p) <= 0.0:
			lower.pop_back()
		lower.append(p)

	var upper: Array[Vector2] = []
	for i: int in range(sorted.size() - 1, -1, -1):
		var p: Vector2 = sorted[i]
		while upper.size() >= 2 and _hull_cross(upper[upper.size() - 2], upper[upper.size() - 1], p) <= 0.0:
			upper.pop_back()
		upper.append(p)

	lower.pop_back()
	upper.pop_back()

	var hull: Array[Vector2] = lower
	hull.append_array(upper)
	return PackedVector2Array(hull)

func _hull_cross(a: Vector2, b: Vector2, c: Vector2) -> float:
	return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)

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

	if dist <= star.radius:
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
	var radius: float = DEBRIS_DISK_RADIUS
	var fill_color: Color = Color(0.55, 0.52, 0.44, 0.03)
	var line_color: Color = Color(0.76, 0.73, 0.60, 0.42)

	draw_circle(center, radius, fill_color)
	draw_arc(center, radius, 0.0, TAU, 128, line_color, 2.0)

func _debris_disk_label(p: PlanetData) -> String:
	var label: String = p.name.strip_edges()
	if label.ends_with(" - 1"):
		return label.substr(0, label.length() - 4)
	return label

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
