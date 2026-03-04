extends Node
#class_name GameSession

signal game_selected(game_id: int)

var current_game_id: int = 0
var current_player_id: int = 1

func select_game(game_id: int, player_id: int) -> void:
	current_game_id = game_id
	current_player_id = player_id
	GameStorage.ensure_game_dir(game_id)
	emit_signal("game_selected", game_id)

	# 1) local sofort laden (falls vorhanden)
	var local_wrapper: Dictionary = GameStorage.load_json(GameStorage.latest_turn_path(game_id))
	var local_turn: int = 0
	if not local_wrapper.is_empty():
		local_turn = GameState.extract_turn_from_wrapper(local_wrapper)
		GameState.load_turn_from_wrapper(local_wrapper)

	# 2) online latest prüfen (und nur überschreiben wenn neuer)
	PlanetsApi.turn_downloaded.connect(func(remote_wrapper: Dictionary) -> void:
		var remote_turn: int = GameState.extract_turn_from_wrapper(remote_wrapper)
		if remote_turn > local_turn:
			GameStorage.save_json(GameStorage.latest_turn_path(game_id), remote_wrapper)
			GameState.load_turn_from_wrapper(remote_wrapper)
	, CONNECT_ONE_SHOT)

	PlanetsApi.turn_download_failed.connect(func(reason: String) -> void:
		# offline okay: local bleibt
		push_error("Turn download failed: " + reason)
	, CONNECT_ONE_SHOT)

	PlanetsApi.download_turn(game_id)
