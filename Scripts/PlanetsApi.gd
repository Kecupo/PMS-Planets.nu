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
var _pending_save_wrapper: Dictionary = {}
var _pending_save_forsave: bool = false
var _pending_username: String = ""
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
func _handle_error(reason: String) -> void:
	match current_request:
		RequestType.LOGIN:
			emit_signal("login_failed", reason)
		RequestType.LOAD_TURN:
			emit_signal("turn_download_failed", reason)
		RequestType.LIST_GAMES:
			emit_signal("games_list_failed", reason)

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
	GameState.load_turn_from_parsed_wrapper(data)
	print("Turn data received")
	GameState.save_turn(data)
	emit_signal("turn_downloaded", data)

	# Wenn dies ein forsave-Download war und ein Save aussteht, direkt Save auslösen
	if _pending_save_forsave and _pending_save_game_id > 0:
		_pending_save_forsave = false
		_save_turn_with_savekey(data)
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
func download_turn(game_id: int, forsave: bool = false) -> void:
	# lazy inject
	if api_key.is_empty() and not GameState.api_key.is_empty():
		api_key = GameState.api_key
	
	if api_key.is_empty():
		_handle_error("No API key – login required")
		return

	var url: String = (
		"https://api.planets.nu/game/loadturn"
		+ "?gameid=" + str(game_id)
		+ "&apikey=" + api_key.uri_encode()
		)
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

	print("HTTP completed:", result, response_code, "finished_request:", finished_request)

	var text: String = body.get_string_from_utf8()
	print("RESPONSE HEAD:", text.substr(0, 120))

	if response_code != 200:
		_handle_error("HTTP " + str(response_code))
		return

	var data_v: Variant = JSON.parse_string(text)
	if data_v == null:
		_handle_error("Invalid JSON (parse_string returned null)")
		return

	match finished_request:
		RequestType.LOGIN:
			if data_v is Dictionary:
				_handle_login_response(data_v as Dictionary)
			else:
				_handle_error("Invalid JSON (LOGIN expected Dictionary)")

		RequestType.LOAD_TURN:
			if data_v is Dictionary:
				_handle_turn_response(data_v as Dictionary)
			else:
				_handle_error("Invalid JSON (LOAD_TURN expected Dictionary)")
		
		RequestType.SAVE_TURN:
			if data_v is Dictionary:
				var d: Dictionary = data_v as Dictionary
				if d.get("success", false) == true:
					emit_signal("save_success", d)
				else:
					var reason: String = String(d.get("error", "Save failed"))
					emit_signal("save_failed", reason)
			else:
				_handle_error("Invalid JSON (SAVE_TURN expected Dictionary)")
				
		RequestType.LIST_GAMES:
			if data_v is Array:
				var arr: Array = data_v as Array
				var out: Array[Dictionary] = []
				for it in arr:
					if it is Dictionary:
						out.append(it as Dictionary)
				emit_signal("games_listed", out)
			else:
				_handle_error("Invalid JSON (LIST_GAMES expected Array)")

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

	# Wrapper nur als "change source" behalten (deine lokalen Änderungen / Orders)
	_pending_save_wrapper = wrapper
	_pending_save_game_id = game_id
	_pending_save_player_id = player_id

	# 1) Direkt vor Save: frischen wrapper + savekey holen
	download_turn(game_id, true)

	var url: String = "http://api.planets.nu/game/save"

	var payload: Dictionary = {
		"apikey": api_key,
		"gameid": game_id,
		"playerid": player_id,
		"rst": wrapper["rst"]
	}

	var json: String = JSON.stringify(payload)

	current_request = RequestType.SAVE_TURN

	var headers: PackedStringArray = [
		"Content-Type: application/json"
	]

	var err: int = http.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		json
	)

	if err != OK:
		_handle_error("HTTPRequest error: " + str(err))

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

func _save_turn_with_savekey(fresh_wrapper: Dictionary) -> void:
	if not fresh_wrapper.has("rst"):
		emit_signal("save_failed", "Fresh wrapper has no rst")
		return

	var savekey_v: Variant = fresh_wrapper.get("savekey", "")
	if typeof(savekey_v) != TYPE_STRING or String(savekey_v).is_empty():
		emit_signal("save_failed", "No savekey in forsave wrapper")
		return

	var savekey: String = String(savekey_v)

	# 2) Hier müssen die Änderungen im RST drin sein.
	# Da du Tax/FC aktuell direkt in GameState.last_turn_json/rst schreibst:
	# -> wir nehmen fresh rst und überschreiben die planet orders aus GameState.last_turn_json["rst"].
	#
	# Minimal robust: benutze komplett GameState.last_turn_json["rst"] falls vorhanden,
	# aber setze savekey aus fresh wrapper.

	var rst_to_save: Dictionary
	var gs_rst_v: Variant = GameState.last_turn_json.get("rst")
	if gs_rst_v is Dictionary:
		rst_to_save = gs_rst_v as Dictionary
	else:
		# fallback: save the fresh rst (better than nothing)
		rst_to_save = fresh_wrapper["rst"] as Dictionary

	# turn ist oft im rst.game.turn
	var turn_num: int = 0
	var rst_game_v: Variant = rst_to_save.get("game")
	if rst_game_v is Dictionary:
		var g: Dictionary = rst_game_v as Dictionary
		var tv: Variant = g.get("turn", 0)
		if typeof(tv) == TYPE_INT:
			turn_num = int(tv)
		elif typeof(tv) == TYPE_FLOAT:
			turn_num = int(float(tv))

	var payload: Dictionary = {
		"apikey": api_key,
		"gameid": _pending_save_game_id,
		"playerid": _pending_save_player_id, # kann bei aktiven games evtl. optional sein; schadet aber nicht
		"turn": turn_num,
		"savekey": savekey,
		"rst": rst_to_save
	}

	var json: String = JSON.stringify(payload)
	var headers: PackedStringArray = ["Content-Type: application/json"]

	current_request = RequestType.SAVE_TURN

	var err: int = http.request(
		"http://api.planets.nu/game/save",
		headers,
		HTTPClient.METHOD_POST,
		json
	)

	if err != OK:
		_handle_error("HTTPRequest error: " + str(err))
		return

	# pending reset (wir lassen game/player stehen, aber wrapper leeren)
	_pending_save_wrapper = {}
	_pending_save_game_id = 0
	_pending_save_player_id = 0
