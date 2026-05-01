extends HBoxContainer

const PlanetMath = preload("res://Scripts/Services/PlanetMath.gd")

@onready var turn_label: Label = %TurnLabel
@onready var race_label: Label = %RaceLabel
@onready var planets_button: Button = %PlanetsButton
@onready var ships_button: Button = %ShipsButton
@onready var starbases_button: Button = %StarbasesButton
@onready var vcr_button: Button = %VcrButton
@onready var game_state: Node = get_node("/root/GameState")
@onready var overlay_root: Control = $"../../OverlayRoot"
@onready var planet_info_panel: Control = $"../../OverlayRoot/PlanetInfoPanel"

const VCR_SIM_PROJECT_PATH: String = "C:/Users/Windows/Documents/planets-vcr-sim"
const GODOT_EXE_FALLBACK: String = "C:/Tools/godot.exe"
const PANEL_SIZE: Vector2 = Vector2(477.0, 708.0)
const PANEL_POS: Vector2 = Vector2(8.0, 7.0)
const TORPEDO_NAMES: PackedStringArray = [
	"None",
	"Mark 1 Photon",
	"Proton Torpedo",
	"Mark 2 Photon",
	"Gamma Bomb",
	"Mark 3 Photon",
	"Mark 4 Photon",
	"Mark 5 Photon",
	"Mark 6 Photon",
	"Mark 7 Photon",
	"Mark 8 Photon"
]
const ENGINE_NAMES: PackedStringArray = [
	"None",
	"Stardrive 1",
	"Stardrive 2",
	"Stardrive 3",
	"Super StarDrive 4",
	"Nova Drive 5",
	"HeavyNova Drive 6",
	"Quantum Drive 7",
	"Heavy Quantum Drive 8",
	"Transwarp Drive"
]

var _ships_panel: PanelContainer = null
var _ships_list: VBoxContainer = null
var _starbases_panel: PanelContainer = null
var _starbases_list: VBoxContainer = null

func _ready() -> void:
	_update_status()
	planets_button.pressed.connect(_on_planets_button_pressed)
	ships_button.pressed.connect(_on_ships_button_pressed)
	starbases_button.pressed.connect(_on_starbases_button_pressed)
	vcr_button.pressed.connect(_on_vcr_button_pressed)

	if game_state.has_signal("turn_loaded"):
		game_state.connect("turn_loaded", Callable(self, "_update_status"))
		game_state.connect("turn_loaded", Callable(self, "_refresh_open_info_panel"))
	if game_state.has_signal("selection_changed"):
		game_state.connect("selection_changed", Callable(self, "_on_selection_changed"))

func _update_status() -> void:
	turn_label.text = str(game_state.get_current_turn())
	race_label.text = _owner_abbrev(game_state.get_my_race_id())

func _owner_abbrev(race_id: int) -> String:
	if game_state.config == null:
		return "-" if race_id <= 0 else str(race_id)
	return game_state.config.get_owner_abbrev(race_id)

func _on_planets_button_pressed() -> void:
	game_state.set_selection_mode("planet")
	_hide_aux_info_panels()
	game_state.clear_selection()
	game_state.clear_selection_for_kind("planet")
	planet_info_panel.visible = true

func _on_ships_button_pressed() -> void:
	game_state.set_selection_mode("ship")
	_ensure_ships_panel()
	_hide_all_info_panels()
	game_state.clear_selection()
	_populate_ships_panel()
	_ships_panel.visible = true

func _on_starbases_button_pressed() -> void:
	game_state.set_selection_mode("starbase")
	_ensure_starbases_panel()
	_hide_all_info_panels()
	game_state.clear_selection()
	_populate_starbases_panel()
	_starbases_panel.visible = true

func _refresh_open_info_panel() -> void:
	if _ships_panel != null and _ships_panel.visible:
		_populate_ships_panel()
	if _starbases_panel != null and _starbases_panel.visible:
		_populate_starbases_panel()

func _on_selection_changed(kind: String, selected_id: int) -> void:
	if kind == "planet" and selected_id >= 0:
		_hide_aux_info_panels()
	elif kind == "ship":
		_ensure_ships_panel()
		_hide_all_info_panels()
		_populate_ships_panel()
		_ships_panel.visible = true
	elif kind == "starbase":
		_ensure_starbases_panel()
		_hide_all_info_panels()
		_populate_starbases_panel()
		_starbases_panel.visible = true

func _hide_all_info_panels() -> void:
	planet_info_panel.visible = false
	_hide_aux_info_panels()

func _hide_aux_info_panels() -> void:
	if _ships_panel != null:
		_ships_panel.visible = false
	if _starbases_panel != null:
		_starbases_panel.visible = false

func _ensure_ships_panel() -> void:
	if _ships_panel != null:
		return
	var parts: Dictionary = _create_info_panel("Ships")
	_ships_panel = parts["panel"] as PanelContainer
	_ships_list = parts["list"] as VBoxContainer

func _ensure_starbases_panel() -> void:
	if _starbases_panel != null:
		return
	var parts: Dictionary = _create_info_panel("Starbases")
	_starbases_panel = parts["panel"] as PanelContainer
	_starbases_list = parts["list"] as VBoxContainer

func _create_info_panel(title: String) -> Dictionary:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = title + "InfoPanel"
	panel.custom_minimum_size = PANEL_SIZE
	panel.position = PANEL_POS
	panel.size = PANEL_SIZE
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_to_group("map_blocking_ui")
	panel.add_theme_stylebox_override("panel", _panel_style())
	overlay_root.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)

	var header: Label = Label.new()
	header.text = title
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", Color(0.04, 0.55, 0.96, 1.0))
	content.add_child(header)
	content.add_child(HSeparator.new())

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)

	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	content.add_child(HSeparator.new())
	var footer: HBoxContainer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(footer)

	var close_btn: Button = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func() -> void:
		panel.visible = false
	)
	footer.add_child(close_btn)

	return {"panel": panel, "list": list}

func _panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.082, 0.075, 0.082, 0.94)
	style.border_color = Color(0.45, 0.56, 0.62, 0.55)
	style.set_border_width_all(1)
	return style

func _populate_ships_panel() -> void:
	_clear_children(_ships_list)
	var ship: StarshipData = game_state.get_selected_ship() as StarshipData
	if ship == null:
		_add_summary_label(_ships_list, "No selection")
		return

	var hidden_text: String = " (hidden)" if ship.ishidden else ""
	var hull: Dictionary = _hull_info(ship.hullid)
	var cargo_capacity: int = _dict_int(hull, ["cargo"], 0)
	var fuel_capacity: int = _dict_int(hull, ["fueltank", "fuel"], 0)
	var cargo_used: int = _ship_cargo_used(ship.raw)
	var stack: Array[StarshipData] = _ships_at_same_position(ship)

	_add_summary_label(_ships_list, "#%d  %s%s" % [ship.ship_id, ship.display_hull_name(), hidden_text])
	_add_wrapped_label(_ships_list, _player_owner_label(ship.ownerid), false).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not ship.name.strip_edges().is_empty() and ship.name != ship.display_hull_name():
		_add_wrapped_label(_ships_list, ship.name, false).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if stack.size() > 1:
		_add_ship_stack_nav(_ships_list, stack, ship)

	_add_section_title(_ships_list, "Weapons")
	var weapons: GridContainer = _add_key_value_grid(_ships_list)
	var beam_count: int = _dict_int(ship.raw, ["beams"], 0)
	var torp_tubes: int = _dict_int(ship.raw, ["torps"], 0)
	var fighter_bays: int = _dict_int(ship.raw, ["bays"], 0)
	var ammo: int = _dict_int(ship.raw, ["ammo"], 0)
	_add_kv(weapons, "Engine", _engine_name(_dict_int(ship.raw, ["engineid"], 0)))
	if beam_count > 0:
		_add_kv(weapons, "Beams", _weapon_count_name(beam_count, _beam_name(_dict_int(ship.raw, ["beamid"], 0))))
	if torp_tubes > 0:
		_add_kv(weapons, "Launchers", _weapon_count_name(torp_tubes, _torpedo_name(_dict_int(ship.raw, ["torpedoid"], 0))))
		_add_kv(weapons, "Torpedoes", str(ammo))
	if fighter_bays > 0:
		_add_kv(weapons, "Fighter Bays", str(fighter_bays))
		_add_kv(weapons, "Fighters", str(ammo))
	if beam_count <= 0 and torp_tubes <= 0 and fighter_bays <= 0:
		_add_kv(weapons, "Weapons", "none")
	_add_kv(weapons, "Damage", "%d%%" % _dict_int(ship.raw, ["damage"], 0))
	_add_kv(weapons, "Crew", "%d / %d" % [
		_dict_int(ship.raw, ["crew"], 0),
		_dict_int(hull, ["crew"], 0)
	])
	_add_kv(weapons, "Mass", "%d kt" % _dict_int(ship.raw, ["mass"], _dict_int(hull, ["mass"], 0)))

	_add_section_title(_ships_list, "Cargo (%d / %s)" % [cargo_used, str(cargo_capacity) if cargo_capacity > 0 else "?"])
	var cargo: GridContainer = _add_key_value_grid(_ships_list)
	_add_kv(cargo, "Duranium", "%d kt" % _dict_int(ship.raw, ["duranium"], 0))
	_add_kv(cargo, "Tritanium", "%d kt" % _dict_int(ship.raw, ["tritanium"], 0))
	_add_kv(cargo, "Molybdenum", "%d kt" % _dict_int(ship.raw, ["molybdenum"], 0))
	_add_kv(cargo, "Colonists", "%d clans" % _dict_int(ship.raw, ["clans"], 0))
	_add_kv(cargo, "Supplies", "%d kt" % _dict_int(ship.raw, ["supplies"], 0))
	_add_kv(cargo, "Megacredits", "%d" % _dict_int(ship.raw, ["megacredits"], 0))
	_add_kv(cargo, "Neutronium", "%d / %s kt" % [
		_dict_int(ship.raw, ["neutronium", "fuel"], 0),
		str(fuel_capacity) if fuel_capacity > 0 else "?"
	])

	_add_section_title(_ships_list, "Orders")
	var orders: GridContainer = _add_key_value_grid(_ships_list)
	_add_kv(orders, "Position", "%.0f / %.0f" % [ship.x, ship.y])
	_add_kv(orders, "Target", "%.0f / %.0f" % [ship.targetx, ship.targety] if ship.has_target() else "-")
	_add_kv(orders, "Warp", str(int(ship.warp)))
	_add_kv(orders, "Heading", str(int(ship.heading)) if ship.heading >= 0.0 else "-")
	_add_kv(orders, "Distance", "%.1f ly" % Vector2(ship.x, ship.y).distance_to(Vector2(ship.targetx, ship.targety)) if ship.has_target() else "0.0 ly")
	_add_kv(orders, "Mission", _mission_label(_dict_int(ship.raw, ["mission"], 0)))
	_add_kv(orders, "Enemy", _enemy_label(_dict_int(ship.raw, ["enemy"], 0)))
	_add_kv(orders, "Friendly Code", _dict_string(ship.raw, ["friendlycode", "friendly_code"], ""))

func _populate_starbases_panel() -> void:
	_clear_children(_starbases_list)
	var sb: Dictionary = game_state.get_selected_starbase()
	if sb.is_empty():
		_add_summary_label(_starbases_list, "No selection")
		return

	var planet_id: int = _dict_int(sb, ["planetid", "planet_id"], game_state.selected_starbase_planet_id)
	var p: PlanetData = _planet_by_id(planet_id)
	_add_summary_label(_starbases_list, "Planet #%d  %s" % [planet_id, p.name if p != null else ""])
	_add_separator(_starbases_list)
	if p != null:
		_add_wrapped_label(_starbases_list, "Owner: %s" % _player_owner_label(int(p.ownerid)), false)
		_add_wrapped_label(_starbases_list, "Position: %.0f / %.0f" % [p.x, p.y], false)
	_add_wrapped_label(_starbases_list, "Defense: %d  Fighters: %d  Damage: %d" % [
		_dict_int(sb, ["defense", "defenseposts", "defense_posts"], 0),
		_dict_int(sb, ["fighters", "fightercount", "fighter_count"], 0),
		_dict_int(sb, ["damage"], 0)
	], false)
	_add_wrapped_label(_starbases_list, "Tech: hull %d, engine %d, beam %d, torp %d" % [
		_dict_int(sb, ["hulltechlevel", "hulltech"], 0),
		_dict_int(sb, ["enginetechlevel", "enginetech"], 0),
		_dict_int(sb, ["beamtechlevel", "beamtech"], 0),
		_dict_int(sb, ["torptechlevel", "torptech"], 0)
	], false)
	_add_wrapped_label(_starbases_list, "Storage: MC %d  Supplies %d" % [
		_dict_int(sb, ["megacredits", "mc"], 0),
		_dict_int(sb, ["supplies"], 0)
	], false)

func _add_section_title(parent: VBoxContainer, text: String) -> Label:
	_add_separator(parent)
	var label: Label = _add_wrapped_label(parent, text, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.04, 0.55, 0.96, 1.0))
	return label

func _add_key_value_grid(parent: VBoxContainer) -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 4)
	parent.add_child(grid)
	return grid

func _add_kv(parent: GridContainer, key: String, value: String) -> void:
	var key_label: Label = Label.new()
	key_label.text = key
	key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(key_label)

	var value_label: Label = Label.new()
	value_label.text = value if not value.is_empty() else "-"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value_label.add_theme_color_override("font_color", Color(0.54, 1.0, 0.58, 1.0))
	parent.add_child(value_label)

func _add_ship_stack_nav(parent: VBoxContainer, stack: Array[StarshipData], current_ship: StarshipData) -> void:
	var index: int = _ship_stack_index(stack, int(current_ship.ship_id))
	if index < 0:
		return

	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var prev_btn: Button = Button.new()
	prev_btn.text = "<"
	prev_btn.custom_minimum_size = Vector2(34.0, 0.0)
	prev_btn.pressed.connect(func() -> void:
		var prev_index: int = (index - 1 + stack.size()) % stack.size()
		game_state.select_ship(int(stack[prev_index].ship_id))
	)
	row.add_child(prev_btn)

	var label: Label = Label.new()
	label.text = "%d / %d at this position" % [index + 1, stack.size()]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(label)

	var next_btn: Button = Button.new()
	next_btn.text = ">"
	next_btn.custom_minimum_size = Vector2(34.0, 0.0)
	next_btn.pressed.connect(func() -> void:
		var next_index: int = (index + 1) % stack.size()
		game_state.select_ship(int(stack[next_index].ship_id))
	)
	row.add_child(next_btn)

func _add_summary_label(parent: VBoxContainer, text: String) -> void:
	var label: Label = _add_wrapped_label(parent, text, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _add_separator(parent: VBoxContainer) -> void:
	parent.add_child(HSeparator.new())

func _add_wrapped_label(parent: VBoxContainer, text: String, highlight: bool) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if highlight:
		label.add_theme_color_override("font_color", Color(0.85, 0.96, 1.0, 1.0))
	parent.add_child(label)
	return label

func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _player_owner_label(player_id: int) -> String:
	if player_id <= 0:
		return "unowned"
	var race_id: int = game_state.get_race_id_of_player(player_id)
	if race_id <= 0:
		return "Player %d" % player_id
	return "%s / Player %d" % [game_state.config.get_owner_abbrev(race_id), player_id]

func _planet_by_id(planet_id: int) -> PlanetData:
	for p: PlanetData in game_state.planets:
		if int(p.planet_id) == planet_id:
			return p
	return null

func _hull_info(hull_id: int) -> Dictionary:
	if game_state.last_turn_json.is_empty():
		return {}
	var rst_v: Variant = game_state.last_turn_json.get("rst")
	if not (rst_v is Dictionary):
		return {}
	var rst: Dictionary = rst_v as Dictionary
	var hulls_v: Variant = rst.get("hulls", [])
	if not (hulls_v is Array):
		return {}
	for hull_v: Variant in hulls_v as Array:
		if not (hull_v is Dictionary):
			continue
		var hull: Dictionary = hull_v as Dictionary
		if _dict_int(hull, ["id"], -1) == hull_id:
			return hull
	return {}

func _ship_cargo_used(raw: Dictionary) -> int:
	return _dict_int(raw, ["duranium"], 0) \
		+ _dict_int(raw, ["tritanium"], 0) \
		+ _dict_int(raw, ["molybdenum"], 0) \
		+ _dict_int(raw, ["clans"], 0) \
		+ _dict_int(raw, ["supplies"], 0) \
		+ _dict_int(raw, ["megacredits"], 0) \
		+ _dict_int(raw, ["ammo"], 0)

func _ships_at_same_position(ship: StarshipData) -> Array[StarshipData]:
	var result: Array[StarshipData] = []
	for other: StarshipData in game_state.starships:
		if other == null or other.ishidden:
			continue
		if abs(other.x - ship.x) <= 0.01 and abs(other.y - ship.y) <= 0.01:
			result.append(other)
	result.sort_custom(func(a: StarshipData, b: StarshipData) -> bool:
		return int(a.ship_id) < int(b.ship_id)
	)
	return result

func _ship_stack_index(stack: Array[StarshipData], ship_id: int) -> int:
	for i: int in range(stack.size()):
		if int(stack[i].ship_id) == ship_id:
			return i
	return -1

func _weapon_count_name(count: int, name: String) -> String:
	if count <= 0:
		return "none"
	return "%d %s" % [count, name]

func _beam_name(beam_id: int) -> String:
	if beam_id >= 0 and beam_id < PlanetMath.BEAM_NAMES.size():
		return PlanetMath.BEAM_NAMES[beam_id]
	return "Beam %d" % beam_id

func _torpedo_name(torpedo_id: int) -> String:
	if torpedo_id >= 0 and torpedo_id < TORPEDO_NAMES.size():
		return TORPEDO_NAMES[torpedo_id]
	return "Torpedo %d" % torpedo_id

func _engine_name(engine_id: int) -> String:
	if engine_id >= 0 and engine_id < ENGINE_NAMES.size():
		return ENGINE_NAMES[engine_id]
	return "Engine %d" % engine_id

func _mission_label(mission_id: int) -> String:
	if mission_id <= 0:
		return "None"
	return "Mission %d" % mission_id

func _enemy_label(enemy_player_id: int) -> String:
	if enemy_player_id <= 0:
		return "None"
	return _player_owner_label(enemy_player_id)

func _dict_int(d: Dictionary, keys: Array[String], fallback: int = 0) -> int:
	for key: String in keys:
		if not d.has(key):
			continue
		var v: Variant = d.get(key)
		if typeof(v) == TYPE_INT:
			return int(v)
		if typeof(v) == TYPE_FLOAT:
			return int(float(v))
		var s: String = String(v)
		if s.is_valid_int():
			return s.to_int()
		if s.is_valid_float():
			return int(float(s))
	return fallback

func _dict_string(d: Dictionary, keys: Array[String], fallback: String = "") -> String:
	for key: String in keys:
		if d.has(key):
			return String(d.get(key, fallback))
	return fallback

func _on_vcr_button_pressed() -> void:
	var game_id: int = game_state.get_game_id()
	if game_id <= 0:
		push_warning("VCR: no game selected")
		return

	var turn_path: String = ProjectSettings.globalize_path(GameStorage.latest_turn_path(game_id))
	if not FileAccess.file_exists(turn_path):
		push_warning("VCR: latest_turn.json not found: " + turn_path)
		return

	var godot_exe: String = GODOT_EXE_FALLBACK if FileAccess.file_exists(GODOT_EXE_FALLBACK) else OS.get_executable_path()

	var args: PackedStringArray = PackedStringArray([
		"--path",
		VCR_SIM_PROJECT_PATH,
		"--",
		"--turn-file=" + turn_path
	])
	var pid: int = OS.create_process(godot_exe, args, false)
	if pid < 0:
		push_warning("VCR: failed to start simulator with " + godot_exe)
