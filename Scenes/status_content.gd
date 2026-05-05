extends HBoxContainer

const PlanetMathScript = preload("res://Scripts/Services/PlanetMath.gd")

@onready var turn_text_label: Label = $Turn
@onready var turn_label: Label = %TurnLabel
@onready var race_text_label: Label = $Race
@onready var race_label: Label = %RaceLabel
@onready var planets_button: Button = %PlanetsButton
@onready var ships_button: Button = %ShipsButton
@onready var starbases_button: Button = %StarbasesButton
@onready var vcr_button: Button = %VcrButton
@onready var messages_button: Button = %MessagesButton
@onready var reports_button: Button = %ReportsButton
@onready var diplomacy_button: Button = %DiplomacyButton
@onready var game_state: Node = get_node("/root/GameState")
@onready var overlay_root: Control = $"../../OverlayRoot"
@onready var planet_info_panel: Control = $"../../OverlayRoot/PlanetInfoPanel"

const VCR_SIM_PROJECT_PATH: String = "C:/Users/Windows/Documents/planets-vcr-sim"
const GODOT_EXE_FALLBACK: String = "C:/Tools/godot.exe"
const PANEL_SIZE: Vector2 = Vector2(477.0, 708.0)
const PANEL_POS: Vector2 = Vector2(8.0, 7.0)
const PANEL_BODY_FONT_SIZE: int = 13
const STATUS_INFO_FONT_SIZE: int = 20
const STATUS_ARROW_MIN_SIZE: Vector2 = Vector2(28.0, 0.0)
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
var _messages_panel: PanelContainer = null
var _messages_list: VBoxContainer = null
var _reports_panel: PanelContainer = null
var _reports_list: VBoxContainer = null
var _diplomacy_panel: PanelContainer = null
var _diplomacy_list: VBoxContainer = null
var _status_controls_installed: bool = false

func _ready() -> void:
	_install_status_controls()
	_style_status_info()
	_update_status()
	planets_button.pressed.connect(_on_planets_button_pressed)
	ships_button.pressed.connect(_on_ships_button_pressed)
	starbases_button.pressed.connect(_on_starbases_button_pressed)
	vcr_button.pressed.connect(_on_vcr_button_pressed)
	messages_button.pressed.connect(_on_messages_button_pressed)
	reports_button.pressed.connect(_on_reports_button_pressed)
	diplomacy_button.pressed.connect(_on_diplomacy_button_pressed)

	if game_state.has_signal("turn_loaded"):
		game_state.connect("turn_loaded", Callable(self, "_update_status"))
		game_state.connect("turn_loaded", Callable(self, "_refresh_open_info_panel"))
	if game_state.has_signal("selection_changed"):
		game_state.connect("selection_changed", Callable(self, "_on_selection_changed"))

func _update_status() -> void:
	turn_label.text = str(game_state.get_current_turn())
	race_label.text = _owner_abbrev(game_state.get_my_race_id())
	turn_label.add_theme_color_override("font_color", Color(0.52, 0.86, 1.0, 1.0))
	var race_color: Color = RandAI_Config.get_player_color(game_state.my_player_id, game_state.get_my_race_id())
	race_color.a = 1.0
	race_label.add_theme_color_override("font_color", race_color)

func _style_status_info() -> void:
	for label: Label in [turn_text_label, turn_label, race_text_label, race_label]:
		label.add_theme_font_size_override("font_size", STATUS_INFO_FONT_SIZE)
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
		label.add_theme_constant_override("outline_size", 2)
	turn_text_label.add_theme_color_override("font_color", Color(0.82, 0.9, 0.92, 1.0))
	race_text_label.add_theme_color_override("font_color", Color(0.82, 0.9, 0.92, 1.0))

func _owner_abbrev(race_id: int) -> String:
	if game_state.config == null:
		return "-" if race_id <= 0 else str(race_id)
	return game_state.config.get_owner_abbrev(race_id)

func _install_status_controls() -> void:
	if _status_controls_installed:
		return
	_status_controls_installed = true

	_add_status_arrow(planets_button, true, Callable(self, "_select_previous_planet"))
	_add_status_arrow(planets_button, false, Callable(self, "_select_next_planet"))
	_add_status_separator_after(planets_button.get_index() + 1)

	_add_status_arrow(ships_button, true, Callable(self, "_select_previous_ship"))
	_add_status_arrow(ships_button, false, Callable(self, "_select_next_ship"))
	_add_status_separator_after(ships_button.get_index() + 1)

	_add_status_arrow(starbases_button, true, Callable(self, "_select_previous_starbase"))
	_add_status_arrow(starbases_button, false, Callable(self, "_select_next_starbase"))
	_add_status_separator_after(starbases_button.get_index() + 1)

	_add_status_separator_after(vcr_button.get_index())
	if messages_button != null:
		_add_status_separator_after(messages_button.get_index())
	if reports_button != null:
		_add_status_separator_after(reports_button.get_index())
	if diplomacy_button != null:
		_add_status_separator_after(diplomacy_button.get_index())

	_add_status_separator_after(turn_label.get_index())

func _add_status_arrow(target: Control, before: bool, callback: Callable) -> void:
	var btn: Button = Button.new()
	btn.text = "<" if before else ">"
	btn.custom_minimum_size = STATUS_ARROW_MIN_SIZE
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(callback)
	add_child(btn)
	var target_index: int = target.get_index()
	move_child(btn, target_index if before else target_index + 1)

func _add_status_separator_after(index: int) -> void:
	var sep: VSeparator = VSeparator.new()
	sep.custom_minimum_size = Vector2(8.0, 0.0)
	add_child(sep)
	move_child(sep, min(index + 1, get_child_count() - 1))

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

func _on_messages_button_pressed() -> void:
	_ensure_messages_panel()
	_hide_all_info_panels()
	_populate_messages_panel()
	_messages_panel.visible = true

func _on_reports_button_pressed() -> void:
	_ensure_reports_panel()
	_hide_all_info_panels()
	_populate_reports_panel()
	_reports_panel.visible = true

func _on_diplomacy_button_pressed() -> void:
	_ensure_diplomacy_panel()
	_hide_all_info_panels()
	_populate_diplomacy_panel()
	_diplomacy_panel.visible = true

func _select_previous_planet() -> void:
	_select_planet_relative(-1)

func _select_next_planet() -> void:
	_select_planet_relative(1)

func _select_previous_ship() -> void:
	_select_ship_relative(-1)

func _select_next_ship() -> void:
	_select_ship_relative(1)

func _select_previous_starbase() -> void:
	_select_starbase_relative(-1)

func _select_next_starbase() -> void:
	_select_starbase_relative(1)

func _select_planet_relative(direction: int) -> void:
	var ids: Array[int] = _sorted_planet_ids()
	if ids.is_empty():
		return
	game_state.set_selection_mode("planet")
	_hide_aux_info_panels()
	planet_info_panel.visible = true
	game_state.select_planet(_relative_id(ids, game_state.selected_planet_id, direction))

func _select_ship_relative(direction: int) -> void:
	var ids: Array[int] = _sorted_ship_ids()
	if ids.is_empty():
		return
	game_state.set_selection_mode("ship")
	game_state.select_ship(_relative_id(ids, game_state.selected_ship_id, direction))

func _select_starbase_relative(direction: int) -> void:
	var ids: Array[int] = _sorted_starbase_planet_ids()
	if ids.is_empty():
		return
	game_state.set_selection_mode("starbase")
	game_state.select_starbase(_relative_id(ids, game_state.selected_starbase_planet_id, direction))

func _relative_id(ids: Array[int], current_id: int, direction: int) -> int:
	var start_index: int = ids.find(current_id)
	if start_index < 0:
		return ids[0] if direction >= 0 else ids[ids.size() - 1]
	return ids[(start_index + direction + ids.size()) % ids.size()]

func _sorted_planet_ids() -> Array[int]:
	var ids: Array[int] = []
	for p: PlanetData in game_state.planets:
		if p != null and game_state.is_my_planet(p):
			ids.append(int(p.planet_id))
	ids.sort()
	return ids

func _sorted_ship_ids() -> Array[int]:
	var ids: Array[int] = []
	for ship: StarshipData in game_state.starships:
		if ship != null and not ship.ishidden and int(ship.ownerid) == int(game_state.my_player_id):
			ids.append(int(ship.ship_id))
	ids.sort()
	return ids

func _sorted_starbase_planet_ids() -> Array[int]:
	var ids: Array[int] = []
	for key: Variant in game_state.starbases_by_planet_id.keys():
		var planet_id: int = int(key)
		var p: PlanetData = _planet_by_id(planet_id)
		if planet_id > 0 and p != null and game_state.is_my_planet(p) and not game_state.get_starbase_for_planet(planet_id).is_empty():
			ids.append(planet_id)
	ids.sort()
	return ids

func _refresh_open_info_panel() -> void:
	if _ships_panel != null and _ships_panel.visible:
		_populate_ships_panel()
	if _starbases_panel != null and _starbases_panel.visible:
		_populate_starbases_panel()
	if _messages_panel != null and _messages_panel.visible:
		_populate_messages_panel()
	if _reports_panel != null and _reports_panel.visible:
		_populate_reports_panel()
	if _diplomacy_panel != null and _diplomacy_panel.visible:
		_populate_diplomacy_panel()

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
	if _messages_panel != null:
		_messages_panel.visible = false
	if _reports_panel != null:
		_reports_panel.visible = false
	if _diplomacy_panel != null:
		_diplomacy_panel.visible = false

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

func _ensure_messages_panel() -> void:
	if _messages_panel != null:
		return
	var parts: Dictionary = _create_info_panel("Messages")
	_messages_panel = parts["panel"] as PanelContainer
	_messages_list = parts["list"] as VBoxContainer

func _ensure_reports_panel() -> void:
	if _reports_panel != null:
		return
	var parts: Dictionary = _create_info_panel("Turn Reports")
	_reports_panel = parts["panel"] as PanelContainer
	_reports_list = parts["list"] as VBoxContainer

func _ensure_diplomacy_panel() -> void:
	if _diplomacy_panel != null:
		return
	var parts: Dictionary = _create_info_panel("Diplomacy")
	_diplomacy_panel = parts["panel"] as PanelContainer
	_diplomacy_list = parts["list"] as VBoxContainer

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

	_add_summary_label(_ships_list, "#%d  %s%s" % [ship.ship_id, ship.display_hull_name(), hidden_text])
	_add_wrapped_label(_ships_list, _player_owner_label(ship.ownerid), false).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not ship.name.strip_edges().is_empty() and ship.name != ship.display_hull_name():
		_add_wrapped_label(_ships_list, ship.name, false).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add_location_nav(_ships_list, "ship", ship.x, ship.y, int(ship.ship_id))

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
	_add_kv(orders, "Distance", "%.1f ly" % _ship_travel_distance(ship))
	_add_kv(orders, "Experience", str(_dict_int(ship.raw, ["experience"], 0)))
	_add_kv(orders, "Mission", _mission_label(_dict_int(ship.raw, ["mission"], 0), ship.ownerid))
	_add_kv(orders, "Enemy", _enemy_label(_dict_int(ship.raw, ["enemy"], 0)))
	_add_ship_fc_editor(orders, ship)

func _populate_starbases_panel() -> void:
	_clear_children(_starbases_list)
	var sb: Dictionary = game_state.get_selected_starbase()
	if sb.is_empty():
		_add_summary_label(_starbases_list, "No selection")
		return

	var planet_id: int = _dict_int(sb, ["planetid", "planet_id"], game_state.selected_starbase_planet_id)
	var p: PlanetData = _planet_by_id(planet_id)
	var can_build_ships: bool = _starbase_can_build_ships(p, sb)
	var base_type: String = _starbase_type_label(p, sb)
	_add_summary_label(_starbases_list, "#%d  %s - %s" % [planet_id, p.name if p != null else "Unknown", base_type])
	if p != null:
		_add_wrapped_label(_starbases_list, "%s  %.0f / %.0f" % [_player_owner_label(int(p.ownerid)), p.x, p.y], false).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_add_location_nav(_starbases_list, "starbase", p.x, p.y, -1)

	var base_defense: int = _dict_int(sb, ["defense", "defenseposts", "defense_posts"], 0)
	var base_fighters: int = _dict_int(sb, ["fighters", "fightercount", "fighter_count"], 0)
	var planet_defense: int = max(0, int(p.defense)) if p != null else 0
	var base_bays: int = 5 if can_build_ships else 0
	var defense_summary: Dictionary = PlanetMath.planet_defense_summary(
		planet_defense,
		base_defense,
		_dict_int(sb, ["massbonus", "mass_bonus"], 0),
		_dict_int(sb, ["beamtechlevel", "beamtech", "beamlevel"], 0),
		base_fighters,
		base_bays
	)

	_add_section_title(_starbases_list, "Defense")
	var defense: GridContainer = _add_key_value_grid(_starbases_list)
	_add_kv(defense, "Base Defense", str(base_defense))
	_add_kv(defense, "Planet Defense", str(planet_defense) if p != null else "?")
	_add_kv(defense, "Fighters", str(base_fighters))
	_add_kv(defense, "Combat Mass", "%d kt" % int(defense_summary.get("combat_mass", 0)))
	_add_kv(defense, "Beams", _weapon_count_name(int(defense_summary.get("beam_count", 0)), String(defense_summary.get("beam_name", "Beam"))))
	_add_kv(defense, "Bays", str(int(defense_summary.get("bays", 0))))
	if _dict_int(sb, ["damage"], 0) > 0:
		_add_kv(defense, "Damage", "%d%%" % _dict_int(sb, ["damage"], 0))

	_add_section_title(_starbases_list, "Shipyard / Resources")
	var shipyard: GridContainer = _add_key_value_grid(_starbases_list)
	if can_build_ships:
		_add_kv(shipyard, "Hull Tech", str(_dict_int(sb, ["hulltechlevel", "hulltech"], 0)))
		_add_kv(shipyard, "Engine Tech", str(_dict_int(sb, ["enginetechlevel", "enginetech"], 0)))
		_add_kv(shipyard, "Beam Tech", str(_dict_int(sb, ["beamtechlevel", "beamtech"], 0)))
		_add_kv(shipyard, "Torp Tech", str(_dict_int(sb, ["torptechlevel", "torptech"], 0)))
		_add_kv(shipyard, "Building", _starbase_build_label(sb))
	else:
		_add_kv(shipyard, "Shipyard", "not available")
	if p != null:
		_add_kv(shipyard, "Neutronium", _planet_amount(p.neutronium, "kt"))
		_add_kv(shipyard, "Duranium", _planet_amount(p.duranium, "kt"))
		_add_kv(shipyard, "Tritanium", _planet_amount(p.tritanium, "kt"))
		_add_kv(shipyard, "Molybdenum", _planet_amount(p.molybdenum, "kt"))
		_add_kv(shipyard, "Supplies", _planet_amount(p.supplies, ""))
		_add_kv(shipyard, "Megacredits", _planet_amount(p.megacredits, ""))

	_add_section_title(_starbases_list, "Orders")
	var orders: GridContainer = _add_key_value_grid(_starbases_list)
	_add_kv(orders, "Mission", _starbase_mission_label(_dict_int(sb, ["mission"], 0)))
	if p != null:
		_add_kv(orders, "Friendly Code", p.friendlycode)
	_add_kv(orders, "Repair Ship", _starbase_ship_order_target(sb, 1))
	_add_kv(orders, "Recycle Ship", _starbase_ship_order_target(sb, 2))

func _populate_messages_panel() -> void:
	_clear_children(_messages_list)

	var current_turn: int = game_state.get_current_turn()
	var player_messages: Array[Dictionary] = _filtered_player_messages(current_turn)
	if player_messages.is_empty():
		_add_summary_label(_messages_list, "No messages")
		return

	_add_summary_label(_messages_list, "%d messages for turn %d" % [player_messages.size(), current_turn])

	_add_section_title(_messages_list, "Player Messages / Diplomacy")
	for msg: Dictionary in player_messages:
		_add_message_entry(_messages_list, msg, true)

func _populate_reports_panel() -> void:
	_clear_children(_reports_list)

	var current_turn: int = game_state.get_current_turn()
	var turn_reports: Array[Dictionary] = _current_messages_from_rst("messages", current_turn)
	if turn_reports.is_empty():
		_add_summary_label(_reports_list, "No turn reports")
		return

	_add_summary_label(_reports_list, "%d reports for turn %d" % [turn_reports.size(), current_turn])
	for msg: Dictionary in turn_reports:
		_add_message_entry(_reports_list, msg, false)

func _populate_diplomacy_panel() -> void:
	_clear_children(_diplomacy_list)

	var relations: Array[Dictionary] = _relations_from_rst()
	if relations.is_empty():
		_add_summary_label(_diplomacy_list, "No diplomacy data")
		return

	_add_summary_label(_diplomacy_list, "Current relations")
	_add_wrapped_label(_diplomacy_list, _diplomacy_limit_summary(), false)
	for relation: Dictionary in relations:
		var player_id: int = _dict_int(relation, ["playertoid"], -1)
		if player_id <= 0 or player_id == int(game_state.my_player_id):
			continue
		var player: Dictionary = game_state.get_player_info(player_id)
		if int(player.get("status", 1)) == 3:
			continue
		_add_diplomacy_entry(_diplomacy_list, relation, player)

func _relations_from_rst() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if game_state.last_turn_json.is_empty():
		return result
	var rst_v: Variant = game_state.last_turn_json.get("rst")
	if not (rst_v is Dictionary):
		return result
	var rst: Dictionary = rst_v as Dictionary
	var rel_v: Variant = rst.get("relations", [])
	if not (rel_v is Array):
		return result
	for item: Variant in rel_v as Array:
		if item is Dictionary:
			result.append(item as Dictionary)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _dict_int(a, ["playertoid"], 0) < _dict_int(b, ["playertoid"], 0)
	)
	return result

func _add_diplomacy_entry(parent: VBoxContainer, relation: Dictionary, player: Dictionary) -> void:
	var relation_id: int = _dict_int(relation, ["id"], -1)
	var player_id: int = _dict_int(relation, ["playertoid"], -1)
	var relation_to: int = _dict_int(relation, ["relationto"], 0)
	var relation_from: int = _dict_int(relation, ["relationfrom"], 0)

	var title_row: HBoxContainer = HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_theme_constant_override("separation", 6)
	parent.add_child(title_row)

	var player_label: Label = Label.new()
	player_label.text = _message_party_label(player_id, true)
	player_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	player_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_label.add_theme_font_size_override("font_size", PANEL_BODY_FONT_SIZE)
	player_label.add_theme_color_override("font_color", _message_party_color(player_id, true))
	title_row.add_child(player_label)

	var state_label: Label = Label.new()
	state_label.text = _combined_relation_label(relation_to, relation_from)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	state_label.add_theme_font_size_override("font_size", PANEL_BODY_FONT_SIZE)
	state_label.add_theme_color_override("font_color", _relation_color(max(relation_to, relation_from)))
	title_row.add_child(state_label)

	var details: GridContainer = _add_key_value_grid(parent)
	_add_relation_editor(details, relation_id, player_id, relation_to)
	_add_colored_kv(details, "They give", _relation_label(relation_from), _relation_color(relation_from))
	var conflict_level: int = _dict_int(relation, ["conflictlevel"], 0)
	if conflict_level > 0:
		_add_colored_kv(details, "Conflict", str(conflict_level), Color(1.0, 0.48, 0.42, 1.0))
	_add_separator(parent)

func _add_relation_editor(parent: GridContainer, relation_id: int, player_id: int, current_value: int) -> void:
	var key_label: Label = Label.new()
	key_label.text = "We give"
	key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_label.add_theme_font_size_override("font_size", PANEL_BODY_FONT_SIZE)
	parent.add_child(key_label)

	var option: OptionButton = OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.add_theme_font_size_override("font_size", PANEL_BODY_FONT_SIZE)
	for value: int in [-1, 0, 1, 2, 3, 4]:
		option.add_item(_relation_label(value), value)
		var index: int = option.get_item_count() - 1
		option.set_item_metadata(index, value)
		var allowed: bool = _can_set_relation_level(player_id, current_value, value)
		option.set_item_disabled(index, not allowed)
		if value == current_value:
			option.select(index)
	option.item_selected.connect(func(index: int) -> void:
		var selected_value: int = int(option.get_item_metadata(index))
		if selected_value == current_value:
			return
		if not _can_set_relation_level(player_id, current_value, selected_value):
			_populate_diplomacy_panel()
			return
		if game_state.set_relation_to(relation_id, selected_value):
			_populate_diplomacy_panel()
	)
	parent.add_child(option)

func _diplomacy_limit_summary() -> String:
	var limits: Dictionary = _diplomacy_limits()
	var counts: Dictionary = _relation_counts_excluding(-1)
	return "Limits: Safe Passage %d/%d, Share Intel %d/%d, Alliances %d/%d" % [
		int(counts.get("safe", 0)),
		int(limits.get("safe", 0)),
		int(counts.get("intel", 0)),
		int(limits.get("intel", 0)),
		int(counts.get("ally", 0)),
		int(limits.get("ally", 0))
	]

func _can_set_relation_level(player_id: int, current_value: int, new_value: int) -> bool:
	if new_value == current_value:
		return true
	if new_value < -1 or new_value > 4:
		return false

	var game_info: Dictionary = _game_info_from_rst()
	if _dict_int(game_info, ["gametype"], 0) == 3:
		if new_value == 4:
			return false
		if current_value == 4:
			var player: Dictionary = game_state.get_player_info(player_id)
			if int(player.get("status", 1)) == 1:
				return false

	if new_value < 2:
		return true

	var limits: Dictionary = _diplomacy_limits()
	var counts: Dictionary = _relation_counts_excluding(player_id)
	if new_value == 4 and int(counts.get("ally", 0)) >= int(limits.get("ally", 0)):
		return false
	if new_value >= 3 and int(counts.get("intel", 0)) >= int(limits.get("intel", 0)):
		return false
	if new_value >= 2 and int(counts.get("safe", 0)) >= int(limits.get("safe", 0)):
		return false
	return true

func _relation_counts_excluding(excluded_player_id: int) -> Dictionary:
	var counts: Dictionary = {"safe": 0, "intel": 0, "ally": 0}
	for relation: Dictionary in _relations_from_rst():
		var player_id: int = _dict_int(relation, ["playertoid"], -1)
		if player_id <= 0 or player_id == int(game_state.my_player_id) or player_id == excluded_player_id:
			continue
		var relation_to: int = _dict_int(relation, ["relationto"], 0)
		if relation_to >= 4:
			counts["ally"] = int(counts["ally"]) + 1
		if relation_to >= 3:
			counts["intel"] = int(counts["intel"]) + 1
		if relation_to >= 2:
			counts["safe"] = int(counts["safe"]) + 1
	return counts

func _diplomacy_limits() -> Dictionary:
	var settings: Dictionary = _settings_from_rst()
	return {
		"safe": _dict_int(settings, ["maxsafepassage"], 99),
		"intel": _dict_int(settings, ["maxshareintel"], 99),
		"ally": _dict_int(settings, ["maxallies"], 99)
	}

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

func _game_info_from_rst() -> Dictionary:
	if game_state.last_turn_json.is_empty():
		return {}
	var rst_v: Variant = game_state.last_turn_json.get("rst")
	if not (rst_v is Dictionary):
		return {}
	var rst: Dictionary = rst_v as Dictionary
	var game_v: Variant = rst.get("game", {})
	if game_v is Dictionary:
		return game_v as Dictionary
	return {}

func _add_colored_kv(parent: GridContainer, key: String, value: String, color: Color) -> void:
	var key_label: Label = Label.new()
	key_label.text = key
	key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_label.add_theme_font_size_override("font_size", PANEL_BODY_FONT_SIZE)
	parent.add_child(key_label)

	var value_label: Label = Label.new()
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value_label.add_theme_font_size_override("font_size", PANEL_BODY_FONT_SIZE)
	value_label.add_theme_color_override("font_color", color)
	parent.add_child(value_label)

func _combined_relation_label(relation_to: int, relation_from: int) -> String:
	if relation_to == relation_from:
		match relation_to:
			-1:
				return "Communication blocked"
			0:
				return "None"
			1:
				return "Open communication"
			2:
				return "Peace agreement"
			3:
				return "Intelligence agreement"
			4:
				return "Full alliance"
			_:
				return "Relation %d" % relation_to
	return "Asymmetric"

func _relation_label(value: int) -> String:
	match value:
		-1:
			return "Blocked"
		0:
			return "None"
		1:
			return "Ambassador"
		2:
			return "Safe Passage"
		3:
			return "Share Intel"
		4:
			return "Full Alliance"
		_:
			return "Relation %d" % value

func _relation_color(value: int) -> Color:
	match value:
		-1:
			return Color(1.0, 0.34, 0.34, 1.0)
		0:
			return Color(0.68, 0.72, 0.74, 1.0)
		1:
			return Color(0.86, 0.82, 0.55, 1.0)
		2:
			return Color(0.62, 0.9, 0.58, 1.0)
		3:
			return Color(0.48, 0.78, 1.0, 1.0)
		4:
			return Color(0.72, 0.56, 1.0, 1.0)
		_:
			return Color(0.85, 0.9, 0.92, 1.0)

func _filtered_player_messages(current_turn: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var messages: Array[Dictionary] = _current_messages_from_rst("mymessages", current_turn)
	for msg: Dictionary in messages:
		var message_type: int = _dict_int(msg, ["messagetype"], 0)
		if message_type == 18:
			result.append(msg)
			continue
		if message_type == 17:
			result.append(msg)
	return result

func _current_messages_from_rst(key: String, current_turn: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if game_state.last_turn_json.is_empty():
		return result
	var rst_v: Variant = game_state.last_turn_json.get("rst")
	if not (rst_v is Dictionary):
		return result
	var rst: Dictionary = rst_v as Dictionary
	var arr_v: Variant = rst.get(key, [])
	if not (arr_v is Array):
		return result

	for item: Variant in arr_v as Array:
		if not (item is Dictionary):
			continue
		var msg: Dictionary = item as Dictionary
		if _dict_int(msg, ["turn"], current_turn) == current_turn:
			result.append(msg)

	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var turn_a: int = _dict_int(a, ["turn"], 0)
		var turn_b: int = _dict_int(b, ["turn"], 0)
		if turn_a != turn_b:
			return turn_a > turn_b
		return _dict_int(a, ["id"], 0) > _dict_int(b, ["id"], 0)
	)
	return result

func _add_message_entry(parent: VBoxContainer, msg: Dictionary, is_player_message: bool) -> void:
	var entry: VBoxContainer = VBoxContainer.new()
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.add_theme_constant_override("separation", 3)
	parent.add_child(entry)

	var header: HBoxContainer = HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 4)
	entry.add_child(header)

	var from_id: int = _message_from_id(msg, is_player_message)
	var to_id: int = _message_to_id(msg, is_player_message)
	_add_message_party_label(header, "From: " + _message_party_label(from_id, false), _message_party_color(from_id, false))
	_add_message_party_label(header, ">", Color(0.78, 0.86, 0.88, 1.0))
	_add_message_party_label(header, "To: " + _message_party_label(to_id, true), _message_party_color(to_id, true))

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var turn_label_msg: Label = Label.new()
	turn_label_msg.text = "T%d" % _dict_int(msg, ["turn"], game_state.get_current_turn())
	turn_label_msg.add_theme_font_size_override("font_size", PANEL_BODY_FONT_SIZE)
	turn_label_msg.add_theme_color_override("font_color", Color(0.72, 0.78, 0.8, 1.0))
	header.add_child(turn_label_msg)

	var headline: String = _dict_string(msg, ["headline", "title", "subject"], "").strip_edges()
	if not headline.is_empty():
		var headline_label: Label = _add_wrapped_label(entry, headline, true)
		headline_label.add_theme_font_size_override("font_size", PANEL_BODY_FONT_SIZE)

	var body: String = _message_body_text(_dict_string(msg, ["body", "message", "text"], ""))
	if body.is_empty():
		body = "-"
	_add_wrapped_label(entry, body, false)

	var coords: Vector2 = Vector2(float(msg.get("x", 0.0)), float(msg.get("y", 0.0)))
	if coords.x > 0.0 or coords.y > 0.0:
		var coords_label: Label = _add_wrapped_label(entry, "%.0f / %.0f" % [coords.x, coords.y], false)
		coords_label.add_theme_color_override("font_color", Color(0.58, 0.7, 0.76, 1.0))

	_add_separator(parent)

func _message_from_id(msg: Dictionary, is_player_message: bool) -> int:
	if not is_player_message:
		return 0
	var message_type: int = _dict_int(msg, ["messagetype"], 0)
	var owner_id: int = _dict_int(msg, ["ownerid", "fromid", "senderid"], -1)
	var target_id: int = _dict_int(msg, ["target", "toid", "recipientid"], -1)
	if message_type == 18 and owner_id == int(game_state.my_player_id) and target_id > 0:
		return target_id
	return owner_id

func _message_to_id(msg: Dictionary, is_player_message: bool) -> int:
	if not is_player_message:
		return _dict_int(msg, ["ownerid"], game_state.my_player_id)
	var message_type: int = _dict_int(msg, ["messagetype"], 0)
	var owner_id: int = _dict_int(msg, ["ownerid", "fromid", "senderid"], -1)
	var target_id: int = _dict_int(msg, ["target", "toid", "recipientid"], game_state.my_player_id)
	if message_type == 18 and owner_id == int(game_state.my_player_id):
		return owner_id
	return target_id

func _add_message_party_label(parent: HBoxContainer, text: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", PANEL_BODY_FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)

func _message_party_label(player_id: int, recipient: bool) -> String:
	if player_id <= 0:
		return "System" if not recipient else "Unknown"
	var info: Dictionary = game_state.get_player_info(player_id)
	var username: String = _dict_string(info, ["username"], "").strip_edges()
	var base: String = _player_owner_label(player_id)
	if not username.is_empty() and username != "dead":
		base += " (" + username + ")"
	if player_id == int(game_state.my_player_id):
		base = "Me: " + base
	return base

func _message_party_color(player_id: int, recipient: bool) -> Color:
	if player_id <= 0:
		return Color(0.74, 0.78, 0.82, 1.0) if recipient else Color(0.95, 0.78, 0.46, 1.0)
	var race_id: int = game_state.get_race_id_of_player(player_id)
	var color: Color = RandAI_Config.get_player_color(player_id, race_id)
	color.a = 1.0
	return color

func _message_body_text(raw: String) -> String:
	var text: String = raw.replace("\r", "")
	text = text.replace("<br/>", "\n")
	text = text.replace("<br />", "\n")
	text = text.replace("<br>", "\n")
	text = text.replace("&nbsp;", " ")
	text = text.replace("&amp;", "&")
	text = text.replace("&lt;", "<")
	text = text.replace("&gt;", ">")
	text = text.replace("&quot;", "\"")
	text = text.replace("&#39;", "'")
	while text.find("\n\n\n") >= 0:
		text = text.replace("\n\n\n", "\n\n")
	return text.strip_edges()

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
	key_label.add_theme_font_size_override("font_size", PANEL_BODY_FONT_SIZE)
	parent.add_child(key_label)

	var value_label: Label = Label.new()
	value_label.text = value if not value.is_empty() else "-"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value_label.add_theme_font_size_override("font_size", PANEL_BODY_FONT_SIZE)
	value_label.add_theme_color_override("font_color", Color(0.54, 1.0, 0.58, 1.0))
	parent.add_child(value_label)

func _add_ship_fc_editor(parent: GridContainer, ship: StarshipData) -> void:
	var key_label: Label = Label.new()
	key_label.text = "Friendly Code"
	key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_label.add_theme_font_size_override("font_size", PANEL_BODY_FONT_SIZE)
	parent.add_child(key_label)

	var edit: LineEdit = LineEdit.new()
	edit.max_length = 3
	edit.text = _dict_string(ship.raw, ["friendlycode", "friendly_code"], "")
	edit.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.custom_minimum_size = Vector2(58.0, 0.0)
	edit.add_theme_font_size_override("font_size", PANEL_BODY_FONT_SIZE)
	edit.add_theme_color_override("font_color", Color(0.54, 1.0, 0.58, 1.0))
	var editable: bool = game_state.is_my_ship(ship)
	edit.editable = editable
	edit.focus_mode = Control.FOCUS_ALL if editable else Control.FOCUS_NONE
	edit.modulate = Color.WHITE if editable else Color(0.6, 0.6, 0.6)
	edit.set_meta("fc_random_armed", true)
	var ship_id: int = int(ship.ship_id)
	edit.text_submitted.connect(func(_text: String) -> void:
		_commit_ship_fc_edit(ship_id, edit)
	)
	edit.focus_exited.connect(func() -> void:
		_commit_ship_fc_edit(ship_id, edit)
		if is_instance_valid(edit):
			edit.set_meta("fc_random_armed", true)
	)
	edit.gui_input.connect(func(event: InputEvent) -> void:
		_on_ship_fc_gui_input(event, ship_id, edit)
	)
	parent.add_child(edit)

func _normalize_fc(value: String) -> String:
	var s: String = value.strip_edges()
	if s.length() > 3:
		s = s.substr(0, 3)
	return s

func _commit_ship_fc_edit(ship_id: int, edit: LineEdit) -> void:
	var ship: StarshipData = _ship_by_id(ship_id)
	if ship == null or edit == null:
		return
	if not game_state.is_my_ship(ship):
		edit.text = _dict_string(ship.raw, ["friendlycode", "friendly_code"], "")
		return

	var fc: String = _normalize_fc(edit.text)
	edit.text = fc
	var current_fc: String = _dict_string(ship.raw, ["friendlycode", "friendly_code"], "")
	if fc == current_fc:
		return
	game_state.set_ship_friendlycode(ship_id, fc)

func _on_ship_fc_gui_input(event: InputEvent, ship_id: int, edit: LineEdit) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if edit == null or not bool(edit.get_meta("fc_random_armed", true)):
		return
	var ship: StarshipData = _ship_by_id(ship_id)
	if ship == null or not game_state.is_my_ship(ship):
		return

	var fc: String = _random_safe_ship_fc(ship)
	edit.set_meta("fc_random_armed", false)
	edit.text = fc
	game_state.set_ship_friendlycode(ship_id, fc)
	edit.grab_focus()
	edit.select_all()
	edit.accept_event()

func _random_safe_ship_fc(ship: StarshipData) -> String:
	if ship == null:
		return RandAI_Config.random_safe_fc()
	var race_id: int = game_state.get_race_id_of_player(int(ship.ownerid))
	if race_id == 3:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.randomize()
		var first_char: String = "X" if rng.randi_range(0, 1) == 0 else "x"
		return RandAI_Config.random_safe_fc(rng, first_char)
	return RandAI_Config.random_safe_fc()

func _add_location_nav(parent: VBoxContainer, current_kind: String, x: float, y: float, current_ship_id: int = -1) -> void:
	var p: PlanetData = _planet_at_position(x, y)
	var ships: Array[StarshipData] = _ships_at_position(x, y)
	var has_starbase: bool = p != null and not game_state.get_starbase_for_planet(int(p.planet_id)).is_empty()
	if p == null and not has_starbase and ships.size() <= 1:
		return

	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	if p != null:
		_add_location_nav_button(row, "Planet", current_kind == "planet", func() -> void:
			game_state.select_planet(int(p.planet_id))
		)

	if has_starbase:
		_add_location_nav_button(row, "Starbase", current_kind == "starbase", func() -> void:
			game_state.select_starbase(int(p.planet_id))
		)

	if ships.size() <= 0:
		return

	if current_kind == "ship":
		_add_ship_stack_nav_controls(row, ships, current_ship_id)
	else:
		var first_ship_id: int = int(ships[0].ship_id)
		var label: String = "Ship #%d" % first_ship_id if ships.size() == 1 else "Ships (%d)" % ships.size()
		_add_location_nav_button(row, label, false, func() -> void:
			game_state.select_ship(first_ship_id)
		)

func _add_location_nav_button(parent: HBoxContainer, text: String, disabled: bool, callback: Callable) -> void:
	var btn: Button = Button.new()
	btn.text = text
	btn.disabled = disabled
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", PANEL_BODY_FONT_SIZE)
	btn.pressed.connect(callback)
	parent.add_child(btn)

func _add_ship_stack_nav_controls(parent: HBoxContainer, stack: Array[StarshipData], current_ship_id: int) -> void:
	var index: int = _ship_stack_index(stack, current_ship_id)
	if index < 0:
		index = 0

	if stack.size() <= 1:
		_add_location_nav_button(parent, "Ship #%d" % int(stack[0].ship_id), true, func() -> void:
			pass
		)
		return

	var prev_btn: Button = Button.new()
	prev_btn.text = "<"
	prev_btn.custom_minimum_size = Vector2(34.0, 0.0)
	prev_btn.focus_mode = Control.FOCUS_NONE
	prev_btn.pressed.connect(func() -> void:
		var prev_index: int = (index - 1 + stack.size()) % stack.size()
		game_state.select_ship(int(stack[prev_index].ship_id))
	)
	parent.add_child(prev_btn)

	var label: Label = Label.new()
	label.text = "Ship %d / %d" % [index + 1, stack.size()]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", PANEL_BODY_FONT_SIZE)
	parent.add_child(label)

	var next_btn: Button = Button.new()
	next_btn.text = ">"
	next_btn.custom_minimum_size = Vector2(34.0, 0.0)
	next_btn.focus_mode = Control.FOCUS_NONE
	next_btn.pressed.connect(func() -> void:
		var next_index: int = (index + 1) % stack.size()
		game_state.select_ship(int(stack[next_index].ship_id))
	)
	parent.add_child(next_btn)

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
	else:
		label.add_theme_font_size_override("font_size", PANEL_BODY_FONT_SIZE)
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

func _planet_at_position(x: float, y: float) -> PlanetData:
	for p: PlanetData in game_state.planets:
		if p == null:
			continue
		if abs(p.x - x) <= 0.01 and abs(p.y - y) <= 0.01:
			return p
	return null

func _ship_by_id(ship_id: int) -> StarshipData:
	for ship: StarshipData in game_state.starships:
		if ship != null and int(ship.ship_id) == ship_id:
			return ship
	return null

func _ships_at_position(x: float, y: float) -> Array[StarshipData]:
	var result: Array[StarshipData] = []
	for ship: StarshipData in game_state.starships:
		if ship == null or ship.ishidden:
			continue
		if abs(ship.x - x) <= 0.01 and abs(ship.y - y) <= 0.01:
			result.append(ship)
	result.sort_custom(func(a: StarshipData, b: StarshipData) -> bool:
		return int(a.ship_id) < int(b.ship_id)
	)
	return result

func _starbase_type_label(p: PlanetData, sb: Dictionary) -> String:
	if _is_mining_station(p, sb):
		return "Mining Station"
	if _is_radiation_starbase(p, sb):
		return "Radiation Starbase"
	return "Starbase"

func _starbase_can_build_ships(p: PlanetData, sb: Dictionary) -> bool:
	return not _is_mining_station(p, sb)

func _is_mining_station(p: PlanetData, sb: Dictionary) -> bool:
	if _dict_int(sb, ["starbasetype"], 0) == 2:
		return true
	return p != null and p.debrisdisk > 0.0

func _is_radiation_starbase(p: PlanetData, sb: Dictionary) -> bool:
	if _dict_int(sb, ["starbasetype"], 0) == 1:
		return true
	return p != null and _is_in_starcluster_radiation_zone(p)

func _is_in_starcluster_radiation_zone(p: PlanetData) -> bool:
	for star: StarClusterData in game_state.starclusters:
		if star == null:
			continue
		var dist: float = Vector2(star.x, star.y).distance_to(Vector2(p.x, p.y))
		if dist > star.radius and dist <= sqrt(star.mass):
			return true
	return false

func _starbase_build_label(sb: Dictionary) -> String:
	if not bool(sb.get("isbuilding", false)):
		return "none"
	var hull_id: int = _dict_int(sb, ["buildhullid"], 0)
	if hull_id <= 0:
		return "none"
	var parts: PackedStringArray = PackedStringArray()
	parts.append(_hull_name(hull_id))
	var engine_id: int = _dict_int(sb, ["buildengineid"], 0)
	if engine_id > 0:
		parts.append(_engine_name(engine_id))
	var beam_count: int = _dict_int(sb, ["buildbeamcount"], 0)
	if beam_count > 0:
		parts.append("%d %s" % [beam_count, _beam_name(_dict_int(sb, ["buildbeamid"], 0))])
	var torp_count: int = _dict_int(sb, ["buildtorpcount"], 0)
	if torp_count > 0:
		parts.append("%d %s" % [torp_count, _torpedo_name(_dict_int(sb, ["buildtorpedoid"], 0))])
	return ", ".join(parts)

func _hull_name(hull_id: int) -> String:
	var hull: Dictionary = _hull_info(hull_id)
	var hname: String = _dict_string(hull, ["name"], "")
	if not hname.is_empty():
		return hname
	return "Hull %d" % hull_id

func _planet_amount(value: float, unit: String) -> String:
	if value < 0.0:
		return "?"
	if unit.is_empty():
		return str(int(value))
	return "%d %s" % [int(value), unit]

func _starbase_mission_label(mission_id: int) -> String:
	match mission_id:
		0:
			return "None"
		1:
			return "Refuel"
		2:
			return "Max Defense"
		3:
			return "Load Torpedoes"
		4:
			return "Unload Freighters"
		5:
			return "Repair Base"
		6:
			return "Force a Surrender"
		7:
			return "Send Fighters"
		8:
			return "Receive Fighters"
		9:
			return "Sweep Mines"
		_:
			return "Mission %d" % mission_id

func _starbase_ship_order_target(sb: Dictionary, expected_shipmission: int) -> String:
	var target_id: int = _dict_int(sb, ["targetshipid", "target_ship_id"], 0)
	var shipmission: int = _dict_int(sb, ["shipmission", "ship_mission"], 0)
	if target_id <= 0 or shipmission != expected_shipmission:
		return "none"
	return "#%d" % target_id

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

func _ship_stack_index(stack: Array[StarshipData], ship_id: int) -> int:
	for i: int in range(stack.size()):
		if int(stack[i].ship_id) == ship_id:
			return i
	return -1

func _ship_travel_distance(ship: StarshipData) -> float:
	var max_distance: float = ship.warp * ship.warp
	if max_distance <= 0.0:
		return 0.0
	if ship.has_target():
		var target_distance: float = Vector2(ship.x, ship.y).distance_to(Vector2(ship.targetx, ship.targety))
		if target_distance <= 0.0:
			return 0.0
		return min(max_distance, target_distance)
	if ship.heading >= 0.0:
		return max_distance
	return 0.0

func _weapon_count_name(count: int, wname: String) -> String:
	if count <= 0:
		return "none"
	return "%d %s" % [count, wname]

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

func _mission_label(mission_id: int, owner_id: int = 0) -> String:
	match mission_id:
		0:
			return "Exploration"
		1:
			return "Mine Sweep"
		2:
			return "Lay Mines"
		3:
			return "Kill"
		4:
			return "Sensor Sweep"
		5:
			return "Land and Disassemble"
		6:
			return "Try to Tow"
		7:
			return "Intercept"
		8:
			return _special_ship_mission_label(owner_id)
		9:
			return "Cloak"
		10:
			return "Beam Up Neutronium"
		11:
			return "Beam Up Duranium"
		12:
			return "Beam Up Tritanium"
		13:
			return "Beam Up Molybdenum"
		14:
			return "Beam Up Supplies"
		_:
			return "Mission %d" % mission_id

func _special_ship_mission_label(owner_id: int) -> String:
	var race_id: int = game_state.get_race_id_of_player(owner_id)
	match race_id:
		1:
			return "Super Refit"
		2:
			return "Hisssss!"
		3:
			return "Super Spy"
		4:
			return "Pillage Planet"
		5:
			return "Rob Ship"
		6:
			return "Self Repair"
		7:
			return "Lay Web Mines"
		8:
			return "Dark Sense"
		9:
			return "Build Fighters"
		10:
			return "Rebel Ground Attack"
		11:
			return "Build Fighters"
		_:
			return "Special Mission"

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
