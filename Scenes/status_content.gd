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
const PANEL_BODY_FONT_SIZE: int = 13
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
var _status_controls_installed: bool = false

func _ready() -> void:
	_install_status_controls()
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
	var messages_button: Control = get_node_or_null("%MessagesButton") as Control
	if messages_button != null:
		_add_status_separator_after(messages_button.get_index())

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
	var ship_id: int = int(ship.ship_id)
	edit.text_submitted.connect(func(_text: String) -> void:
		_commit_ship_fc_edit(ship_id, edit)
	)
	edit.focus_exited.connect(func() -> void:
		_commit_ship_fc_edit(ship_id, edit)
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
	if edit == null or edit.has_focus():
		return
	var ship: StarshipData = _ship_by_id(ship_id)
	if ship == null or not game_state.is_my_ship(ship):
		return

	var fc: String = RandAI_Config.random_safe_fc()
	edit.text = fc
	game_state.set_ship_friendlycode(ship_id, fc)
	edit.grab_focus()
	edit.select_all()
	edit.accept_event()

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
	label.add_theme_font_size_override("font_size", PANEL_BODY_FONT_SIZE)
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

func _ship_by_id(ship_id: int) -> StarshipData:
	for ship: StarshipData in game_state.starships:
		if ship != null and int(ship.ship_id) == ship_id:
			return ship
	return null

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
	var name: String = _dict_string(hull, ["name"], "")
	if not name.is_empty():
		return name
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
