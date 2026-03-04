extends Node
class_name GameStorage

const ROOT_GAMES: String = "user://games"
const API_KEY_FILE: String = "user://api_key.json"

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
	
static func rand_ai_config_path(game_id: int) -> String:
	var p: String = "%s/%d" % [ROOT_GAMES, game_id]
	return p.path_join("rand_ai_config.json")
