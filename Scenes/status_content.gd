extends HBoxContainer

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
	_add_summary_label(_ships_list, "#%d  %s%s" % [ship.ship_id, ship.display_hull_name(), hidden_text])
	_add_separator(_ships_list)
	_add_wrapped_label(_ships_list, "Owner: %s" % _player_owner_label(ship.ownerid), false)
	_add_wrapped_label(_ships_list, "Position: %.0f / %.0f" % [ship.x, ship.y], false)
	_add_wrapped_label(_ships_list, "Warp: %.0f  Heading: %.0f" % [ship.warp, ship.heading], false)
	if ship.has_target():
		_add_wrapped_label(_ships_list, "Target: %.0f / %.0f" % [ship.targetx, ship.targety], false)
	if not ship.name.strip_edges().is_empty():
		_add_wrapped_label(_ships_list, "Name: %s" % ship.name, false)
	_add_wrapped_label(_ships_list, "Hull ID: %d" % ship.hullid, false)
	if not ship.raw.is_empty():
		_add_separator(_ships_list)
		_add_wrapped_label(_ships_list, "Fuel: %d  Damage: %d  Crew: %d" % [
			_dict_int(ship.raw, ["neutronium", "fuel"], 0),
			_dict_int(ship.raw, ["damage"], 0),
			_dict_int(ship.raw, ["crew"], 0)
		], false)
		_add_wrapped_label(_ships_list, "FC: %s  Mission: %d" % [
			_dict_string(ship.raw, ["friendlycode", "friendly_code"], ""),
			_dict_int(ship.raw, ["mission"], 0)
		], false)

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
