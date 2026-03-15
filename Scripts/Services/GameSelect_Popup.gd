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
	var g: Dictionary = _games[index]
	var id_v: Variant = g.get("id", 0)
	var gid: int = int(id_v) if typeof(id_v) == TYPE_INT else int(float(id_v))
	_select_game_id(gid)

func _refresh() -> void:
	status_label.text = "Loading games..."

	# Nur UI resetten
	game_list.clear()
	_games.clear()
	game_list.deselect_all()

	PlanetsApi.list_games()  # ohne username (siehe Punkt 3)
	
func _on_games_list_failed(reason: String) -> void:
	status_label.text = "Failed: " + reason

func _on_games_listed(games: Array[Dictionary]) -> void:
	_populating = true

	game_list.clear()
	_games = games

	for g in _games:
		var name_g: String = String(g.get("name", ""))
		var id_v: Variant = g.get("id", 0)
		var gid: int = int(id_v) if typeof(id_v) == TYPE_INT else int(float(id_v))
		game_list.add_item("%s (%d)" % [name_g, gid])

	game_list.deselect_all()
	_populating = false
	status_label.text = "Select a game"
	
func _on_item_activated(index: int) -> void:
	if index < 0 or index >= _games.size():
		return

	var g: Dictionary = _games[index]
	var id_v: Variant = g.get("id", 0)
	var gid: int = int(id_v) if typeof(id_v) == TYPE_INT else int(float(id_v))

	# Spiel setzen
	GameState.set_current_game(gid)

	# Lokal laden (falls vorhanden)
	var local_turn: int = 0
	var local_loaded: bool = GameState.load_latest_turn_from_disk()
	if local_loaded:
		local_turn = GameState.get_current_turn()

	# Remote latest prüfen
	status_label.text = "Checking latest turn online..."

	PlanetsApi.turn_downloaded.connect(func(remote_wrapper: Dictionary) -> void:
		hide()
		var remote_turn: int = GameState.extract_turn_from_wrapper(remote_wrapper)
		if remote_turn > local_turn:
			GameState.save_turn(remote_wrapper)  # speichert + lädt
	, CONNECT_ONE_SHOT)

	PlanetsApi.turn_download_failed.connect(func(reason: String) -> void:
		status_label.text = "Turn download failed: " + reason
	# nicht hide(), sonst siehst du die Ursache nicht
	, CONNECT_ONE_SHOT)


	PlanetsApi.download_turn(gid, GameState.my_player_id)  # ohne playerid

func _select_game_id(gid: int) -> void:
	GameState.set_current_game(gid)

	var local_turn: int = 0
	var local_loaded: bool = GameState.load_latest_turn_from_disk()
	if local_loaded:
		local_turn = GameState.get_current_turn()

	status_label.text = "Checking latest turn online..."

	PlanetsApi.turn_downloaded.connect(func(remote_wrapper: Dictionary) -> void:
		hide()
		var remote_turn: int = GameState.extract_turn_from_wrapper(remote_wrapper)
		if remote_turn > local_turn:
			GameState.save_turn(remote_wrapper)
	, CONNECT_ONE_SHOT)

	PlanetsApi.turn_download_failed.connect(func(reason: String) -> void:
		status_label.text = "Turn download failed: " + reason
	, CONNECT_ONE_SHOT)

	PlanetsApi.download_turn(gid, GameState.my_player_id)
