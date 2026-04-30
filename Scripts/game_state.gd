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
var selected_planet_id: int = -1
var username: String = ""
var my_planets: Array[PlanetData] = []
var my_planets_by_id: Dictionary = {} # int -> PlanetData
var _batch_mode: bool = false
var _batch_dirty: bool = false
const API_KEY_FILE: String = "user://api_key.dat"
const API_KEY_PASS: String = "Jw95m+3*Mv$3x"
const Minefield_Data = preload("res://Scripts/Data/MinefieldData.gd")
const IonStorm_Data = preload("res://Scripts/Data/IonStormData.gd")
const Nebula_Data = preload("res://Scripts/Data/NebulaData.gd")
const StarCluster_Data = preload("res://Scripts/Data/StarClusterData.gd")
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
var current_turn: int = 0
var minefields: Array[Minefield_Data] = []
var starbase_planet_ids: Dictionary = {}
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
	minefields = turn_data_model.minefields
	ionstorms = turn_data_model.ionstorms
	starbase_planet_ids = turn_data_model.starbase_planet_ids
	nebulas = turn_data_model.nebulas
	starclusters = turn_data_model.starclusters
	rebuild_my_planets_cache()
	
	# Load static game config once (races, advantages, etc.)
	if config.races_by_id.is_empty():
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

	load_turn_from_parsed_wrapper(wrapper)
	return true

func select_planet(planet_id: int) -> void:
	selected_planet_id = planet_id
	emit_signal("selection_changed", "planet", planet_id)

func get_selected_planet() -> PlanetData:
	if selected_planet_id < 0:
		return null
	for p in planets:
		if p.planet_id == selected_planet_id:
			return p
	return null
	
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
	
func planet_has_starbase(planet_id: int) -> bool:
	return starbase_planet_ids.has(planet_id)
