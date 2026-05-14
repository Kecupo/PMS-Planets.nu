extends Node
class_name GameStorage

const ROOT_GAMES: String = "user://games"

static func ensure_game_dir(game_id: int) -> void:
	if not DirAccess.dir_exists_absolute(ROOT_GAMES):
		DirAccess.make_dir_recursive_absolute(ROOT_GAMES)
	var p: String = "%s/%d" % [ROOT_GAMES, game_id]
	if not DirAccess.dir_exists_absolute(p):
		DirAccess.make_dir_recursive_absolute(p)

static func latest_turn_path(game_id: int) -> String:
	return "%s/%d/latest_turn.json" % [ROOT_GAMES, game_id]

static func save_json(path: String, data: Dictionary) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("GameStorage: cannot write " + path)
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	return true

static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	if text.strip_edges().is_empty():
		return {}

	var parsed_v: Variant = JSON.parse_string(text)
	if not (parsed_v is Dictionary):
		push_error("Config JSON is not a Dictionary: " + path)
		return {}
	return parsed_v as Dictionary

static func list_local_games() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(ROOT_GAMES):
		return result

	var dir: DirAccess = DirAccess.open(ROOT_GAMES)
	if dir == null:
		return result

	dir.list_dir_begin()
	var entry_name: String = dir.get_next()
	while not entry_name.is_empty():
		if dir.current_is_dir() and not entry_name.begins_with(".") and entry_name.is_valid_int():
			var game_id: int = int(entry_name)
			var wrapper: Dictionary = load_json(latest_turn_path(game_id))
			if not wrapper.is_empty():
				result.append(_local_game_entry(game_id, wrapper))
		entry_name = dir.get_next()
	dir.list_dir_end()

	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("id", 0)) < int(b.get("id", 0))
	)
	return result

static func _local_game_entry(game_id: int, wrapper: Dictionary) -> Dictionary:
	var rst: Dictionary = _child_dict(wrapper, "rst")
	var game: Dictionary = _child_dict(rst, "game")
	var player: Dictionary = _child_dict(rst, "player")
	var name: String = String(game.get("name", "")).strip_edges()
	if name.is_empty():
		name = String(game.get("description", "")).strip_edges()
	if name.is_empty():
		name = "Game %d" % game_id

	return {
		"id": game_id,
		"name": name,
		"turn": _dict_int(game, "turn", 0),
		"playerid": _dict_int(player, "id", 0),
		"raceid": _dict_int(player, "raceid", 0),
		"local": true
	}

static func _child_dict(parent: Dictionary, key: String) -> Dictionary:
	var value: Variant = parent.get(key, {})
	if value is Dictionary:
		return value as Dictionary
	return {}

static func _dict_int(parent: Dictionary, key: String, fallback: int) -> int:
	var value: Variant = parent.get(key, fallback)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	if typeof(value) == TYPE_STRING and String(value).is_valid_int():
		return int(String(value))
	return fallback
	
static func rand_ai_config_path(game_id: int) -> String:
	var p: String = "%s/%d" % [ROOT_GAMES, game_id]
	return p.path_join("rand_ai_config.json")
