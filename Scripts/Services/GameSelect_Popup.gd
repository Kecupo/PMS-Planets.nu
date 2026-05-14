extends Window
class_name GameSelectPopup

@onready var status_label: Label = $VBox/Status
@onready var game_list: ItemList = $VBox/GameList
@onready var refresh_button: Button = $VBox/GameList/Buttons/RefreshButton
@onready var close_button: Button = $VBox/GameList/Buttons/CloseButton

var _populating: bool = false
var _games: Array[Dictionary] = []

func _ready() -> void:
	game_list.item_clicked.connect(_on_item_clicked)
	refresh_button.pressed.connect(_refresh)
	close_button.pressed.connect(func() -> void: hide())
	if not PlanetsApi.games_listed.is_connected(_on_games_listed):
		PlanetsApi.games_listed.connect(_on_games_listed)
	if not PlanetsApi.games_list_failed.is_connected(_on_games_list_failed):
		PlanetsApi.games_list_failed.connect(_on_games_list_failed)

func open_and_load() -> void:
	show()
	popup_centered()
	grab_focus()
	_refresh()

func _on_item_clicked(index: int, _pos: Vector2, _button: int) -> void:
	if index < 0 or index >= _games.size():
		return
	_select_game(_games[index])

func _on_item_activated(index: int) -> void:
	if index < 0 or index >= _games.size():
		return
	_select_game(_games[index])

func _refresh() -> void:
	status_label.text = "Loading games..."
	game_list.clear()
	_games.clear()
	game_list.deselect_all()
	PlanetsApi.list_games()

func _on_games_list_failed(reason: String) -> void:
	var local_games: Array[Dictionary] = GameStorage.list_local_games()
	if local_games.is_empty():
		status_label.text = "Failed: " + reason
		return
	_show_games(local_games, "Offline: showing local turns")

func _on_games_listed(games: Array[Dictionary]) -> void:
	_show_games(games, "Select a game")

func _show_games(games: Array[Dictionary], status_text: String) -> void:
	_populating = true
	game_list.clear()
	_games = games
	for g: Dictionary in _games:
		game_list.add_item(_game_list_label(g))
	game_list.deselect_all()
	_populating = false
	status_label.text = status_text

func _select_game_id(gid: int) -> void:
	_select_game({"id": gid})

func _select_game(g: Dictionary) -> void:
	var gid: int = _game_id(g)
	if gid <= 0:
		status_label.text = "Invalid game id"
		return

	GameState.set_current_game(gid)

	var local_turn: int = 0
	var local_loaded: bool = GameState.load_latest_turn_from_disk()
	if local_loaded:
		local_turn = GameState.get_current_turn()

	if bool(g.get("local", false)):
		if local_loaded:
			status_label.text = "Loaded local turn %d" % local_turn
			hide()
		else:
			status_label.text = "Local turn file missing"
		return

	var remote_turn_hint: int = _game_turn_hint(g)
	if local_loaded and remote_turn_hint > 0 and local_turn >= remote_turn_hint:
		status_label.text = "Local turn %d is current" % local_turn
		hide()
		return

	status_label.text = "Checking latest turn online..."

	PlanetsApi.turn_downloaded.connect(func(remote_wrapper: Dictionary) -> void:
		var remote_turn: int = GameState.extract_turn_from_wrapper(remote_wrapper)
		if remote_turn > local_turn:
			GameState.save_turn(remote_wrapper)
		hide()
	, CONNECT_ONE_SHOT)

	PlanetsApi.turn_download_failed.connect(func(reason: String) -> void:
		if local_loaded:
			status_label.text = "Loaded local turn %d; online check failed" % local_turn
			hide()
		else:
			status_label.text = "Turn download failed: " + reason
	, CONNECT_ONE_SHOT)

	var player_id: int = _game_player_id(g)
	if player_id <= 0:
		player_id = GameState.my_player_id
	PlanetsApi.download_turn(gid, player_id)

func _game_list_label(g: Dictionary) -> String:
	var gid: int = _game_id(g)
	var name_g: String = String(g.get("name", "")).strip_edges()
	var turn: int = _game_turn_hint(g)
	var parts: Array[String] = []
	if bool(g.get("local", false)):
		parts.append("[local]")
	parts.append(name_g if not name_g.is_empty() else "Game %d" % gid)
	parts.append("(%d)" % gid)
	if turn > 0:
		parts.append("Turn %d" % turn)
	return " ".join(parts)

func _game_id(g: Dictionary) -> int:
	return _variant_int(g.get("id", g.get("gameid", 0)))

func _game_player_id(g: Dictionary) -> int:
	return _variant_int(g.get("playerid", g.get("player_id", 0)))

func _game_turn_hint(g: Dictionary) -> int:
	for key: String in ["turn", "currentturn", "turnid", "turnnumber"]:
		var value: int = _variant_int(g.get(key, 0))
		if value > 0:
			return value
	return 0

func _variant_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	if typeof(value) == TYPE_STRING:
		var text: String = String(value)
		if text.is_valid_int():
			return int(text)
		if text.is_valid_float():
			return int(float(text))
	return 0
