extends Node

# -------------------------
# Konfiguration (vorerst fest)
# -------------------------
const Turn_Data = preload("res://Scripts/Data/TurnData.gd")
signal selection_changed(selected_kind: String, selected_id: int)
const Game_Config = preload("res://Scripts/Data/GameConfig.gd")
signal turn_loaded
signal orders_changed
signal game_changed(game_id: int)
var config: Game_Config = Game_Config.new()
var current_game_id: int = 0
var my_player_id: int = -1   # wird aus rst.player.id gesetzt
var my_race_id: int = 0          # später aus rst.player.raceid ziehen
var selection_mode: String = "planet"
var selected_planet_id: int = -1
var selected_ship_id: int = -1
var selected_starbase_planet_id: int = -1
var username: String = ""
var my_planets: Array[PlanetData] = []
var my_planets_by_id: Dictionary = {} # int -> PlanetData
var planet_start_state_by_id: Dictionary = {}
var _batch_mode: bool = false
var _batch_dirty: bool = false
const API_KEY_FILE: String = "user://api_key.dat"
const API_KEY_PASS: String = "Jw95m+3*Mv$3x"
const Minefield_Data = preload("res://Scripts/Data/MinefieldData.gd")
const IonStorm_Data = preload("res://Scripts/Data/IonStormData.gd")
const Nebula_Data = preload("res://Scripts/Data/NebulaData.gd")
const StarCluster_Data = preload("res://Scripts/Data/StarClusterData.gd")
const Starship_Data = preload("res://Scripts/Data/StarshipData.gd")
# -------------------------
# Laufzeitdaten
# -------------------------
var api_key: String = ""
var last_turn_json: Dictionary = {}
var turn_data_model: Turn_Data = null
var map_min_x: float
var map_max_x: float
var map_min_y: float
var map_max_y: float
var planets: Array = []
var starships: Array[Starship_Data] = []
var current_turn: int = 0
var minefields: Array[Minefield_Data] = []
var starbase_planet_ids: Dictionary = {}
var starbases_by_planet_id: Dictionary = {}
var ionstorms: Array[IonStorm_Data] = []
var nebulas: Array[Nebula_Data] = []
var starclusters: Array[StarCluster_Data] = []
# -------------------------
# Programmstart
# -------------------------
func _ready() -> void:
	load_api_credentials()
	
	# -------------------------
# Turn-Datei prüfen
# -------------------------
func _process_loaded_turn(parsed: Dictionary) -> void:
	last_turn_json = parsed
	# parsed: Dictionary = Root wrapper
	my_player_id = -1
	my_race_id = 0
	
	if not parsed.has("rst"):
		push_error("Turn wrapper JSON has no 'rst' section")
		return
	var rst_v: Variant = parsed.get("rst")
	if not (rst_v is Dictionary):
		push_error("'rst' is not a Dictionary")
	var rst: Dictionary = rst_v as Dictionary
	# my_player_id aus rst.player.id
	if rst.has("player"):
		var pl_v: Variant = rst.get("player")
		if pl_v is Dictionary:
			var pl: Dictionary = pl_v as Dictionary
			var id_v: Variant = pl.get("id")
			if typeof(id_v) == TYPE_INT:
				my_player_id = int(id_v)
			elif typeof(id_v) == TYPE_FLOAT:
				my_player_id = int(float(id_v))

			var race_v: Variant = pl.get("raceid")
			if typeof(race_v) == TYPE_INT or typeof(race_v) == TYPE_FLOAT:
				my_race_id = int(race_v)

			#var pid_v: Variant = pl.get("id")
			#if typeof(pid_v) == TYPE_INT or typeof(pid_v) == TYPE_FLOAT:
			#	my_race_id = int(race_v)

	if not rst.has("game"):
		push_error("'rst' has no 'game' section")
	var game_v: Variant = rst.get("game")
	if not (game_v is Dictionary):
		push_error("'rst.game' is not a Dictionary")

	var game: Dictionary = game_v as Dictionary

	var t_v: Variant = game.get("turn")
	if typeof(t_v) == TYPE_INT or typeof(t_v) == TYPE_FLOAT:
		current_turn = int(t_v)
		
	else:
		push_error("'rst.game.turn' is not numeric")
	if current_game_id > 0:
		RandAI_Config.set_current_game(current_game_id)
	build_turn_model(parsed["rst"])
	planets = turn_data_model.planets
	starships = turn_data_model.starships
	minefields = turn_data_model.minefields
	ionstorms = turn_data_model.ionstorms
	starbase_planet_ids = turn_data_model.starbase_planet_ids
	starbases_by_planet_id = turn_data_model.starbases_by_planet_id
	nebulas = turn_data_model.nebulas
	starclusters = turn_data_model.starclusters
	rebuild_my_planets_cache()
	rebuild_planet_start_state_cache()
	annotate_minefield_friendly_codes(rst)
	
	config.load_from_turn_json(parsed)
		
	calculate_map_bounds()
	emit_signal("turn_loaded")

# -------------------------
# Turn laden
# -------------------------

func save_turn(wrapper: Dictionary) -> void:
	if current_game_id <= 0:
		push_error("GameState.save_turn: no current_game_id set")
		return

	GameStorage.ensure_game_dir(current_game_id)

	# nur latest speichern (Turn-spezifische Datei optional später)
	GameStorage.save_json(GameStorage.latest_turn_path(current_game_id), wrapper)

	load_turn_from_parsed_wrapper(wrapper)

func extract_turn_from_wrapper(wrapper: Dictionary) -> int:
	if not wrapper.has("rst"):
		return 0
	var rst_v: Variant = wrapper.get("rst")
	if not (rst_v is Dictionary):
		return 0
	var rst: Dictionary = rst_v as Dictionary
	if not rst.has("game"):
		return 0
	var game_v: Variant = rst.get("game")
	if not (game_v is Dictionary):
		return 0
	var game: Dictionary = game_v as Dictionary
	var t_v: Variant = game.get("turn")
	if typeof(t_v) == TYPE_INT or typeof(t_v) == TYPE_FLOAT:
		return int(t_v)
	return 0

# -------------------------
# Turn-Datenmodell aufbauen
# -------------------------
func build_turn_model(parsed: Dictionary) -> void:
	turn_data_model = Turn_Data.new()
	turn_data_model.load_from_turn(parsed)

func load_turn_from_parsed_wrapper(wrapper: Dictionary) -> void:
	# wrapper top keys: success, rst, savekey, ...
	_process_loaded_turn(wrapper)

func calculate_map_bounds() -> void:
	
	if planets.is_empty():
		return

	map_min_x = planets[0].x
	map_max_x = planets[0].x
	map_min_y = planets[0].y
	map_max_y = planets[0].y

	for p in planets:
		map_min_x = min(map_min_x, p.x)
		map_max_x = max(map_max_x, p.x)
		map_min_y = min(map_min_y, p.y)
		map_max_y = max(map_max_y, p.y)

func load_latest_turn_from_disk() -> bool:
	if current_game_id <= 0:
		return false

	var path: String = GameStorage.latest_turn_path(current_game_id)
	var wrapper: Dictionary = GameStorage.load_json(path)
	if wrapper.is_empty():
		return false
	if not wrapper.has("rst") or not (wrapper.get("rst") is Dictionary):
		push_warning("Ignoring invalid local turn without rst: " + path)
		return false

	load_turn_from_parsed_wrapper(wrapper)
	return true

func select_planet(planet_id: int) -> void:
	selection_mode = "planet"
	selected_planet_id = planet_id
	selected_ship_id = -1
	selected_starbase_planet_id = -1
	emit_signal("selection_changed", "planet", planet_id)

func clear_selection() -> void:
	selected_planet_id = -1
	selected_ship_id = -1
	selected_starbase_planet_id = -1
	emit_signal("selection_changed", "none", -1)

func set_selection_mode(mode: String) -> void:
	if mode != "planet" and mode != "ship" and mode != "starbase":
		mode = "planet"
	selection_mode = mode

func get_selection_mode() -> String:
	return selection_mode

func clear_selection_for_kind(kind: String) -> void:
	match kind:
		"planet":
			selected_planet_id = -1
		"ship":
			selected_ship_id = -1
		"starbase":
			selected_starbase_planet_id = -1
		_:
			clear_selection()
			return
	emit_signal("selection_changed", kind, -1)

func select_ship(ship_id: int) -> void:
	selection_mode = "ship"
	selected_planet_id = -1
	selected_ship_id = ship_id
	selected_starbase_planet_id = -1
	emit_signal("selection_changed", "ship", ship_id)

func select_starbase(planet_id: int) -> void:
	selection_mode = "starbase"
	selected_planet_id = -1
	selected_ship_id = -1
	selected_starbase_planet_id = planet_id
	emit_signal("selection_changed", "starbase", planet_id)

func get_selected_planet() -> PlanetData:
	if selected_planet_id < 0:
		return null
	for p in planets:
		if p.planet_id == selected_planet_id:
			return p
	return null

func get_selected_ship() -> StarshipData:
	if selected_ship_id < 0:
		return null
	for ship: StarshipData in starships:
		if ship != null and int(ship.ship_id) == selected_ship_id:
			return ship
	return null

func get_selected_starbase() -> Dictionary:
	if selected_starbase_planet_id < 0:
		return {}
	return get_starbase_for_planet(selected_starbase_planet_id)
	
func get_effective_native_taxrate(p: PlanetData) -> int:
	return int(p.nativetaxrate)

func get_effective_colonist_taxrate(p: PlanetData) -> int:
	return int(p.colonisttaxrate)

func get_current_turn() -> int:
	return current_turn

func get_game_id() -> int:
	return current_game_id

func get_owner_race_id() -> int:
	return my_race_id  # oder current_player_id wenn du wirklich player slot meinst

func get_owner_race_id_of_planet(p: PlanetData) -> int:
	if p.ownerid <= 0:
		return -1

	# last_turn_json ist der Wrapper; players liegen in rst.players
	if last_turn_json.is_empty():
		return -1

	var rst_v: Variant = last_turn_json.get("rst")
	if not (rst_v is Dictionary):
		return -1
	var rst: Dictionary = rst_v as Dictionary

	var players_v: Variant = rst.get("players")
	if not (players_v is Array):
		return -1
	var players: Array = players_v as Array

	for it in players:
		if it is Dictionary:
			var d: Dictionary = it as Dictionary
			var id_v: Variant = d.get("id", -1)
			var pid: int = int(id_v) if typeof(id_v) == TYPE_INT else int(float(id_v))
			if pid == p.ownerid:
				var race_v: Variant = d.get("raceid", -1)
				if typeof(race_v) == TYPE_INT or typeof(race_v) == TYPE_FLOAT:
					return int(race_v)

	return -1

func get_all_planets() -> Array:
	return planets

func get_my_planets() -> Array[PlanetData]:
	return my_planets

func load_api_credentials() -> void:
	if not FileAccess.file_exists(API_KEY_FILE):
		return
	var f: FileAccess = FileAccess.open_encrypted_with_pass(
		API_KEY_FILE,
		FileAccess.READ,
		API_KEY_PASS
	)
	if f == null:
		push_error("Cannot open " + API_KEY_FILE)
		return
	var text: String = f.get_as_text()
	f.close()

	var v: Variant = JSON.parse_string(text)
	if not (v is Dictionary):
		push_error("Invalid api_key.json")
		return

	var d: Dictionary = v as Dictionary
	var ak_v: Variant = d.get("api_key", "")
	if typeof(ak_v) == TYPE_STRING:
		api_key = String(ak_v)

	var un_v: Variant = d.get("username", "")
	if typeof(un_v) == TYPE_STRING:
		username = String(un_v)

func save_api_credentials(new_username: String, new_api_key: String) -> void:
	username = new_username
	api_key = new_api_key

	var d: Dictionary = {"username": username, "api_key": api_key}
	var f: FileAccess = FileAccess.open_encrypted_with_pass(
		API_KEY_FILE,
		FileAccess.WRITE,
		API_KEY_PASS
	)
	if f == null:
		push_error("Cannot write " + API_KEY_FILE)
		return
	f.store_string(JSON.stringify(d))
	f.close()

func set_current_game(game_id: int) -> void:
	current_game_id = game_id
	#my_player_id = player_id
	GameStorage.ensure_game_dir(game_id)
	Orders_Store.load_for_game(game_id)
	# Config pro Spiel laden
	RandAI_Config.set_current_game(game_id)
	emit_signal("game_changed", game_id)
	
func get_my_race_id() -> int:
	return my_race_id

func is_my_planet(p: PlanetData) -> bool:
	if p == null:
		return false
	if my_player_id <= 0:
		return false

	var oid_v: Variant = p.ownerid
	if oid_v == null:
		return false

	var oid: int
	if typeof(oid_v) == TYPE_INT:
		oid = int(oid_v)
	elif typeof(oid_v) == TYPE_FLOAT:
		oid = int(float(oid_v))
	else:
		return false

	return oid == my_player_id

func is_my_ship(ship: StarshipData) -> bool:
	if ship == null:
		return false
	if my_player_id <= 0:
		return false
	return int(ship.ownerid) == my_player_id

func set_planet_colonist_taxrate(planet_id: int, tax: int) -> void:
	var v: int = clamp(tax, 0, 100)

	# 1) Wrapper patchen
	_set_planet_field_in_rst(planet_id, "colonisttaxrate", v)

	# 2) Model patchen
	_set_planet_taxrate_in_model(planet_id, false, v)
	if _batch_mode:
		_batch_dirty = true
	else:
		_save_latest_turn_json()
		emit_signal("orders_changed")
		
func set_planet_native_taxrate(planet_id: int, tax: int) -> void:
	var v: int = clamp(tax, 0, 100)
	_set_planet_field_in_rst(planet_id, "nativetaxrate", v)
	_set_planet_taxrate_in_model(planet_id, true, v)
	if _batch_mode:
		_batch_dirty = true
	else:
		_save_latest_turn_json()
		emit_signal("orders_changed")

func set_planet_building_counts(
	planet_id: int,
	mines_count: int,
	factories_count: int,
	defense_count: int
) -> bool:
	var p: PlanetData = my_planets_by_id.get(planet_id, null)
	if p == null:
		push_error("Planet not found for building update: " + str(planet_id))
		return false

	var start: Dictionary = get_planet_start_state(planet_id)
	if start.is_empty():
		push_error("No building start state for planet: " + str(planet_id))
		return false

	var start_mines: int = int(start.get("mines", 0))
	var start_factories: int = int(start.get("factories", 0))
	var start_defense: int = int(start.get("defense", 0))

	var max_mines_v: int = Planet_Math.max_mines(p)
	var max_factories_v: int = Planet_Math.max_factories(p)
	var max_defense_v: int = Planet_Math.max_defense(p)
	if max_mines_v < start_mines:
		max_mines_v = start_mines
	if max_factories_v < start_factories:
		max_factories_v = start_factories
	if max_defense_v < start_defense:
		max_defense_v = start_defense

	var new_mines: int = clamp(mines_count, start_mines, max_mines_v)
	var new_factories: int = clamp(factories_count, start_factories, max_factories_v)
	var new_defense: int = clamp(defense_count, start_defense, max_defense_v)

	var build_mines: int = new_mines - start_mines
	var build_factories: int = new_factories - start_factories
	var build_defense: int = new_defense - start_defense

	var needed_supplies: int = build_mines + build_factories + build_defense
	var needed_mc: int = build_mines * PlanetMath.MINE_COST_MC \
		+ build_factories * PlanetMath.FACTORY_COST_MC \
		+ build_defense * PlanetMath.DEFENSE_COST_MC

	var start_mc: int = int(start.get("megacredits", 0))
	var start_supplies: int = int(start.get("supplies", 0))
	var start_supplies_sold: int = int(start.get("suppliessold", 0))

	if needed_supplies > start_supplies:
		return false

	var supplies_after_build: int = start_supplies - needed_supplies
	var supplies_to_sell: int = max(needed_mc - start_mc, 0)
	if supplies_to_sell > 0 and not bool(RandAI_Config.auto_sell_supplies):
		return false
	if supplies_to_sell > supplies_after_build:
		return false

	var final_mc: int = start_mc + supplies_to_sell - needed_mc
	var final_supplies: int = supplies_after_build - supplies_to_sell
	var final_supplies_sold: int = start_supplies_sold + supplies_to_sell

	_set_planet_field_in_rst(planet_id, "mines", new_mines)
	_set_planet_field_in_rst(planet_id, "factories", new_factories)
	_set_planet_field_in_rst(planet_id, "defense", new_defense)
	_set_planet_field_in_rst(planet_id, "megacredits", final_mc)
	_set_planet_field_in_rst(planet_id, "supplies", final_supplies)
	_set_planet_field_in_rst(planet_id, "suppliessold", final_supplies_sold)

	p.mines = float(new_mines)
	p.factories = float(new_factories)
	p.defense = float(new_defense)
	p.megacredits = float(final_mc)
	p.supplies = float(final_supplies)

	if _batch_mode:
		_batch_dirty = true
	else:
		_save_latest_turn_json()
		emit_signal("orders_changed")

	return true

func set_planet_building_targets(
	planet_id: int,
	target_mines: int = -1,
	target_factories: int = -1,
	target_defense: int = -1
) -> bool:
	var changed: bool = false

	for p: PlanetData in planets:
		if p == null or int(p.planet_id) != planet_id:
			continue

		if target_mines >= 0 and int(p.raw.get("targetmines", -1)) != target_mines:
			_set_planet_field_in_rst(planet_id, "targetmines", target_mines)
			p.raw["targetmines"] = target_mines
			p.targetmines = float(target_mines)
			changed = true

		if target_factories >= 0 and int(p.raw.get("targetfactories", -1)) != target_factories:
			_set_planet_field_in_rst(planet_id, "targetfactories", target_factories)
			p.raw["targetfactories"] = target_factories
			p.targetfactories = float(target_factories)
			changed = true

		if target_defense >= 0 and int(p.raw.get("targetdefense", -1)) != target_defense:
			_set_planet_field_in_rst(planet_id, "targetdefense", target_defense)
			p.raw["targetdefense"] = target_defense
			p.targetdefense = float(target_defense)
			changed = true

		break

	if not changed:
		return false

	if _batch_mode:
		_batch_dirty = true
	else:
		_save_latest_turn_json()
		emit_signal("orders_changed")

	return true
		
func _set_planet_taxrate_in_model(planet_id: int, is_native: bool, value: int) -> void:
	for p in planets:
		if int(p.planet_id) == planet_id:
			
			if is_native:
				p.nativetaxrate = value
			else:
				p.colonisttaxrate = value

			return
	push_error("Planet not found in model for tax update: " + str(planet_id))

func _save_latest_turn_json() -> void:
	if current_game_id <= 0:
		return
	if last_turn_json.is_empty():
		return

	GameStorage.ensure_game_dir(current_game_id)
	GameStorage.save_json(GameStorage.latest_turn_path(current_game_id), last_turn_json)

func rebuild_my_planets_cache() -> void:
	my_planets.clear()
	my_planets_by_id.clear()

	if my_player_id < 0:
		return

	for p in planets:
		if int(p.ownerid) == my_player_id:
			my_planets.append(p)
			my_planets_by_id[int(p.planet_id)] = p

func rebuild_planet_start_state_cache() -> void:
	planet_start_state_by_id.clear()

	for p in planets:
		if p == null:
			continue
		planet_start_state_by_id[int(p.planet_id)] = {
			"mines": int(p.mines),
			"factories": int(p.factories),
			"defense": int(p.defense),
			"megacredits": int(p.megacredits),
			"supplies": int(p.supplies),
			"suppliessold": int(p.raw.get("suppliessold", 0)),
			"neutronium": int(p.neutronium),
			"duranium": int(p.duranium),
			"tritanium": int(p.tritanium),
			"molybdenum": int(p.molybdenum)
		}

func annotate_minefield_friendly_codes(rst: Dictionary) -> void:
	for mf: MinefieldData in minefields:
		if mf == null:
			continue
		_reset_minefield_fc_annotations(mf)
		if mf.isweb:
			continue
		var nearest_owner_planet: PlanetData = _nearest_planet_owned_by(int(mf.ownerid), Vector2(mf.x, mf.y))
		if nearest_owner_planet != null:
			mf.fc_planet_id = int(nearest_owner_planet.planet_id)
			mf.fc_planet_name = nearest_owner_planet.name
			mf.resolved_friendlycode = String(nearest_owner_planet.friendlycode)

	_annotate_safe_passage_fc_reports(rst)

func _reset_minefield_fc_annotations(mf: MinefieldData) -> void:
	mf.fc_planet_id = -1
	mf.fc_planet_name = ""
	mf.resolved_friendlycode = ""
	mf.suspected_passage_fc = ""
	mf.suspected_passage_ship_id = -1
	mf.suspected_passage_planet_id = -1
	mf.suspected_passage_planet_name = ""
	mf.suspected_passage_from_report = false

func _annotate_safe_passage_fc_reports(rst: Dictionary) -> void:
	var messages_v: Variant = rst.get("messages", [])
	if not (messages_v is Array):
		return
	for item: Variant in messages_v as Array:
		if not (item is Dictionary):
			continue
		var msg: Dictionary = item as Dictionary
		if int(float(msg.get("messagetype", 0))) != 19:
			continue
		if int(float(msg.get("turn", current_turn))) != current_turn:
			continue
		var body: String = String(msg.get("body", ""))
		if body.find("has granted us safe passage") < 0:
			continue
		var minefield_id: int = int(float(msg.get("target", -1)))
		var mf: MinefieldData = _minefield_by_id(minefield_id)
		if mf == null or mf.isweb:
			continue
		if _relation_from_player(int(mf.ownerid)) >= 2:
			continue
		var ship_id: int = _ship_id_from_message_headline(String(msg.get("headline", "")))
		var ship: StarshipData = _ship_by_id(ship_id)
		if ship == null:
			continue
		var ship_fc: String = String(ship.raw.get("friendlycode", "")).strip_edges()
		if ship_fc.is_empty():
			continue
		mf.suspected_passage_from_report = true
		mf.suspected_passage_ship_id = ship_id
		mf.suspected_passage_fc = ship_fc
		mf.suspected_passage_planet_id = mf.fc_planet_id
		mf.suspected_passage_planet_name = mf.fc_planet_name

func _minefield_by_id(minefield_id: int) -> MinefieldData:
	for mf: MinefieldData in minefields:
		if mf != null and int(mf.minefield_id) == minefield_id:
			return mf
	return null

func _ship_by_id(ship_id: int) -> StarshipData:
	if ship_id <= 0:
		return null
	for ship: StarshipData in starships:
		if ship != null and int(ship.ship_id) == ship_id:
			return ship
	return null

func _ship_id_from_message_headline(headline: String) -> int:
	var re: RegEx = RegEx.new()
	if re.compile("ID#(\\d+)") != OK:
		return -1
	var m: RegExMatch = re.search(headline)
	if m == null:
		return -1
	return int(m.get_string(1))

func _nearest_planet_owned_by(owner_id: int, pos: Vector2) -> PlanetData:
	if owner_id <= 0:
		return null
	var best: PlanetData = null
	var best_dist2: float = INF
	for p: PlanetData in planets:
		if p == null or int(p.ownerid) != owner_id:
			continue
		var d2: float = Vector2(p.x, p.y).distance_squared_to(pos)
		if d2 < best_dist2:
			best_dist2 = d2
			best = p
	return best

func _relation_from_player(player_id: int) -> int:
	if player_id <= 0 or last_turn_json.is_empty():
		return 0
	var rst_v: Variant = last_turn_json.get("rst")
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
		if int(float(relation.get("playertoid", -1))) == player_id:
			return int(float(relation.get("relationfrom", 0)))
	return 0

func get_planet_start_state(planet_id: int) -> Dictionary:
	return planet_start_state_by_id.get(planet_id, {})
func has_api_credentials() -> bool:
	return not api_key.is_empty()

func clear_api_credentials() -> void:
	api_key = ""
	username = ""

	# Datei löschen
	var abs_path: String = ProjectSettings.globalize_path(API_KEY_FILE)
	if FileAccess.file_exists(API_KEY_FILE):
		var err: Error = DirAccess.remove_absolute(abs_path)
		if err != OK:
			push_error("Failed to delete api_key.json: " + str(err))

func _set_planet_field_in_rst(planet_id: int, key: String, value: Variant) -> void:
	if last_turn_json.is_empty():
		push_error("GameState: last_turn_json empty, cannot patch rst")
		return

	var rst_v: Variant = last_turn_json.get("rst")
	if not (rst_v is Dictionary):
		push_error("GameState: last_turn_json has no rst Dictionary")
		return
	var rst: Dictionary = rst_v as Dictionary

	var planets_v: Variant = rst.get("planets")
	if not (planets_v is Array):
		push_error("GameState: rst.planets is not an Array")
		return
	var arr: Array = planets_v as Array

	for i in range(arr.size()):
		var it: Variant = arr[i]
		if not (it is Dictionary):
			continue
		var pd: Dictionary = it as Dictionary

		var id_v: Variant = pd.get("id", -1)
		var pid: int = -1
		if typeof(id_v) == TYPE_INT:
			pid = int(id_v)
		elif typeof(id_v) == TYPE_FLOAT:
			pid = int(float(id_v))

		if pid == planet_id:
			pd[key] = value
			arr[i] = pd
			rst["planets"] = arr
			last_turn_json["rst"] = rst
			return

	push_error("GameState: planet id not found in rst.planets: " + str(planet_id))

func _set_ship_field_in_rst(ship_id: int, key: String, value: Variant) -> void:
	if last_turn_json.is_empty():
		push_error("GameState: last_turn_json empty, cannot patch rst")
		return

	var rst_v: Variant = last_turn_json.get("rst")
	if not (rst_v is Dictionary):
		push_error("GameState: last_turn_json has no rst Dictionary")
		return
	var rst: Dictionary = rst_v as Dictionary

	var ships_v: Variant = rst.get("ships")
	if not (ships_v is Array):
		push_error("GameState: rst.ships is not an Array")
		return
	var arr: Array = ships_v as Array

	for i in range(arr.size()):
		var it: Variant = arr[i]
		if not (it is Dictionary):
			continue
		var sd: Dictionary = it as Dictionary

		var id_v: Variant = sd.get("id", -1)
		var sid: int = -1
		if typeof(id_v) == TYPE_INT:
			sid = int(id_v)
		elif typeof(id_v) == TYPE_FLOAT:
			sid = int(float(id_v))

		if sid == ship_id:
			sd[key] = value
			arr[i] = sd
			rst["ships"] = arr
			last_turn_json["rst"] = rst
			return

	push_error("GameState: ship id not found in rst.ships: " + str(ship_id))

func _set_starbase_field_in_rst(planet_id: int, key: String, value: Variant) -> void:
	if last_turn_json.is_empty():
		push_error("GameState: last_turn_json empty, cannot patch rst")
		return

	var rst_v: Variant = last_turn_json.get("rst")
	if not (rst_v is Dictionary):
		push_error("GameState: last_turn_json has no rst Dictionary")
		return
	var rst: Dictionary = rst_v as Dictionary

	var starbases_v: Variant = rst.get("starbases")
	if not (starbases_v is Array):
		push_error("GameState: rst.starbases is not an Array")
		return
	var arr: Array = starbases_v as Array

	for i: int in range(arr.size()):
		var it: Variant = arr[i]
		if not (it is Dictionary):
			continue
		var sb: Dictionary = it as Dictionary
		var pid: int = int(float(sb.get("planetid", -1)))
		if pid == planet_id:
			sb[key] = value
			arr[i] = sb
			rst["starbases"] = arr
			last_turn_json["rst"] = rst
			return

	push_error("GameState: starbase planet id not found in rst.starbases: " + str(planet_id))

func set_planet_friendlycode(planet_id: int, fc: String) -> void:
	var s: String = fc.strip_edges()
	if s.length() > 3:
		s = s.substr(0, 3)

	# 1) RST wrapper patchen
	_set_planet_field_in_rst(planet_id, "friendlycode", s)

	# 2) Model patchen
	for p in planets:
		if int(p.planet_id) == planet_id:
			p.friendlycode = s
			break

	if _batch_mode:
		_batch_dirty = true
	else:
		_save_latest_turn_json()
		emit_signal("orders_changed")

func set_ship_friendlycode(ship_id: int, fc: String) -> void:
	var s: String = fc.strip_edges()
	if s.length() > 3:
		s = s.substr(0, 3)

	_set_ship_field_in_rst(ship_id, "friendlycode", s)

	for ship: StarshipData in starships:
		if ship != null and int(ship.ship_id) == ship_id:
			ship.raw["friendlycode"] = s
			break

	if _batch_mode:
		_batch_dirty = true
	else:
		_save_latest_turn_json()
		emit_signal("orders_changed")

func set_ship_name(ship_id: int, ship_name: String) -> bool:
	if ship_id <= 0:
		return false
	var s: String = ship_name.strip_edges()

	var found: bool = false
	var current_name: String = ""
	for ship: StarshipData in starships:
		if ship != null and int(ship.ship_id) == ship_id:
			current_name = ship.name
			found = true
			break
	if not found or current_name == s:
		return false

	_set_ship_field_in_rst(ship_id, "name", s)

	for ship: StarshipData in starships:
		if ship != null and int(ship.ship_id) == ship_id:
			ship.name = s
			ship.raw["name"] = s
			break

	if _batch_mode:
		_batch_dirty = true
	else:
		_save_latest_turn_json()
		emit_signal("orders_changed")
	return true

func set_ship_waypoint(ship_id: int, target_x: float, target_y: float) -> bool:
	if ship_id <= 0:
		return false

	var found: bool = false
	var rounded_x: float = float(int(round(target_x)))
	var rounded_y: float = float(int(round(target_y)))
	for ship: StarshipData in starships:
		if ship != null and int(ship.ship_id) == ship_id:
			if not is_my_ship(ship):
				return false
			found = true
			if is_equal_approx(ship.targetx, rounded_x) and is_equal_approx(ship.targety, rounded_y):
				return false
			ship.targetx = rounded_x
			ship.targety = rounded_y
			ship.raw["targetx"] = rounded_x
			ship.raw["targety"] = rounded_y
			break
	if not found:
		return false

	_set_ship_field_in_rst(ship_id, "targetx", rounded_x)
	_set_ship_field_in_rst(ship_id, "targety", rounded_y)

	if _batch_mode:
		_batch_dirty = true
	else:
		_save_latest_turn_json()
		emit_signal("orders_changed")
	return true

func set_ship_warp(ship_id: int, warp: int) -> bool:
	if ship_id <= 0:
		return false

	var value: int = clampi(warp, 0, 9)
	var found: bool = false
	for ship: StarshipData in starships:
		if ship != null and int(ship.ship_id) == ship_id:
			if not is_my_ship(ship):
				return false
			found = true
			if int(round(ship.warp)) == value:
				return false
			ship.warp = float(value)
			ship.raw["warp"] = value
			break
	if not found:
		return false

	_set_ship_field_in_rst(ship_id, "warp", value)

	if _batch_mode:
		_batch_dirty = true
	else:
		_save_latest_turn_json()
		emit_signal("orders_changed")
	return true

func set_ship_enemy(ship_id: int, enemy_id: int) -> bool:
	if ship_id <= 0 or enemy_id < 0:
		return false

	var current_enemy: int = -1
	var found: bool = false
	for ship: StarshipData in starships:
		if ship != null and int(ship.ship_id) == ship_id:
			current_enemy = int(float(ship.raw.get("enemy", 0)))
			found = true
			break
	if not found or current_enemy == enemy_id:
		return false

	_set_ship_field_in_rst(ship_id, "enemy", enemy_id)

	for ship: StarshipData in starships:
		if ship != null and int(ship.ship_id) == ship_id:
			ship.raw["enemy"] = enemy_id
			break

	if _batch_mode:
		_batch_dirty = true
	else:
		_save_latest_turn_json()
		emit_signal("orders_changed")
	return true

func set_ship_mission(ship_id: int, mission_id: int, mission1target: int = 0, mission2target: int = 0) -> bool:
	if ship_id <= 0 or mission_id < 0:
		return false

	var found: bool = false
	var current_mission: int = -1
	var current_target: int = -1
	var current_target2: int = -1
	for ship: StarshipData in starships:
		if ship != null and int(ship.ship_id) == ship_id:
			current_mission = int(float(ship.raw.get("mission", 0)))
			current_target = int(float(ship.raw.get("mission1target", 0)))
			current_target2 = int(float(ship.raw.get("mission2target", 0)))
			found = true
			break
	if not found:
		return false
	if current_mission == mission_id and current_target == mission1target and current_target2 == mission2target:
		return false

	_set_ship_field_in_rst(ship_id, "mission", mission_id)
	_set_ship_field_in_rst(ship_id, "mission1target", mission1target)
	_set_ship_field_in_rst(ship_id, "mission2target", mission2target)

	for ship: StarshipData in starships:
		if ship != null and int(ship.ship_id) == ship_id:
			ship.raw["mission"] = mission_id
			ship.raw["mission1target"] = mission1target
			ship.raw["mission2target"] = mission2target
			break

	if _batch_mode:
		_batch_dirty = true
	else:
		_save_latest_turn_json()
		emit_signal("orders_changed")
	return true

func set_ship_mission_target(ship_id: int, mission1target: int) -> bool:
	if ship_id <= 0 or mission1target < 0:
		return false

	var found: bool = false
	var current_target: int = -1
	for ship: StarshipData in starships:
		if ship != null and int(ship.ship_id) == ship_id:
			current_target = int(float(ship.raw.get("mission1target", 0)))
			found = true
			break
	if not found or current_target == mission1target:
		return false

	_set_ship_field_in_rst(ship_id, "mission1target", mission1target)

	for ship: StarshipData in starships:
		if ship != null and int(ship.ship_id) == ship_id:
			ship.raw["mission1target"] = mission1target
			break

	if _batch_mode:
		_batch_dirty = true
	else:
		_save_latest_turn_json()
		emit_signal("orders_changed")
	return true

func set_relation_to(relation_id: int, relation_to: int) -> bool:
	if relation_to < -1 or relation_to > 4:
		return false
	if last_turn_json.is_empty():
		return false

	var rst_v: Variant = last_turn_json.get("rst")
	if not (rst_v is Dictionary):
		return false
	var rst: Dictionary = rst_v as Dictionary
	var relations_v: Variant = rst.get("relations")
	if not (relations_v is Array):
		return false
	var relations: Array = relations_v as Array

	for i: int in range(relations.size()):
		var item: Variant = relations[i]
		if not (item is Dictionary):
			continue
		var relation: Dictionary = item as Dictionary
		var rid: int = int(float(relation.get("id", -1)))
		if rid != relation_id:
			continue
		if int(float(relation.get("relationto", 0))) == relation_to:
			return false
		relation["relationto"] = relation_to
		relations[i] = relation
		rst["relations"] = relations
		last_turn_json["rst"] = rst

		if _batch_mode:
			_batch_dirty = true
		else:
			_save_latest_turn_json()
			emit_signal("orders_changed")
		return true

	return false

func set_starbase_mission(planet_id: int, mission_id: int) -> bool:
	if planet_id <= 0 or mission_id < 0:
		return false
	if not starbases_by_planet_id.has(planet_id):
		return false

	var current_v: Variant = starbases_by_planet_id[planet_id]
	if not (current_v is Dictionary):
		return false
	var sb: Dictionary = current_v as Dictionary
	if int(float(sb.get("mission", 0))) == mission_id:
		return false

	sb["mission"] = mission_id
	starbases_by_planet_id[planet_id] = sb
	_set_starbase_field_in_rst(planet_id, "mission", mission_id)

	if _batch_mode:
		_batch_dirty = true
	else:
		_save_latest_turn_json()
		emit_signal("orders_changed")
	return true

func set_starbase_ship_order(planet_id: int, shipmission: int, target_ship_id: int) -> bool:
	if planet_id <= 0:
		return false
	if shipmission != 0 and shipmission != 1 and shipmission != 2:
		return false
	if shipmission == 0 or target_ship_id <= 0:
		shipmission = 0
		target_ship_id = 0
	if not starbases_by_planet_id.has(planet_id):
		return false

	var current_v: Variant = starbases_by_planet_id[planet_id]
	if not (current_v is Dictionary):
		return false
	var sb: Dictionary = current_v as Dictionary
	var current_shipmission: int = int(float(sb.get("shipmission", 0)))
	var current_target: int = int(float(sb.get("targetshipid", 0)))
	if current_shipmission == shipmission and current_target == target_ship_id:
		return false

	sb["shipmission"] = shipmission
	sb["targetshipid"] = target_ship_id
	starbases_by_planet_id[planet_id] = sb
	_set_starbase_field_in_rst(planet_id, "shipmission", shipmission)
	_set_starbase_field_in_rst(planet_id, "targetshipid", target_ship_id)

	if _batch_mode:
		_batch_dirty = true
	else:
		_save_latest_turn_json()
		emit_signal("orders_changed")
	return true

func set_starbase_tech_level(planet_id: int, tech_kind: String, target_level: int) -> bool:
	if planet_id <= 0:
		return false
	if not starbases_by_planet_id.has(planet_id):
		return false

	var field_names: Dictionary = _starbase_tech_field_names(tech_kind)
	if field_names.is_empty():
		return false

	var current_v: Variant = starbases_by_planet_id[planet_id]
	if not (current_v is Dictionary):
		return false
	var sb: Dictionary = current_v as Dictionary

	var level_key: String = String(field_names.get("level", ""))
	var up_key: String = String(field_names.get("up", ""))
	var current_level: int = int(float(sb.get(level_key, 1)))
	var current_up: int = int(float(sb.get(up_key, 0)))
	var original_level: int = clamp(current_level - current_up, 1, 10)
	var next_level: int = clamp(target_level, original_level, 10)
	if next_level == current_level:
		return false

	var p: PlanetData = _planet_by_id(planet_id)
	if p == null or not is_my_planet(p):
		return false

	var max_level: int = _starbase_max_tech_level_for_planet(p)
	if next_level > max_level and next_level > current_level:
		return false

	var mc_delta: int = _starbase_tech_mc_delta(current_level, next_level)
	var current_mc: int = int(p.megacredits)
	if not _can_pay_mc_with_supplies(p, mc_delta):
		return false

	_apply_planet_resource_delta(planet_id, p, -mc_delta, 0, 0, 0, 0, true)
	var final_up: int = next_level - original_level

	sb[level_key] = next_level
	sb[up_key] = final_up
	starbases_by_planet_id[planet_id] = sb
	_set_starbase_field_in_rst(planet_id, level_key, next_level)
	_set_starbase_field_in_rst(planet_id, up_key, final_up)

	if _batch_mode:
		_batch_dirty = true
	else:
		_save_latest_turn_json()
		emit_signal("orders_changed")
	return true

func set_starbase_defense_posts(planet_id: int, target_defense: int) -> bool:
	var sb: Dictionary = get_starbase_for_planet(planet_id)
	var p: PlanetData = _planet_by_id(planet_id)
	if sb.is_empty() or p == null or not is_my_planet(p):
		return false

	var current: int = int(float(sb.get("defense", 0)))
	var built: int = int(float(sb.get("builtdefense", 0)))
	var original: int = max(0, current - built)
	var max_value: int = _starbase_max_defense_posts(sb)
	var next_value: int = clamp(target_defense, original, max_value)
	var change: int = next_value - current
	if change == 0:
		return false

	if change > 0:
		if int(p.duranium) < change:
			return false
		if not _can_pay_mc_with_supplies(p, change * 10):
			return false

	_apply_planet_resource_delta(planet_id, p, -change * 10, 0, -change, 0, 0, true)
	sb["defense"] = next_value
	sb["builtdefense"] = built + change
	starbases_by_planet_id[planet_id] = sb
	_set_starbase_field_in_rst(planet_id, "defense", next_value)
	_set_starbase_field_in_rst(planet_id, "builtdefense", built + change)
	_commit_order_change()
	return true

func set_starbase_fighters(planet_id: int, target_fighters: int) -> bool:
	var sb: Dictionary = get_starbase_for_planet(planet_id)
	var p: PlanetData = _planet_by_id(planet_id)
	if sb.is_empty() or p == null or not is_my_planet(p):
		return false

	var current: int = int(float(sb.get("fighters", 0)))
	var built: int = int(float(sb.get("builtfighters", 0)))
	var original: int = max(0, current - built)
	var max_value: int = _starbase_max_fighters(sb)
	var next_value: int = clamp(target_fighters, original, max_value)
	var change: int = next_value - current
	if change == 0:
		return false

	if change > 0:
		if int(p.tritanium) < change * 3 or int(p.molybdenum) < change * 2:
			return false
		if not _can_pay_mc_with_supplies(p, change * 100):
			return false

	_apply_planet_resource_delta(planet_id, p, -change * 100, 0, 0, -change * 3, -change * 2, true)
	sb["fighters"] = next_value
	sb["builtfighters"] = built + change
	starbases_by_planet_id[planet_id] = sb
	_set_starbase_field_in_rst(planet_id, "fighters", next_value)
	_set_starbase_field_in_rst(planet_id, "builtfighters", built + change)
	_commit_order_change()
	return true

func set_starbase_torpedo_stock(planet_id: int, torpedo_id: int, target_amount: int) -> bool:
	if torpedo_id <= 0:
		return false
	var sb: Dictionary = get_starbase_for_planet(planet_id)
	var p: PlanetData = _planet_by_id(planet_id)
	if sb.is_empty() or p == null or not is_my_planet(p):
		return false

	var starbase_id: int = int(float(sb.get("id", 0)))
	var stock: Dictionary = get_starbase_stock_item(starbase_id, 5, torpedo_id)
	if stock.is_empty():
		return false

	var torp_info: Dictionary = _torpedo_info(torpedo_id)
	if torp_info.is_empty():
		return false
	var tech_level: int = int(float(torp_info.get("techlevel", 0)))
	if tech_level > int(float(sb.get("torptechlevel", 0))):
		return false
	var torp_cost: int = int(float(torp_info.get("torpedocost", torp_info.get("cost", 0))))

	var current: int = int(float(stock.get("amount", 0)))
	var built: int = int(float(stock.get("builtamount", 0)))
	var original: int = max(0, current - built)
	var next_value: int = max(target_amount, original)
	var change: int = next_value - current
	if change == 0:
		return false

	if change > 0:
		if int(p.duranium) < change or int(p.tritanium) < change or int(p.molybdenum) < change:
			return false
		if not _can_pay_mc_with_supplies(p, change * torp_cost):
			return false

	_apply_planet_resource_delta(planet_id, p, -change * torp_cost, 0, -change, -change, -change, true)
	_set_stock_amounts(int(stock.get("id", 0)), next_value, built + change)
	_commit_order_change()
	return true

func _starbase_max_defense_posts(sb: Dictionary) -> int:
	match int(float(sb.get("starbasetype", 0))):
		1:
			return 250
		2:
			return 50
		_:
			return 200

func _starbase_max_fighters(sb: Dictionary) -> int:
	match int(float(sb.get("starbasetype", 0))):
		1:
			return 80
		2:
			return 20
		_:
			return 60

func _can_pay_mc_with_supplies(p: PlanetData, mc_needed: int) -> bool:
	if mc_needed <= 0:
		return true
	var missing_mc: int = mc_needed - int(p.megacredits)
	if missing_mc <= 0:
		return true
	if not bool(RandAI_Config.auto_sell_supplies):
		return false
	return int(p.supplies) >= missing_mc

func _apply_planet_resource_delta(
	planet_id: int,
	p: PlanetData,
	mc_delta: int,
	supplies_delta: int,
	duranium_delta: int,
	tritanium_delta: int,
	molybdenum_delta: int,
	allow_supply_sale: bool
) -> void:
	var final_mc: int = int(p.megacredits) + mc_delta
	var final_supplies: int = int(p.supplies) + supplies_delta
	var final_supplies_sold: int = int(p.raw.get("suppliessold", 0))
	var start: Dictionary = get_planet_start_state(planet_id)
	var start_supplies_sold: int = int(start.get("suppliessold", final_supplies_sold))
	if allow_supply_sale and final_mc < 0 and bool(RandAI_Config.auto_sell_supplies):
		var sell_amount: int = min(-final_mc, final_supplies)
		final_mc += sell_amount
		final_supplies -= sell_amount
		final_supplies_sold += sell_amount
	elif allow_supply_sale and final_mc > 0 and final_supplies_sold > start_supplies_sold:
		var buyback_amount: int = min(final_mc, final_supplies_sold - start_supplies_sold)
		final_mc -= buyback_amount
		final_supplies += buyback_amount
		final_supplies_sold -= buyback_amount

	p.megacredits = float(final_mc)
	p.supplies = float(final_supplies)
	p.duranium = float(int(p.duranium) + duranium_delta)
	p.tritanium = float(int(p.tritanium) + tritanium_delta)
	p.molybdenum = float(int(p.molybdenum) + molybdenum_delta)
	p.raw["megacredits"] = final_mc
	p.raw["supplies"] = final_supplies
	p.raw["suppliessold"] = final_supplies_sold
	p.raw["duranium"] = int(p.duranium)
	p.raw["tritanium"] = int(p.tritanium)
	p.raw["molybdenum"] = int(p.molybdenum)
	_set_planet_field_in_rst(planet_id, "megacredits", final_mc)
	_set_planet_field_in_rst(planet_id, "supplies", final_supplies)
	_set_planet_field_in_rst(planet_id, "suppliessold", final_supplies_sold)
	_set_planet_field_in_rst(planet_id, "duranium", int(p.duranium))
	_set_planet_field_in_rst(planet_id, "tritanium", int(p.tritanium))
	_set_planet_field_in_rst(planet_id, "molybdenum", int(p.molybdenum))

func get_starbase_stock_item(starbase_id: int, stock_type: int, stock_id: int) -> Dictionary:
	var rst_v: Variant = last_turn_json.get("rst", {})
	if not (rst_v is Dictionary):
		return {}
	var stock_v: Variant = (rst_v as Dictionary).get("stock", [])
	if not (stock_v is Array):
		return {}
	for item: Variant in stock_v as Array:
		if not (item is Dictionary):
			continue
		var stock: Dictionary = item as Dictionary
		if int(float(stock.get("starbaseid", -1))) == starbase_id \
			and int(float(stock.get("stocktype", -1))) == stock_type \
			and int(float(stock.get("stockid", -1))) == stock_id:
			return stock
	return {}

func _set_stock_amounts(stock_entry_id: int, amount: int, built_amount: int) -> void:
	var rst_v: Variant = last_turn_json.get("rst", {})
	if not (rst_v is Dictionary):
		return
	var rst: Dictionary = rst_v as Dictionary
	var stock_v: Variant = rst.get("stock", [])
	if not (stock_v is Array):
		return
	var stock_arr: Array = stock_v as Array
	for i: int in range(stock_arr.size()):
		var item: Variant = stock_arr[i]
		if not (item is Dictionary):
			continue
		var stock: Dictionary = item as Dictionary
		if int(float(stock.get("id", -1))) != stock_entry_id:
			continue
		stock["amount"] = amount
		stock["builtamount"] = built_amount
		stock["changed"] = 1
		stock_arr[i] = stock
		rst["stock"] = stock_arr
		last_turn_json["rst"] = rst
		return

func _torpedo_info(torpedo_id: int) -> Dictionary:
	var rst_v: Variant = last_turn_json.get("rst", {})
	if not (rst_v is Dictionary):
		return {}
	var torps_v: Variant = (rst_v as Dictionary).get("torpedos", [])
	if not (torps_v is Array):
		return {}
	for item: Variant in torps_v as Array:
		if item is Dictionary and int(float((item as Dictionary).get("id", -1))) == torpedo_id:
			return item as Dictionary
	return {}

func _commit_order_change() -> void:
	if _batch_mode:
		_batch_dirty = true
	else:
		_save_latest_turn_json()
		emit_signal("orders_changed")

func _starbase_tech_field_names(tech_kind: String) -> Dictionary:
	match tech_kind.to_lower():
		"hull":
			return {"level": "hulltechlevel", "up": "hulltechup"}
		"engine":
			return {"level": "enginetechlevel", "up": "enginetechup"}
		"beam":
			return {"level": "beamtechlevel", "up": "beamtechup"}
		"torp":
			return {"level": "torptechlevel", "up": "torptechup"}
		_:
			return {}

func _starbase_tech_mc_delta(current_level: int, target_level: int) -> int:
	var delta: int = 0
	if target_level > current_level:
		for level: int in range(current_level, target_level):
			delta += level * 100
	elif target_level < current_level:
		for level: int in range(target_level, current_level):
			delta -= level * 100
	return delta

func _starbase_max_tech_level_for_planet(p: PlanetData) -> int:
	if _is_my_player_premium() or (p != null and int(p.flag) == 1):
		return 10
	return 7

func _is_my_player_premium() -> bool:
	for key: String in ["ispremium", "is_premium", "premium", "isregistered"]:
		if _dict_bool_value(last_turn_json.get(key, false)):
			return true

	var player: Dictionary = get_player_info(my_player_id)
	if player.is_empty():
		var rst_v: Variant = last_turn_json.get("rst", {})
		if rst_v is Dictionary:
			var player_v: Variant = (rst_v as Dictionary).get("player", {})
			if player_v is Dictionary:
				player = player_v as Dictionary
	for key: String in ["isregistered", "ispremium", "is_premium", "premium"]:
		if _dict_bool_value(player.get(key, false)):
			return true
	return false

func _dict_bool_value(value: Variant) -> bool:
	if typeof(value) == TYPE_BOOL:
		return bool(value)
	if typeof(value) == TYPE_INT:
		return int(value) != 0
	if typeof(value) == TYPE_FLOAT:
		return not is_zero_approx(float(value))
	var text: String = String(value).strip_edges().to_lower()
	return text == "true" or text == "yes" or text == "1"

func _planet_by_id(planet_id: int) -> PlanetData:
	for p: PlanetData in planets:
		if p != null and int(p.planet_id) == planet_id:
			return p
	return null

func begin_batch_changes() -> void:
	_batch_mode = true
	_batch_dirty = false

func end_batch_changes() -> void:
	_batch_mode = false
	if _batch_dirty:
		_save_latest_turn_json()
		emit_signal("orders_changed")
	_batch_dirty = false

func get_race_id_of_player(player_id: int) -> int:
	if player_id <= 0:
		return -1

	if last_turn_json.is_empty():
		return -1

	var rst_v: Variant = last_turn_json.get("rst")
	if not (rst_v is Dictionary):
		return -1
	var rst: Dictionary = rst_v as Dictionary

	var players_v: Variant = rst.get("players")
	if not (players_v is Array):
		return -1
	var players: Array = players_v as Array

	for it: Variant in players:
		if it is Dictionary:
			var d: Dictionary = it as Dictionary
			var id_v: Variant = d.get("id", -1)
			var pid: int = int(id_v) if typeof(id_v) == TYPE_INT else int(float(id_v))
			if pid == player_id:
				var race_v: Variant = d.get("raceid", -1)
				if typeof(race_v) == TYPE_INT or typeof(race_v) == TYPE_FLOAT:
					return int(race_v)

	return -1

func get_players() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if last_turn_json.is_empty():
		return result

	var rst_v: Variant = last_turn_json.get("rst")
	if not (rst_v is Dictionary):
		return result
	var rst: Dictionary = rst_v as Dictionary

	var players_v: Variant = rst.get("players")
	if not (players_v is Array):
		return result

	for it: Variant in players_v as Array:
		if it is Dictionary:
			result.append(it as Dictionary)

	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("id", 0)) < int(b.get("id", 0))
	)
	return result

func get_player_info(player_id: int) -> Dictionary:
	for p: Dictionary in get_players():
		if int(p.get("id", -1)) == player_id:
			return p
	return {}
	
func planet_has_starbase(planet_id: int) -> bool:
	return starbase_planet_ids.has(planet_id)

func get_starbase_for_planet(planet_id: int) -> Dictionary:
	if not starbases_by_planet_id.has(planet_id):
		return {}
	var value: Variant = starbases_by_planet_id[planet_id]
	if value is Dictionary:
		return value as Dictionary
	return {}
