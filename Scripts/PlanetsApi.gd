extends Node

# =========================
# PlanetsApi.gd
# Godot 4.5.1 Mono
# =========================

signal login_success
signal login_failed(reason: String)
signal turn_downloaded(turn_data: Dictionary)
signal turn_download_failed(reason: String)
signal games_listed(games: Array[Dictionary])
signal games_list_failed(reason: String)
signal save_success(response: Dictionary)
signal save_failed(reason: String)
var _pending_save_game_id: int = 0
var _pending_save_player_id: int = 0
var _pending_save_forsave: bool = false
var _pending_username: String = ""
var _pending_save_rst: Dictionary = {}
var api_key: String = ""
var current_request: RequestType = RequestType.NONE
@onready var http: HTTPRequest = HTTPRequest.new()

enum RequestType { NONE, LOGIN, LOAD_TURN, SAVE_TURN, LIST_GAMES}
# =========================
# READY
# =========================
func _ready() -> void:
	add_child(http)
	http.request_completed.connect(_on_request_completed)
	if not GameState.api_key.is_empty():
		api_key = GameState.api_key
# =========================
# ERROR HANDLING
# =========================
func _handle_error(reason: String, request_type: int = -1) -> void:
	var req: int = current_request if request_type < 0 else request_type
	match req:
		RequestType.LOGIN:
			emit_signal("login_failed", reason)
		RequestType.LOAD_TURN:
			emit_signal("turn_download_failed", reason)
		RequestType.LIST_GAMES:
			emit_signal("games_list_failed", reason)
		RequestType.SAVE_TURN:
			emit_signal("save_failed", reason)

# =========================
# LOGIN RESPONSE
# =========================
func _handle_login_response(data: Dictionary) -> void:
	if data.has("success") and data["success"] == true and data.has("apikey"):
		api_key = data["apikey"]
		GameState.save_api_credentials(_pending_username, api_key)
		emit_signal("login_success")

	else:
		var reason: String = "Login failed"
		if data.has("error"):
			reason = str(data["error"])
		emit_signal("login_failed", reason)

# =========================
# TURN RESPONSE
# =========================
func _handle_turn_response(data: Dictionary) -> void:
	if _pending_save_forsave:
		_pending_save_forsave = false
		_save_turn_with_savekey_and_merge(data)
		return

	GameState.save_turn(data)
	emit_signal("turn_downloaded", data)
# =========================
# LOGIN
# =========================
func login(username: String, password: String) -> void:
	_pending_username = username
	
	var url: String = (
		"http://api.planets.nu/account/login"
		+ "?username=" + username.uri_encode()
		+ "&password=" + password.uri_encode()
	)

	current_request = RequestType.LOGIN

	var err: int = http.request(url)
	if err != OK:
		_handle_error("HTTPRequest error: " + str(err))

# =========================
# TURN DOWNLOAD
# =========================
func download_turn(game_id: int, player_id, forsave: bool = false) -> void:
	# lazy inject
	if api_key.is_empty() and not GameState.api_key.is_empty():
		api_key = GameState.api_key
	
	if api_key.is_empty():
		_handle_error("No API key – login required")
		return

	var url: String = (
		"https://api.planets.nu/game/loadturn"
		+ "?gameid=" + str(game_id)
		)
		
	if player_id > 0:
		url += "&playerid=" + str(player_id)
	url += "&apikey=" + api_key.uri_encode()
	if forsave:
		url += "&forsave=true"

	_pending_save_forsave = forsave
	current_request = RequestType.LOAD_TURN

	var err: int = http.request(url)
	if err != OK:
		_handle_error("HTTPRequest error: " + str(err))
# =========================
# HTTP CALLBACK
# =========================
func _on_request_completed(result: int, response_code: int,_headers: PackedStringArray, body: PackedByteArray) -> void:
	var finished_request: RequestType = current_request
	current_request = RequestType.NONE  # <<< SOFORT resetten

	var text: String = body.get_string_from_utf8()
	
	if response_code != 200:
		_handle_error("HTTP " + str(response_code), finished_request)
		return

	var data_v: Variant = JSON.parse_string(text)
	if data_v == null:
		_handle_error("Invalid JSON (parse_string returned null)", finished_request)
		return

	match finished_request:
		RequestType.LOGIN:
			if data_v is Dictionary:
				_handle_login_response(data_v as Dictionary)
			else:
				_handle_error("Invalid JSON (LOGIN expected Dictionary)", finished_request)

		RequestType.LOAD_TURN:
			if data_v is Dictionary:
				_handle_turn_response(data_v as Dictionary)
			else:
				_handle_error("Invalid JSON (LOAD_TURN expected Dictionary)", finished_request)
		
		RequestType.SAVE_TURN:
			if data_v is Dictionary:
				var d: Dictionary = data_v as Dictionary
				if d.get("success", false) == true:
					emit_signal("save_success", d)
				else:
					var reason: String = String(d.get("error", "Save failed"))
					emit_signal("save_failed", reason)
			else:
				_handle_error("Invalid JSON (SAVE_TURN expected Dictionary)", finished_request)
				
		RequestType.LIST_GAMES:
			if data_v is Array:
				var arr: Array = data_v as Array
				var out: Array[Dictionary] = []
				for it in arr:
					if it is Dictionary:
						out.append(it as Dictionary)
				emit_signal("games_listed", out)
			else:
				_handle_error("Invalid JSON (LIST_GAMES expected Array)", finished_request)

		_:
			# NONE oder unbekannt
			print("Ignored response: no pending request type")

func list_games() -> void:
	var un: String = GameState.username
	if un.is_empty():
		_handle_error("No username stored – login required")
		return
	list_games_for_username(un) 
	
func list_games_for_username(username: String) -> void:
	var url: String = (
		"http://api.planets.nu/games/list"
		+ "?username=" + username.uri_encode()
		+ "&scope=0,1")
	current_request = RequestType.LIST_GAMES
	var err: int = http.request(url)
	if err != OK:
		_handle_error("HTTPRequest error: " + str(err))

func save_turn(wrapper: Dictionary, game_id: int, player_id: int) -> void:
	if api_key.is_empty():
		_handle_error("No API key")
		return
	if game_id <= 0:
		_handle_error("Invalid game_id")
		return
	if not wrapper.has("rst"):
		_handle_error("Wrapper has no rst")
		return

	var rst_v: Variant = wrapper["rst"]
	if not (rst_v is Dictionary):
		_handle_error("Wrapper rst is not a Dictionary")
		return
	_pending_save_game_id = game_id
	_pending_save_player_id = player_id
	_pending_save_rst = rst_v as Dictionary
	_pending_save_forsave = true

	# Nur frischen savekey holen – noch NICHT speichern
	download_turn(game_id, player_id, true)

func _urlencode_form(fields: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for k in fields.keys():
		var key_s: String = String(k).uri_encode()
		var val_s: String = String(fields[k]).uri_encode()
		parts.append(key_s + "=" + val_s)
	return "&".join(parts)

func logout() -> void:
	api_key = ""
	# optional: weitere session infos zurücksetzen

func _save_turn_with_savekey_and_merge(fresh_wrapper: Dictionary) -> void:
	
	# -------------------------
	# savekey
	# -------------------------
	var savekey_v: Variant = fresh_wrapper.get("savekey", "")
	if typeof(savekey_v) != TYPE_STRING:
		emit_signal("save_failed", "No savekey string in fresh wrapper")
		return

	var savekey: String = String(savekey_v)
	
	if savekey.is_empty():
		emit_signal("save_failed", "Empty savekey in fresh wrapper")
		return

	# -------------------------
	# fresh rst
	# -------------------------
	var fresh_rst_v: Variant = fresh_wrapper.get("rst")
	if not (fresh_rst_v is Dictionary):
		emit_signal("save_failed", "Fresh wrapper has no rst Dictionary")
		return
	var fresh_rst: Dictionary = fresh_rst_v as Dictionary

	# -------------------------
	# pending rst
	# -------------------------
	if _pending_save_rst.is_empty():
		emit_signal("save_failed", "Pending save rst is empty")
		return

	# -------------------------
	# turn number
	# -------------------------
	var turn_num: int = 0
	var settings_v: Variant = fresh_rst.get("settings")
	if settings_v is Dictionary:
		var settings: Dictionary = settings_v as Dictionary
		var t_v: Variant = settings.get("turn", 0)
		if typeof(t_v) == TYPE_INT:
			turn_num = int(t_v)
		elif typeof(t_v) == TYPE_FLOAT:
			turn_num = int(float(t_v))

	if turn_num <= 0:
		emit_signal("save_failed", "Could not extract turn number from rst.settings.turn")
		return

	# -------------------------
	# build request fields
	# -------------------------
	var fields: Dictionary = {
		"gameid": str(_pending_save_game_id),
		"playerid": str(_pending_save_player_id),
		"turn": str(turn_num),
		"version": "3.02",
		"savekey": savekey,
		"apikey": api_key,
		"saveindex": "2"
	}

	# -------------------------
	# add changed planets
	# -------------------------
	var command_count: int = 0
	var my_planets: Array[PlanetData] = GameState.get_my_planets()

	for p in my_planets:
		if p == null:
			continue

		var planet_id: int = int(p.planet_id)

		if not _planet_has_relevant_changes(fresh_rst, _pending_save_rst, planet_id):
			continue

		var packed_planet: String = _pack_planet_command(fresh_rst, _pending_save_rst, planet_id)
		if packed_planet.is_empty():
			continue

		fields["Planet" + str(planet_id)] = packed_planet
		command_count += 1

	if command_count <= 0:
		emit_signal("save_failed", "No changed own planets found for upload")
		return

	# Perl reference: keycount = 8 + scalar(@commands)
	fields["keycount"] = str(8 + command_count)

	# -------------------------
	# build POST body
	# -------------------------
	var body: String = _urlencode_form(fields)
	var headers: PackedStringArray = [
		"Content-Type: application/x-www-form-urlencoded; charset=UTF-8"
	]

	# -------------------------
	# send
	# -------------------------
	current_request = RequestType.SAVE_TURN

	var err: int = http.request(
		"http://api.planets.nu/game/save",
		headers,
		HTTPClient.METHOD_POST,
		body
	)

	if err != OK:
		_handle_error("HTTPRequest error: " + str(err))
		return
	
static func _find_planet_dict_by_id(rst: Dictionary, planet_id: int) -> Dictionary:
	var planets_v: Variant = rst.get("planets")
	if not (planets_v is Array):
		return {}

	var planets: Array = planets_v as Array
	for it in planets:
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
			return pd

	return {}

static func _build_planet_save_command(orig_rst: Dictionary, pending_rst: Dictionary, planet_id: int) -> Dictionary:

	var orig_planet: Dictionary = _find_planet_dict_by_id(orig_rst, planet_id)
	var mod_planet: Dictionary = _find_planet_dict_by_id(pending_rst, planet_id)

	if orig_planet.is_empty() or mod_planet.is_empty():
		return {}

	var orig_mines: int = _to_int(orig_planet.get("mines", 0))
	var orig_factories: int = _to_int(orig_planet.get("factories", 0))
	var orig_defense: int = _to_int(orig_planet.get("defense", 0))

	var mod_mines: int = _to_int(mod_planet.get("mines", 0))
	var mod_factories: int = _to_int(mod_planet.get("factories", 0))
	var mod_defense: int = _to_int(mod_planet.get("defense", 0))

	var orig_built_mines: int = _to_int(orig_planet.get("builtmines", 0))
	var orig_built_factories: int = _to_int(orig_planet.get("builtfactories", 0))
	var orig_built_defense: int = _to_int(orig_planet.get("builtdefense", 0))

	var cmd: Dictionary = {}

	cmd["Id"] = planet_id
	cmd["FriendlyCode"] = String(mod_planet.get("friendlycode", ""))

	cmd["Mines"] = mod_mines
	cmd["Factories"] = mod_factories
	cmd["Defense"] = mod_defense

	cmd["TargetMines"] = _to_int(orig_planet.get("targetmines", 0))
	cmd["TargetFactories"] = _to_int(orig_planet.get("targetfactories", 0))
	cmd["TargetDefense"] = _to_int(orig_planet.get("targetdefense", 0))

	cmd["BuiltMines"] = mod_mines - orig_mines + orig_built_mines
	cmd["BuiltFactories"] = mod_factories - orig_factories + orig_built_factories
	cmd["BuiltDefense"] = mod_defense - orig_defense + orig_built_defense

	cmd["MegaCredits"] = _to_int(mod_planet.get("megacredits", 0))
	cmd["Supplies"] = _to_int(mod_planet.get("supplies", 0))
	cmd["SuppliesSold"] = _to_int(mod_planet.get("suppliessold", 0))

	cmd["Neutronium"] = _to_int(mod_planet.get("neutronium", 0))
	cmd["Molybdenum"] = _to_int(mod_planet.get("molybdenum", 0))
	cmd["Duranium"] = _to_int(mod_planet.get("duranium", 0))
	cmd["Tritanium"] = _to_int(mod_planet.get("tritanium", 0))

	cmd["Clans"] = _to_int(mod_planet.get("clans", 0))
	cmd["ColonistTaxRate"] = _to_int(mod_planet.get("colonisttaxrate", 0))
	cmd["NativeTaxRate"] = _to_int(mod_planet.get("nativetaxrate", 0))

	cmd["BuildingStarbase"] = _to_bool_string(mod_planet.get("buildingstarbase", false))

	cmd["NativeHappyChange"] = _to_int(orig_planet.get("nativehappychange", 0))
	cmd["ColHappyChange"] = _to_int(orig_planet.get("colhappychange", 0))
	cmd["ColChange"] = _to_int(orig_planet.get("colchange", 0))
	cmd["ReadyStatus"] = _to_int(orig_planet.get("readystatus", 0))

	return cmd
	
static func _to_int(v: Variant) -> int:
	if typeof(v) == TYPE_INT:
		return int(v)
	if typeof(v) == TYPE_FLOAT:
		return int(float(v))
	if typeof(v) == TYPE_STRING:
		return int(String(v).to_int())
	return 0


static func _to_bool_string(v: Variant) -> String:
	if v is bool:
		if bool(v):
			return "true"
		else:
			return "false"
	return "false"

static func _pack_field_value(v: Variant) -> String:
	var s: String = str(v)
	s = s.replace("|", "_")
	s = s.replace("&", "_")
	return s


static func _pack_planet_command(orig_rst: Dictionary, pending_rst: Dictionary, planet_id: int) -> String:
	var cmd: Dictionary = _build_planet_save_command(orig_rst, pending_rst, planet_id)
	if cmd.is_empty():
		return ""

	var parts: PackedStringArray = PackedStringArray()

	parts.append("Id:::" + _pack_field_value(cmd.get("Id", 0)))
	parts.append("FriendlyCode:::" + _pack_field_value(cmd.get("FriendlyCode", "")))
	parts.append("Mines:::" + _pack_field_value(cmd.get("Mines", 0)))
	parts.append("Factories:::" + _pack_field_value(cmd.get("Factories", 0)))
	parts.append("Defense:::" + _pack_field_value(cmd.get("Defense", 0)))
	parts.append("TargetMines:::" + _pack_field_value(cmd.get("TargetMines", 0)))
	parts.append("TargetFactories:::" + _pack_field_value(cmd.get("TargetFactories", 0)))
	parts.append("TargetDefense:::" + _pack_field_value(cmd.get("TargetDefense", 0)))
	parts.append("BuiltMines:::" + _pack_field_value(cmd.get("BuiltMines", 0)))
	parts.append("BuiltFactories:::" + _pack_field_value(cmd.get("BuiltFactories", 0)))
	parts.append("BuiltDefense:::" + _pack_field_value(cmd.get("BuiltDefense", 0)))
	parts.append("MegaCredits:::" + _pack_field_value(cmd.get("MegaCredits", 0)))
	parts.append("Supplies:::" + _pack_field_value(cmd.get("Supplies", 0)))
	parts.append("SuppliesSold:::" + _pack_field_value(cmd.get("SuppliesSold", 0)))
	parts.append("Neutronium:::" + _pack_field_value(cmd.get("Neutronium", 0)))
	parts.append("Molybdenum:::" + _pack_field_value(cmd.get("Molybdenum", 0)))
	parts.append("Duranium:::" + _pack_field_value(cmd.get("Duranium", 0)))
	parts.append("Tritanium:::" + _pack_field_value(cmd.get("Tritanium", 0)))
	parts.append("Clans:::" + _pack_field_value(cmd.get("Clans", 0)))
	parts.append("ColonistTaxRate:::" + _pack_field_value(cmd.get("ColonistTaxRate", 0)))
	parts.append("NativeTaxRate:::" + _pack_field_value(cmd.get("NativeTaxRate", 0)))
	parts.append("BuildingStarbase:::" + _pack_field_value(cmd.get("BuildingStarbase", "false")))
	parts.append("NativeHappyChange:::" + _pack_field_value(cmd.get("NativeHappyChange", 0)))
	parts.append("ColHappyChange:::" + _pack_field_value(cmd.get("ColHappyChange", 0)))
	parts.append("ColChange:::" + _pack_field_value(cmd.get("ColChange", 0)))
	parts.append("ReadyStatus:::" + _pack_field_value(cmd.get("ReadyStatus", 0)))

	return "|||".join(parts)
static func _planet_has_relevant_changes(orig_rst: Dictionary, pending_rst: Dictionary, planet_id: int) -> bool:
	var orig_planet: Dictionary = _find_planet_dict_by_id(orig_rst, planet_id)
	var mod_planet: Dictionary = _find_planet_dict_by_id(pending_rst, planet_id)

	if orig_planet.is_empty() or mod_planet.is_empty():
		return false

	if String(orig_planet.get("friendlycode", "")) != String(mod_planet.get("friendlycode", "")):
		return true

	if _to_int(orig_planet.get("colonisttaxrate", 0)) != _to_int(mod_planet.get("colonisttaxrate", 0)):
		return true

	if _to_int(orig_planet.get("nativetaxrate", 0)) != _to_int(mod_planet.get("nativetaxrate", 0)):
		return true

	return false
