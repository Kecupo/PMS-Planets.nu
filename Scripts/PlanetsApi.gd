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
func download_turn(game_id: int) -> void:
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
			print("Save response:", data_v)
			
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
