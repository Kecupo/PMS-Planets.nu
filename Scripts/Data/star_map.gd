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
const DETAIL_GRID_ZOOM: float = 20.0
const ACADEMY_DETAIL_GRID_ZOOM: float = 10.0
const WARP_WELL_ZOOM: float = 10.0
const WARP_WELL_RADIUS: int = 3
const PLANET_MIN_DETAIL_RADIUS: float = 0.5
const PLANETOID_MIN_DETAIL_RADIUS: float = 0.22
const MINE_SWEEP_ANIM_START_HOLD_SECONDS: float = 0.6
const MINE_SWEEP_ANIM_SHRINK_SECONDS: float = 5.2
const MINE_SWEEP_ANIM_END_HOLD_SECONDS: float = 0.8
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
var hover_label: RichTextLabel = null
var _last_hover_mouse_pos: Vector2 = Vector2(INF, INF)
var _last_hover_camera_pos: Vector2 = Vector2(INF, INF)
var _last_hover_camera_zoom: Vector2 = Vector2(INF, INF)
var _ship_label_screen_rects: Array[Rect2] = []
var _mine_sweep_preview_by_id: Dictionary = {}

func _ready() -> void:
	set_process_input(true)
	_create_hover_overlay()
	GameState.turn_loaded.connect(_on_turn_loaded)
	GameState.selection_changed.connect(_on_selection_changed)
	if not RandAI_Config.config_changed.is_connected(_on_config_changed):
		RandAI_Config.config_changed.connect(_on_config_changed)
	GameState.orders_changed.connect(func() -> void:
		_rebuild_mine_sweep_preview()
		queue_redraw()
)

func _on_config_changed() -> void:
	queue_redraw()

func _on_turn_loaded() -> void:
	var center := Vector2(
		(game_state.map_min_x + game_state.map_max_x) * 0.5,
		(game_state.map_min_y + game_state.map_max_y) * 0.5
	)
	$Camera2D.position = center   # lokal, weil Camera2D Kind der StarMap ist
	_rebuild_mine_sweep_preview()
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
	var blink_active: bool = _has_blinking_minefields()
	var sweep_preview_active: bool = _has_animated_minefield_preview()
	if blink_active or sweep_preview_active:
		queue_redraw()

	var zoom_changed: bool = camera.zoom != _last_hover_camera_zoom
	if mouse_pos == _last_hover_mouse_pos \
	and camera.position == _last_hover_camera_pos \
	and not zoom_changed \
	and not blink_active \
	and not sweep_preview_active:
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
	_draw_detail_grid()
	_draw_starclusters()
	_draw_nebulas()
	_draw_ionstorms()
	_draw_minefields()
	_draw_warp_wells()
	for p in game_state.planets:
		var center: Vector2 = _map_to_world(p)
		var col: Color = _planet_color(p)
		
		var radius: float = _get_planet_draw_radius(p)

		if _is_debris_disk_anchor(p):
			_draw_debris_disk_outline(p)

		draw_circle(center, radius, col)
		col.a = 0.4
		var inner_radius: float = maxf(radius * 0.55, radius - _screen_px_to_world(3.0))
		draw_circle(center, inner_radius, col)
		
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

func _draw_detail_grid() -> void:
	var zoom: float = maxf($Camera2D.zoom.x, 0.001)
	var threshold: float = ACADEMY_DETAIL_GRID_ZOOM if _dict_bool(_settings_from_rst(), ["isacademy"], false) else DETAIL_GRID_ZOOM
	if zoom < threshold:
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	var top_left: Vector2 = _screen_to_world(Vector2.ZERO)
	var bottom_right: Vector2 = _screen_to_world(viewport_size)
	var min_x: float = minf(top_left.x, bottom_right.x) - 1.0
	var max_x: float = maxf(top_left.x, bottom_right.x) + 1.0
	var min_y: float = minf(top_left.y, bottom_right.y) - 1.0
	var max_y: float = maxf(top_left.y, bottom_right.y) + 1.0
	var width: float = _screen_px_to_world(1.0)
	var grid_color: Color = Color(0.24, 0.26, 0.28, 0.42)
	var dot_color: Color = Color(0.35, 0.38, 0.40, 0.36)
	var dot_radius: float = _screen_px_to_world(1.2)

	var first_x: int = int(floor(min_x - 0.5))
	var last_x: int = int(ceil(max_x + 0.5))
	for x: int in range(first_x, last_x + 1):
		var boundary_x: float = float(x) + 0.5
		draw_line(Vector2(boundary_x, min_y), Vector2(boundary_x, max_y), grid_color, width)

	var first_y: int = int(floor(min_y - 0.5))
	var last_y: int = int(ceil(max_y + 0.5))
	for y: int in range(first_y, last_y + 1):
		var boundary_y: float = float(y) + 0.5
		draw_line(Vector2(min_x, boundary_y), Vector2(max_x, boundary_y), grid_color, width)

	for x: int in range(int(floor(min_x)), int(ceil(max_x)) + 1):
		for y: int in range(int(floor(min_y)), int(ceil(max_y)) + 1):
			draw_circle(Vector2(float(x), float(y)), dot_radius, dot_color)

func _draw_warp_wells() -> void:
	if $Camera2D.zoom.x < WARP_WELL_ZOOM:
		return
	var settings: Dictionary = _settings_from_rst()
	if _dict_bool(settings, ["isacademy"], false) or _dict_bool(settings, ["nowarpwells"], false):
		return

	var fill_color: Color = Color(0.0, 0.0, 0.0, 0.58)
	var line_color: Color = Color(0.58, 0.60, 0.62, 0.60)
	var width: float = _screen_px_to_world(1.0)
	for p in game_state.planets:
		if _is_debris_disk_anchor(p) or _is_debris_planetoid(p):
			continue
		var px: int = int(round(p.x))
		var py: int = int(round(p.y))
		for x: int in range(px - WARP_WELL_RADIUS, px + WARP_WELL_RADIUS + 1):
			for y: int in range(py - WARP_WELL_RADIUS, py + WARP_WELL_RADIUS + 1):
				if Vector2(float(x), float(y)).distance_to(Vector2(float(px), float(py))) > float(WARP_WELL_RADIUS):
					continue
				var center: Vector2 = Vector2(float(x), game_state.map_max_y + game_state.map_min_y - float(y))
				var rect: Rect2 = Rect2(center - Vector2(0.5, 0.5), Vector2.ONE)
				draw_rect(rect, fill_color, true)
				draw_rect(rect, line_color, false, width)

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
	if RandAI_Config.show_ship_scan_range:
		var scan_range: float = _ship_scan_range()
		if scan_range > 0.0:
			var scan_color: Color = _ship_color(ship)
			scan_color.a = 0.38
			draw_arc(pos, scan_range, 0.0, TAU, 192, scan_color, _screen_px_to_world(1.0))

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
			var selected_ship: StarshipData = game_state.get_selected_ship()
			if selected_ship != null and game_state.is_my_ship(selected_ship):
				var map_pos: Vector2 = _world_to_map(world_pos)
				if game_state.set_ship_waypoint(int(selected_ship.ship_id), map_pos.x, map_pos.y):
					queue_redraw()
				get_viewport().set_input_as_handled()
			else:
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

	hover_label = RichTextLabel.new()
	hover_label.name = "MapHoverInfoLabel"
	hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_label.custom_minimum_size = Vector2(HOVER_PANEL_WIDTH - 20.0, 0.0)
	hover_label.bbcode_enabled = true
	hover_label.fit_content = true
	hover_label.scroll_active = false
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

	for storm: IonStormData in game_state.ionstorms:
		if storm == null:
			continue

		var circle_specs: Array = _ionstorm_circle_specs(storm)
		if not _point_in_circle_union(world_pos, circle_specs):
			continue
		total_voltage += _ionstorm_voltage_at(storm, world_pos, circle_specs)

	if total_voltage <= 0.0:
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
		if not mf.isweb:
			if mf.suspected_passage_from_report:
				lines.append(_red_hover_line("Safe-passage FC: %s (Ship #%d)" % [mf.suspected_passage_fc, mf.suspected_passage_ship_id]))
				lines.append(_red_hover_line("FC planet: %s" % _minefield_fc_planet_label(mf)))
			elif int(mf.ownerid) == int(game_state.my_player_id):
				var fc: String = mf.resolved_friendlycode if not mf.resolved_friendlycode.is_empty() else mf.friendlycode
				lines.append("FC: %s (%s)" % [fc, _minefield_fc_planet_label(mf)])

func _minefield_fc_planet_label(mf: MinefieldData) -> String:
	if mf == null:
		return "unknown"
	if mf.fc_planet_id > 0:
		var pname: String = mf.fc_planet_name
		if pname.is_empty():
			pname = "Planet"
		return "%s #%d" % [pname, mf.fc_planet_id]
	return "unknown"

func _red_hover_line(text: String) -> String:
	return "[color=#ff5a5a]" + _bbcode_escape(text) + "[/color]"

func _bbcode_escape(text: String) -> String:
	return text.replace("[", "\\[").replace("]", "\\]")

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
	return _point_in_circle_union(world_pos, _ionstorm_circle_specs(storm))

func _ionstorm_circle_specs(storm: IonStormData) -> Array:
	var circle_specs: Array = []
	for circle: IonStormCircleData in storm.circles:
		if circle == null or circle.radius <= 0.0:
			continue
		var voltage: float = circle.voltage
		if voltage <= 0.0:
			voltage = storm.voltage
		circle_specs.append([_ionstorm_circle_to_world(circle), circle.radius, voltage])
	return circle_specs

func _ionstorm_voltage_at(storm: IonStormData, world_pos: Vector2, circle_specs: Array = []) -> float:
	if circle_specs.is_empty():
		circle_specs = _ionstorm_circle_specs(storm)
	var voltage: float = 0.0
	for spec: Variant in circle_specs:
		if not (spec is Array):
			continue
		var arr: Array = spec as Array
		if arr.size() < 3:
			continue
		var center: Vector2 = arr[0] as Vector2
		var radius: float = float(arr[1])
		var circle_voltage: float = float(arr[2])
		if radius <= 0.0:
			continue
		var dist: float = center.distance_to(world_pos)
		if dist <= radius:
			voltage += ceil(circle_voltage * (1.0 - (dist / radius)))

	return voltage

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
	return _minefield_color_for_owner(mf.ownerid)

func _minefield_color_for_owner(owner_id: int) -> Color:
	var race_id: int = game_state.get_race_id_of_player(owner_id)
	return RandAI_Config.get_player_color(owner_id, race_id)

func _has_blinking_minefields() -> bool:
	for mf: MinefieldData in game_state.minefields:
		if mf != null and mf.suspected_passage_from_report:
			return true
	return false

func _has_animated_minefield_preview() -> bool:
	for preview_v: Variant in _mine_sweep_preview_by_id.values():
		if not (preview_v is Dictionary):
			continue
		var preview: Dictionary = preview_v as Dictionary
		if bool(preview.get("laid", false)) or bool(preview.get("swept", false)):
			return true
	return false
	
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
		if _mine_sweep_preview_by_id.has(int(mf.minefield_id)):
			_draw_mine_sweep_preview(mf, center, color)
		if mf.suspected_passage_from_report:
			_draw_suspected_minefield_marker(center, mf.radius)
	_draw_new_minefield_previews()

func _draw_mine_sweep_preview(mf: MinefieldData, center: Vector2, base_color: Color) -> void:
	var preview_v: Variant = _mine_sweep_preview_by_id.get(int(mf.minefield_id))
	_draw_minefield_preview_entry(preview_v, center, base_color)

func _draw_new_minefield_previews() -> void:
	for preview_v: Variant in _mine_sweep_preview_by_id.values():
		if not (preview_v is Dictionary):
			continue
		var preview: Dictionary = preview_v as Dictionary
		if not bool(preview.get("new_field", false)):
			continue
		var center: Vector2 = Vector2(float(preview.get("x", 0.0)), game_state.map_max_y + game_state.map_min_y - float(preview.get("y", 0.0)))
		var owner_id: int = int(preview.get("ownerid", -1))
		var color: Color = _minefield_color_for_owner(owner_id)
		color.a = 0.24
		_draw_minefield_preview_entry(preview, center, color)

func _draw_minefield_preview_entry(preview_v: Variant, center: Vector2, base_color: Color) -> void:
	if not (preview_v is Dictionary):
		return
	var preview: Dictionary = preview_v as Dictionary
	var start_radius: float = float(preview.get("start_radius", 0.0))
	var end_radius: float = float(preview.get("end_radius", start_radius))
	var start_units: float = float(preview.get("start_units", 0.0))
	var end_units: float = float(preview.get("end_units", start_units))
	var is_swept: bool = bool(preview.get("swept", false))
	var is_laid: bool = bool(preview.get("laid", false))
	var is_decayed: bool = bool(preview.get("decayed", false))
	var has_animated_action: bool = is_swept or is_laid
	if not has_animated_action:
		if is_decayed:
			_draw_minefield_decay_preview_entry(preview, center, base_color)
		return

	if start_radius <= 0.0 and end_radius <= 0.0:
		if is_decayed:
			_draw_minefield_decay_preview_entry(preview, center, base_color)
		return
	if is_equal_approx(start_radius, end_radius):
		if is_equal_approx(start_units, end_units):
			if is_decayed:
				_draw_minefield_decay_preview_entry(preview, center, base_color)
			return
		if is_swept and end_units < start_units:
			end_radius = maxf(0.0, start_radius - _screen_px_to_world(8.0))

	var cycle: float = MINE_SWEEP_ANIM_START_HOLD_SECONDS + MINE_SWEEP_ANIM_SHRINK_SECONDS + MINE_SWEEP_ANIM_END_HOLD_SECONDS
	var t: float = fmod(float(Time.get_ticks_msec()) / 1000.0, cycle)
	var change_t: float = clampf((t - MINE_SWEEP_ANIM_START_HOLD_SECONDS) / MINE_SWEEP_ANIM_SHRINK_SECONDS, 0.0, 1.0)
	var eased: float = change_t * change_t * (3.0 - 2.0 * change_t)
	var current_radius: float = lerpf(start_radius, end_radius, eased)

	var zoom: float = maxf($Camera2D.zoom.x, 0.001)
	var outer: Color = base_color
	outer.a = 0.82
	var inner_fill: Color = base_color
	inner_fill.a = 0.38
	var inner_line: Color = base_color
	inner_line.a = 0.95
	var cleared: Color = Color(0.0, 0.0, 0.0, 0.34)
	var is_growth: bool = end_radius > start_radius

	var outer_radius: float = maxf(start_radius, end_radius)
	if not is_growth and start_radius > 0.0:
		draw_circle(center, outer_radius, cleared)
	draw_arc(center, outer_radius, 0.0, TAU, 128, outer, 2.2 / zoom, true)
	if current_radius > 0.1:
		draw_circle(center, current_radius, inner_fill)
		draw_arc(center, current_radius, 0.0, TAU, 128, inner_line, 1.8 / zoom, true)
	if is_decayed:
		_draw_minefield_decay_preview_entry(preview, center, base_color)

func _draw_minefield_decay_preview_entry(preview: Dictionary, center: Vector2, base_color: Color) -> void:
	var start_radius: float = float(preview.get("decay_start_radius", preview.get("end_radius", 0.0)))
	var end_radius: float = float(preview.get("decay_end_radius", start_radius))
	if start_radius <= 0.0:
		return
	if is_equal_approx(start_radius, end_radius):
		var start_units: float = float(preview.get("decay_start_units", 0.0))
		var end_units: float = float(preview.get("decay_end_units", start_units))
		if is_equal_approx(start_units, end_units):
			return
		end_radius = maxf(0.0, start_radius - _screen_px_to_world(4.0))

	var zoom: float = maxf($Camera2D.zoom.x, 0.001)
	var faded_fill: Color = base_color
	faded_fill.a = 0.11
	var remaining_fill: Color = base_color
	remaining_fill.a = 0.27
	var old_outline: Color = base_color
	old_outline.a = 0.50
	var new_outline: Color = base_color
	new_outline.a = 0.95
	var cleared: Color = Color(0.0, 0.0, 0.0, 0.18)

	draw_circle(center, start_radius, cleared)
	draw_circle(center, start_radius, faded_fill)
	if end_radius > 0.1:
		draw_circle(center, end_radius, remaining_fill)
	draw_arc(center, start_radius, 0.0, TAU, 128, old_outline, 1.1 / zoom, true)
	if end_radius > 0.1:
		draw_arc(center, end_radius, 0.0, TAU, 128, new_outline, 1.7 / zoom, true)

func _draw_suspected_minefield_marker(center: Vector2, radius: float) -> void:
	var phase: float = float(Time.get_ticks_msec()) / 900.0
	var pulse: float = 0.35 + 0.35 * (sin(phase) + 1.0) * 0.5
	var fill: Color = Color(1.0, 0.08, 0.08, 0.05 + pulse * 0.10)
	var outline: Color = Color(1.0, 0.12, 0.08, 0.40 + pulse * 0.45)
	draw_circle(center, radius, fill)
	draw_arc(center, radius, 0.0, TAU, 96, outline, 2.5 / maxf($Camera2D.zoom.x, 0.001), true)

func _rebuild_mine_sweep_preview() -> void:
	_mine_sweep_preview_by_id.clear()
	if game_state.minefields.is_empty():
		return

	var working_fields: Array[Dictionary] = []
	for mf: MinefieldData in game_state.minefields:
		if mf == null or mf.ishidden or mf.units <= 0.0 or mf.radius <= 0.0:
			continue
		working_fields.append({
			"id": int(mf.minefield_id),
			"ownerid": int(mf.ownerid),
			"x": mf.x,
			"y": mf.y,
			"units": mf.units,
			"radius": mf.radius,
			"start_units": mf.units,
			"start_radius": mf.radius,
			"isweb": mf.isweb,
			"new_field": false,
			"laid": false,
			"swept": false,
			"decayed": false,
			"sweepers": PackedInt32Array()
		})

	var lay_ships: Array[StarshipData] = []
	var sweepers: Array[StarshipData] = []
	for ship: StarshipData in game_state.starships:
		if _ship_can_preview_lay_mines(ship):
			lay_ships.append(ship)
		if _ship_can_preview_mine_sweep(ship) or _ship_can_preview_mine_scoop(ship):
			sweepers.append(ship)
	lay_ships.sort_custom(func(a: StarshipData, b: StarshipData) -> bool:
		return int(a.ship_id) < int(b.ship_id)
	)
	sweepers.sort_custom(func(a: StarshipData, b: StarshipData) -> bool:
		return int(a.ship_id) < int(b.ship_id)
	)

	var next_preview_id: Array[int] = [-1]
	for ship: StarshipData in lay_ships:
		_apply_ship_lay_mines(working_fields, ship, _ship_mine_action_position(ship), next_preview_id)

	for ship: StarshipData in sweepers:
		var sweep_pos: Vector2 = _ship_mine_action_position(ship)
		var sweep_units: float = _ship_beam_sweep_units(ship)
		var fighter_units: float = _ship_fighter_sweep_units(ship)

		if sweep_units > 0.0 or fighter_units > 0.0:
			for i: int in range(working_fields.size()):
				var field: Dictionary = working_fields[i]
				if not _minefield_is_sweep_target(field, ship):
					continue
				var dist: int = int(floor(sweep_pos.distance_to(Vector2(float(field["x"]), float(field["y"])))))
				var radius: float = float(field["radius"])
				var isweb: bool = bool(field["isweb"])
				var removed: float = 0.0
				if sweep_units > 0.0 and float(dist) <= radius + (0.0 if isweb else 5.0):
					removed += sweep_units * (3.0 if isweb else 4.0)
				if fighter_units > 0.0 and not isweb and float(dist) <= radius + 100.0:
					removed += fighter_units
				if removed <= 0.0:
					continue
				working_fields[i] = _apply_minefield_unit_loss(field, removed, ship)

		if _ship_can_preview_mine_scoop(ship):
			_apply_ship_mine_scoop(working_fields, ship, sweep_pos)

	for i: int in range(working_fields.size()):
		working_fields[i] = _apply_minefield_decay(working_fields[i])

	for field: Dictionary in working_fields:
		if not bool(field.get("swept", false)) and not bool(field.get("laid", false)) and not bool(field.get("decayed", false)):
			continue
		var start_radius: float = float(field.get("start_radius", 0.0))
		var start_units: float = float(field.get("start_units", 0.0))
		if bool(field.get("swept", false)):
			start_radius = float(field.get("sweep_start_radius", start_radius))
			start_units = float(field.get("sweep_start_units", start_units))
		var has_action: bool = bool(field.get("swept", false)) or bool(field.get("laid", false))
		var end_radius: float = float(field.get("radius", start_radius))
		var end_units: float = float(field["units"])
		if has_action and bool(field.get("decayed", false)):
			end_radius = float(field.get("decay_start_radius", end_radius))
			end_units = float(field.get("decay_start_units", end_units))
		if is_equal_approx(end_radius, start_radius) and is_equal_approx(end_units, start_units) and not bool(field.get("decayed", false)):
			continue
		_mine_sweep_preview_by_id[int(field["id"])] = {
			"x": float(field["x"]),
			"y": float(field["y"]),
			"ownerid": int(field["ownerid"]),
			"start_units": start_units,
			"end_units": end_units,
			"start_radius": start_radius,
			"end_radius": end_radius,
			"new_field": bool(field.get("new_field", false)),
			"laid": bool(field.get("laid", false)),
			"swept": bool(field.get("swept", false)),
			"decayed": bool(field.get("decayed", false)),
			"decay_start_units": float(field.get("decay_start_units", end_units)),
			"decay_end_units": float(field.get("decay_end_units", field["units"])),
			"decay_start_radius": float(field.get("decay_start_radius", end_radius)),
			"decay_end_radius": float(field.get("decay_end_radius", field["radius"])),
			"sweepers": field["sweepers"]
		}

func _ship_can_preview_lay_mines(ship: StarshipData) -> bool:
	if ship == null or ship.ishidden:
		return false
	if not game_state.is_my_ship(ship):
		return false
	if _dict_float(ship.raw, ["neutronium"], 0.0) <= 0.0:
		return false
	if _dict_int(ship.raw, ["ammo"], 0) <= 0:
		return false
	if _dict_int(ship.raw, ["torps"], 0) <= 0:
		return false
	var mission_id: int = _dict_int(ship.raw, ["mission"], 0)
	var race_id: int = game_state.get_race_id_of_player(ship.ownerid)
	return mission_id == 2 or (mission_id == 8 and race_id == 7) or (mission_id == 28 and race_id == 5)

func _apply_ship_lay_mines(
	working_fields: Array[Dictionary],
	ship: StarshipData,
	lay_pos: Vector2,
	next_preview_id: Array[int]
) -> void:
	var units: float = _ship_mine_lay_units(ship)
	if units <= 0.0:
		return

	var is_web: bool = _dict_int(ship.raw, ["mission"], 0) == 8
	var field_owner_id: int = _mine_lay_owner_id(ship)
	var field_index: int = _nearest_lay_target_minefield_index(working_fields, field_owner_id, is_web, lay_pos)
	if field_index < 0:
		var field_id: int = next_preview_id[0]
		next_preview_id[0] = field_id - 1
		working_fields.append({
			"id": field_id,
			"ownerid": field_owner_id,
			"x": lay_pos.x,
			"y": lay_pos.y,
			"units": 0.0,
			"radius": 0.0,
			"start_units": 0.0,
			"start_radius": 0.0,
			"isweb": is_web,
			"new_field": true,
			"laid": false,
			"swept": false,
			"decayed": false,
			"sweepers": PackedInt32Array()
		})
		field_index = working_fields.size() - 1

	var field: Dictionary = working_fields[field_index]
	var max_units: float = _minefield_max_units()
	var next_units: float = minf(max_units, float(field["units"]) + units)
	if is_equal_approx(next_units, float(field["units"])):
		return
	field["units"] = next_units
	field["radius"] = _minefield_radius_from_units(next_units)
	field["laid"] = true
	working_fields[field_index] = field

func _nearest_lay_target_minefield_index(
	working_fields: Array[Dictionary],
	owner_id: int,
	is_web: bool,
	lay_pos: Vector2
) -> int:
	var best_index: int = -1
	var best_dist: float = INF
	for i: int in range(working_fields.size()):
		var field: Dictionary = working_fields[i]
		if int(field.get("ownerid", -1)) != owner_id:
			continue
		if bool(field.get("isweb", false)) != is_web:
			continue
		var dist: float = lay_pos.distance_to(Vector2(float(field["x"]), float(field["y"])))
		if dist < best_dist:
			best_dist = dist
			best_index = i
	if best_index >= 0 and best_dist <= float(working_fields[best_index].get("radius", 0.0)):
		return best_index
	return -1

func _ship_mine_lay_units(ship: StarshipData) -> float:
	var torps: int = _ship_mine_lay_torps(ship)
	if torps <= 0:
		return 0.0
	var torpedo_id: int = _dict_int(ship.raw, ["torpedoid"], 0)
	if torpedo_id <= 0:
		return 0.0
	var units: float = float(torps * torpedo_id * torpedo_id)
	if game_state.get_race_id_of_player(ship.ownerid) == 9:
		units *= 4.0
	if _dict_int(ship.raw, ["mission"], 0) == 28 and game_state.get_race_id_of_player(ship.ownerid) == 5:
		units = ceil(units / 2.0)
	return units

func _ship_mine_lay_torps(ship: StarshipData) -> int:
	var torps: int = _dict_int(ship.raw, ["ammo"], 0)
	var fc: String = String(ship.raw.get("friendlycode", "")).strip_edges().to_lower()
	if not fc.begins_with("md"):
		return torps
	if fc == "mdh":
		return int(floor(float(torps) / 2.0))
	if fc == "mdq":
		return int(floor(float(torps) / 4.0))
	var md_val: String = fc.replace("md", "")
	if md_val.is_valid_int():
		var amount: int = int(md_val)
		if amount == 0:
			amount = 10
		amount *= 10
		return min(torps, amount)
	return torps

func _mine_lay_owner_id(ship: StarshipData) -> int:
	var owner_id: int = int(ship.ownerid)
	var fc: String = String(ship.raw.get("friendlycode", "")).strip_edges().to_lower()
	if not fc.begins_with("mi"):
		return owner_id
	var value: int = _base36_to_int(fc.replace("mi", ""))
	if value <= 0 or value > _game_slots():
		return owner_id
	return value

func _base36_to_int(text: String) -> int:
	var result: int = 0
	var clean: String = text.strip_edges().to_lower()
	if clean.is_empty():
		return 0
	for i: int in range(clean.length()):
		var code: int = clean.unicode_at(i)
		var digit: int = -1
		if code >= 48 and code <= 57:
			digit = code - 48
		elif code >= 97 and code <= 122:
			digit = code - 87
		if digit < 0 or digit >= 36:
			return 0
		result = result * 36 + digit
	return result

func _ship_can_preview_mine_sweep(ship: StarshipData) -> bool:
	if ship == null or ship.ishidden:
		return false
	if not game_state.is_my_ship(ship):
		return false
	if _dict_int(ship.raw, ["mission"], 0) != 1:
		return false
	if _dict_float(ship.raw, ["neutronium"], 0.0) <= 0.0:
		return false
	return _ship_beam_sweep_units(ship) > 0.0 or _ship_fighter_sweep_units(ship) > 0.0

func _ship_can_preview_mine_scoop(ship: StarshipData) -> bool:
	if ship == null or ship.ishidden:
		return false
	if not game_state.is_my_ship(ship):
		return false
	if _dict_int(ship.raw, ["mission"], 0) != 1:
		return false
	if _dict_float(ship.raw, ["neutronium"], 0.0) <= 0.0:
		return false
	if _dict_int(ship.raw, ["torps"], 0) <= 0:
		return false
	if _mine_scoop_units_per_torp(ship) <= 0.0:
		return false
	return String(ship.raw.get("friendlycode", "")).strip_edges().to_lower() == "msc"

func _apply_minefield_unit_loss(field: Dictionary, removed: float, ship: StarshipData) -> Dictionary:
	if not bool(field.get("swept", false)):
		field["sweep_start_units"] = float(field["units"])
		field["sweep_start_radius"] = float(field["radius"])
	var next_units: float = maxf(0.0, float(field["units"]) - removed)
	if is_equal_approx(next_units, float(field["units"])):
		return field
	field["units"] = next_units
	field["radius"] = _minefield_radius_from_units(next_units)
	field["swept"] = true
	var sweepers_for_field: PackedInt32Array = field["sweepers"]
	sweepers_for_field.append(int(ship.ship_id))
	field["sweepers"] = sweepers_for_field
	return field

func _apply_minefield_decay(field: Dictionary) -> Dictionary:
	var current_units: float = float(field.get("units", 0.0))
	var current_radius: float = float(field.get("radius", 0.0))
	if current_units <= 0.0 or current_radius <= 0.0:
		return field

	var in_nebula: bool = _minefield_overlaps_nebula(field)
	var decay: float = 0.85 if in_nebula else 0.95
	if current_units > 22500.0:
		decay = 1.0 - (0.05 * _minefield_density(current_units) * (3.0 if in_nebula else 1.0))

	var next_units: float = maxf(0.0, (current_units * decay) - 1.0)
	var next_radius: float = _minefield_radius_from_units(next_units)
	if is_equal_approx(next_units, current_units):
		return field

	field["decay_start_units"] = current_units
	field["decay_start_radius"] = current_radius
	field["decay_end_units"] = next_units
	field["decay_end_radius"] = next_radius
	field["units"] = next_units
	field["radius"] = next_radius
	field["decayed"] = true
	return field

func _minefield_density(units: float) -> float:
	return maxf(1.0, floor(units / 22500.0))

func _minefield_overlaps_nebula(field: Dictionary) -> bool:
	var center: Vector2 = Vector2(float(field.get("x", 0.0)), float(field.get("y", 0.0)))
	var radius: float = float(field.get("radius", 0.0))
	for nebula: NebulaData in game_state.nebulas:
		if nebula == null:
			continue
		for circle: NebulaCircleData in nebula.circles:
			if circle == null:
				continue
			var nebula_center: Vector2 = Vector2(circle.x, circle.y)
			if center.distance_to(nebula_center) < circle.radius + radius:
				return true
	return false

func _apply_ship_mine_scoop(working_fields: Array[Dictionary], ship: StarshipData, scoop_pos: Vector2) -> void:
	var open_cargo: int = _ship_open_cargo(ship)
	if open_cargo <= 0:
		return

	var units_per_torp: float = _mine_scoop_units_per_torp(ship)
	if units_per_torp <= 0.0:
		return

	while open_cargo > 0:
		var field_index: int = _nearest_scoopable_minefield_index(working_fields, ship, scoop_pos)
		if field_index < 0:
			return

		var field: Dictionary = working_fields[field_index]
		var max_units: float = float(open_cargo) * units_per_torp
		var removed: float = minf(float(field["units"]), max_units)
		if removed <= 0.0:
			return

		working_fields[field_index] = _apply_minefield_unit_loss(field, removed, ship)
		var torps_loaded: int = int(floor(removed / units_per_torp))
		if torps_loaded <= 0 and is_equal_approx(float(working_fields[field_index]["units"]), 0.0):
			continue
		if torps_loaded <= 0:
			return
		open_cargo -= torps_loaded

func _nearest_scoopable_minefield_index(working_fields: Array[Dictionary], ship: StarshipData, scoop_pos: Vector2) -> int:
	var best_index: int = -1
	var best_dist: float = INF
	for i: int in range(working_fields.size()):
		var field: Dictionary = working_fields[i]
		if int(field.get("ownerid", -1)) != int(ship.ownerid):
			continue
		if float(field.get("units", 0.0)) <= 0.0 or float(field.get("radius", 0.0)) <= 0.0:
			continue
		var dist: float = floor(scoop_pos.distance_to(Vector2(float(field["x"]), float(field["y"]))))
		if dist > float(field["radius"]):
			continue
		if dist < best_dist:
			best_dist = dist
			best_index = i
	return best_index

func _ship_open_cargo(ship: StarshipData) -> int:
	var capacity: int = int(_hull_cargo(ship.hullid))
	if capacity <= 0:
		return 0
	return max(0, capacity - _ship_cargo_used(ship.raw))

func _ship_cargo_used(raw: Dictionary) -> int:
	return _dict_int(raw, ["duranium"], 0) \
		+ _dict_int(raw, ["tritanium"], 0) \
		+ _dict_int(raw, ["molybdenum"], 0) \
		+ _dict_int(raw, ["clans"], 0) \
		+ _dict_int(raw, ["supplies"], 0) \
		+ _dict_int(raw, ["ammo"], 0)

func _mine_scoop_units_per_torp(ship: StarshipData) -> float:
	var torpedo_id: int = _dict_int(ship.raw, ["torpedoid"], 0)
	if torpedo_id <= 0:
		return 0.0
	var units: float = float(torpedo_id * torpedo_id)
	if game_state.get_race_id_of_player(ship.ownerid) == 9:
		units *= 4.0
	return units

func _ship_beam_sweep_units(ship: StarshipData) -> float:
	var beams: int = _dict_int(ship.raw, ["beams"], 0)
	if beams <= 0:
		return 0.0
	var beam_id: int = _dict_int(ship.raw, ["beamid"], 0)
	if game_state.get_race_id_of_player(ship.ownerid) == 12:
		var hull_cargo: float = _hull_cargo(ship.hullid)
		if hull_cargo > 0.0:
			beam_id = int(floor((_dict_float(ship.raw, ["clans"], 0.0) / hull_cargo) * 9.0)) + 1
	beam_id = clampi(beam_id, 0, 10)
	return float(beams * beam_id * beam_id)

func _ship_fighter_sweep_units(ship: StarshipData) -> float:
	if game_state.get_race_id_of_player(ship.ownerid) != 11:
		return 0.0
	if _dict_int(ship.raw, ["bays"], 0) <= 0:
		return 0.0
	return float(_dict_int(ship.raw, ["ammo"], 0) * 20)

func _ship_mine_action_position(ship: StarshipData) -> Vector2:
	if _ship_has_at_command_ship(ship) and ship.has_target():
		return Vector2(ship.targetx, ship.targety)
	return Vector2(ship.x, ship.y)

func _ship_has_at_command_ship(ship: StarshipData) -> bool:
	for other: StarshipData in game_state.starships:
		if other == null or other.ishidden:
			continue
		if int(other.ownerid) != int(ship.ownerid):
			continue
		if int(other.hullid) != 1089:
			continue
		if is_equal_approx(other.x, ship.x) and is_equal_approx(other.y, ship.y):
			return true
	return false

func _minefield_is_sweep_target(field: Dictionary, ship: StarshipData) -> bool:
	var owner_id: int = int(field.get("ownerid", -1))
	if owner_id <= 0 or owner_id == int(ship.ownerid):
		return false
	return _relation_to_player(owner_id) < 2

func _relation_to_player(player_id: int) -> int:
	if player_id <= 0 or game_state.last_turn_json.is_empty():
		return 0
	var rst_v: Variant = game_state.last_turn_json.get("rst")
	if not (rst_v is Dictionary):
		return 0
	var rst: Dictionary = rst_v as Dictionary
	var relations_v: Variant = rst.get("relations", [])
	if not (relations_v is Array):
		return 0
	for item: Variant in relations_v as Array:
		if not (item is Dictionary):
			continue
		var relation: Dictionary = item as Dictionary
		if _dict_int(relation, ["playertoid"], -1) == player_id:
			return _dict_int(relation, ["relationto"], 0)
	return 0

func _minefield_radius_from_units(units: float) -> float:
	var radius: float = minf(150.0, floor(sqrt(maxf(0.0, units))))
	if _dict_bool(_settings_from_rst(), ["isacademy"], false):
		radius = minf(4.0, floor(radius / 30.0))
	return radius

func _minefield_max_units() -> float:
	if _is_player_advantage_active(72):
		return INF
	if _is_player_advantage_active(48):
		return 22500.0
	return 10000.0

func _is_player_advantage_active(advantage_id: int) -> bool:
	var player: Dictionary = _player_from_rst()
	var raw: String = _dict_string(player, ["activeadvantages"], "")
	if raw.strip_edges().is_empty():
		raw = _dict_string(_race_info_from_rst(game_state.get_my_race_id()), ["baseadvantages"], "")
	for part: String in raw.split(",", false):
		var text: String = part.strip_edges()
		if text.is_valid_int() and int(text) == advantage_id:
			return true
	return false

func _player_from_rst() -> Dictionary:
	if game_state.last_turn_json.is_empty():
		return {}
	var rst_v: Variant = game_state.last_turn_json.get("rst")
	if not (rst_v is Dictionary):
		return {}
	var rst: Dictionary = rst_v as Dictionary
	var player_v: Variant = rst.get("player", {})
	if player_v is Dictionary:
		return player_v as Dictionary
	return {}

func _race_info_from_rst(race_id: int) -> Dictionary:
	if game_state.last_turn_json.is_empty():
		return {}
	var rst_v: Variant = game_state.last_turn_json.get("rst")
	if not (rst_v is Dictionary):
		return {}
	var races_v: Variant = (rst_v as Dictionary).get("races", [])
	if not (races_v is Array):
		return {}
	for item: Variant in races_v as Array:
		if item is Dictionary and _dict_int(item as Dictionary, ["id"], -1) == race_id:
			return item as Dictionary
	return {}

func _game_slots() -> int:
	if game_state.last_turn_json.is_empty():
		return 11
	var rst_v: Variant = game_state.last_turn_json.get("rst")
	if not (rst_v is Dictionary):
		return 11
	var rst: Dictionary = rst_v as Dictionary
	var game_v: Variant = rst.get("game", {})
	if game_v is Dictionary:
		return _dict_int(game_v as Dictionary, ["slots"], 11)
	return 11

func _hull_cargo(hull_id: int) -> float:
	if game_state.last_turn_json.is_empty():
		return 0.0
	var rst_v: Variant = game_state.last_turn_json.get("rst")
	if not (rst_v is Dictionary):
		return 0.0
	var rst: Dictionary = rst_v as Dictionary
	var hulls_v: Variant = rst.get("hulls", [])
	if not (hulls_v is Array):
		return 0.0
	for hull_v: Variant in hulls_v as Array:
		if not (hull_v is Dictionary):
			continue
		var hull: Dictionary = hull_v as Dictionary
		if _dict_int(hull, ["id"], -1) == hull_id:
			return _dict_float(hull, ["cargo"], 0.0)
	return 0.0

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
	var dscale: float = _screen_px_to_world(1.0)
	draw_set_transform(pos, 0.0, Vector2(dscale, dscale))
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
		_draw_ionstorm_shape(circle_specs, storm.voltage)

	_draw_ionstorm_heading(storm)

func _draw_ionstorm_shape(circle_specs: Array, storm_voltage: float) -> void:
	var bounds: Rect2 = _circle_specs_bounds(circle_specs)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return

	_draw_circle_union_field_fill(circle_specs, bounds, ION_STORM_BASE_COLOR, "ionstorm")
	_draw_circle_union_outline(circle_specs, _ionstorm_border_color(storm_voltage), 2.0)

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

func _draw_circle_union_field_fill(
	circle_specs: Array,
	bounds: Rect2,
	base_color: Color,
	field_kind: String
) -> void:
	var cell_size: float = maxf(16.0, maxf(bounds.size.x, bounds.size.y) / 80.0)
	var x_steps: int = int(ceil(bounds.size.x / cell_size))
	var y_steps: int = int(ceil(bounds.size.y / cell_size))

	for xi: int in range(x_steps):
		for yi: int in range(y_steps):
			var p00: Vector2 = bounds.position + Vector2(float(xi) * cell_size, float(yi) * cell_size)
			var p10: Vector2 = bounds.position + Vector2(float(xi + 1) * cell_size, float(yi) * cell_size)
			var p01: Vector2 = bounds.position + Vector2(float(xi) * cell_size, float(yi + 1) * cell_size)
			var p11: Vector2 = bounds.position + Vector2(float(xi + 1) * cell_size, float(yi + 1) * cell_size)
			_draw_circle_union_field_triangle(p00, p10, p11, circle_specs, base_color, field_kind)
			_draw_circle_union_field_triangle(p00, p11, p01, circle_specs, base_color, field_kind)

func _draw_circle_union_field_triangle(
	a: Vector2,
	b: Vector2,
	c: Vector2,
	circle_specs: Array,
	base_color: Color,
	field_kind: String
) -> void:
	var ca: Color = _circle_union_color_at(a, circle_specs, base_color, field_kind)
	var cb: Color = _circle_union_color_at(b, circle_specs, base_color, field_kind)
	var cc: Color = _circle_union_color_at(c, circle_specs, base_color, field_kind)
	if ca.a <= 0.0 and cb.a <= 0.0 and cc.a <= 0.0:
		return
	draw_primitive(PackedVector2Array([a, b, c]), PackedColorArray([ca, cb, cc]), PackedVector2Array())

func _circle_union_color_at(
	pos: Vector2,
	circle_specs: Array,
	base_color: Color,
	field_kind: String
) -> Color:
	var c: Color = base_color
	if not _point_in_circle_union(pos, circle_specs):
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
		var falloff: float = _contained_smooth_falloff(dist_ratio) if field_kind == "ionstorm" else _smooth_falloff(dist_ratio)
		if falloff > 0.0:
			alpha = maxf(alpha, _field_alpha_for_strength(strength, field_kind) * falloff)

	c.a = alpha
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

func _contained_smooth_falloff(dist_ratio: float) -> float:
	if dist_ratio >= 1.0:
		return 0.0
	var t: float = clampf(dist_ratio, 0.0, 1.0)
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
	var zoom: float = maxf($Camera2D.zoom.x, 0.001)
	if _is_debris_planetoid(p):
		return clampf((PLANET_RADIUS_DRAW * 0.35) / zoom, PLANETOID_MIN_DETAIL_RADIUS, PLANET_RADIUS_DRAW * 0.35)
	return clampf(PLANET_RADIUS_DRAW / zoom, PLANET_MIN_DETAIL_RADIUS, PLANET_RADIUS_DRAW)

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

func _settings_from_rst() -> Dictionary:
	if game_state.last_turn_json.is_empty():
		return {}
	var rst_v: Variant = game_state.last_turn_json.get("rst")
	if not (rst_v is Dictionary):
		return {}
	var rst: Dictionary = rst_v as Dictionary
	var settings_v: Variant = rst.get("settings", {})
	if settings_v is Dictionary:
		return settings_v as Dictionary
	return {}

func _ship_scan_range() -> float:
	var settings: Dictionary = _settings_from_rst()
	return maxf(0.0, _dict_float(settings, [
		"shipscanrange",
		"ship_scan_range",
		"shipscan",
		"scanrange",
		"scan_range",
		"scanningrange",
		"scannerange",
		"sensorrange",
		"sensor_range"
	], 300.0))

func _dict_int(d: Dictionary, keys: Array[String], fallback: int = 0) -> int:
	for key: String in keys:
		if not d.has(key):
			continue
		var value: Variant = d.get(key)
		if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
			return int(value)
		var text: String = String(value)
		if text.is_valid_int():
			return int(text)
		if text.is_valid_float():
			return int(float(text))
	return fallback

func _dict_float(d: Dictionary, keys: Array[String], fallback: float = 0.0) -> float:
	for key: String in keys:
		if not d.has(key):
			continue
		var value: Variant = d.get(key)
		if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
			return float(value)
		var text: String = String(value)
		if text.is_valid_float():
			return float(text)
	return fallback

func _dict_string(d: Dictionary, keys: Array[String], fallback: String = "") -> String:
	for key: String in keys:
		if d.has(key):
			return String(d.get(key, fallback))
	return fallback

func _dict_bool(d: Dictionary, keys: Array[String], fallback: bool = false) -> bool:
	for key: String in keys:
		if not d.has(key):
			continue
		var value: Variant = d.get(key)
		if typeof(value) == TYPE_BOOL:
			return bool(value)
		if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
			return int(value) != 0
		var text: String = String(value).to_lower()
		if text == "true" or text == "1":
			return true
		if text == "false" or text == "0":
			return false
	return fallback
