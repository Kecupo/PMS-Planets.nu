extends Node
class_name OrdersStore

# orders: planet_id (string) -> Dictionary of order overrides
# Example:
# {
#   "17": {"colonisttaxrate": 5, "nativetaxrate": 8, "friendly_code": "aTt", "build_mines": 10, "auto_managed": true}
# }
var orders: Dictionary = {}
signal orders_changed(game_id: int)

var _batch_depth: int = 0
var _batch_game_id: int = -1

func begin_batch(game_id: int) -> void:
	_batch_depth += 1
	_batch_game_id = game_id

func end_batch(game_id: int) -> void:
	if _batch_depth <= 0:
		return
	_batch_depth -= 1
	if _batch_depth == 0:
		_maybe_save(game_id)
		emit_signal("orders_changed", game_id)
		_batch_game_id = -1
		
func _maybe_save(game_id: int) -> void:
	if _batch_depth > 0:
		return
	save_for_game(game_id)
	emit_signal("orders_changed", game_id)


# --- Persistence -------------------------------------------------------------

func load_for_game(game_id: int) -> void:
	var path := _path(game_id)
	if not FileAccess.file_exists(path):
		orders = {}
		return

	var text: String = FileAccess.get_file_as_string(path)
	var parsed_any: Variant = JSON.parse_string(text)

	if parsed_any is Dictionary:
		orders = parsed_any as Dictionary
	else:
		orders = {}


func save_for_game(game_id: int) -> void:
	var path := _path(game_id)
	var dir := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)

	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("OrdersStore: failed to write " + path)
		return
	f.store_string(JSON.stringify(orders))
	f.close()


func _path(game_id: int) -> String:
	return "user://orders/game_%d_orders.json" % game_id


# --- Helpers -----------------------------------------------------------------

func _ensure_planet_dict(planet_id: int) -> Dictionary:
	var pid := str(planet_id)
	if not orders.has(pid) or not (orders[pid] is Dictionary):
		orders[pid] = {}
	return orders[pid] as Dictionary


func _has_key(planet_id: int, key: String) -> bool:
	var pid := str(planet_id)
	return orders.has(pid) and (orders[pid] is Dictionary) and (orders[pid] as Dictionary).has(key)


# --- Existing: Tax -----------------------------------------------------------

func set_colonist_tax(game_id: int, planet_id: int, tax: int) -> void:
	var d := _ensure_planet_dict(planet_id)
	d["colonisttaxrate"] = clamp(tax, 0, 100)
	orders[str(planet_id)] = d
	_maybe_save(game_id)


func set_native_tax(game_id: int, planet_id: int, tax: int) -> void:
	var d := _ensure_planet_dict(planet_id)
	d["nativetaxrate"] = clamp(tax, 0, 100)
	orders[str(planet_id)] = d
	_maybe_save(game_id)


func get_colonist_tax_override(planet_id: int) -> int:
	var pid := str(planet_id)
	if not orders.has(pid):
		return -1
	var d: Dictionary = orders[pid] as Dictionary
	return int(d.get("colonisttaxrate", -1))


func get_native_tax_override(planet_id: int) -> int:
	var pid := str(planet_id)
	if not orders.has(pid):
		return -1
	var d: Dictionary = orders[pid] as Dictionary
	return int(d.get("nativetaxrate", -1))


func clear_colonist_tax(game_id: int, planet_id: int) -> void:
	if _has_key(planet_id, "colonisttaxrate"):
		(orders[str(planet_id)] as Dictionary).erase("colonisttaxrate")
		_maybe_save(game_id)


func clear_native_tax(game_id: int, planet_id: int) -> void:
	if _has_key(planet_id, "nativetaxrate"):
		(orders[str(planet_id)] as Dictionary).erase("nativetaxrate")
		_maybe_save(game_id)


# --- New: Friendly Code ------------------------------------------------------

func set_friendly_code(game_id: int, planet_id: int, fc: String) -> void:
	var d := _ensure_planet_dict(planet_id)
	d["friendly_code"] = fc
	orders[str(planet_id)] = d
	_maybe_save(game_id)


func get_friendly_code_override(planet_id: int) -> String:
	var pid := str(planet_id)
	if not orders.has(pid):
		return ""
	var d: Dictionary = orders[pid] as Dictionary
	return String(d.get("friendly_code", ""))


func clear_friendly_code(game_id: int, planet_id: int) -> void:
	if _has_key(planet_id, "friendly_code"):
		(orders[str(planet_id)] as Dictionary).erase("friendly_code")
		_maybe_save(game_id)


# --- New: Build Orders (mines/factories) ------------------------------------

func set_build_mines(game_id: int, planet_id: int, count: int) -> void:
	var d := _ensure_planet_dict(planet_id)
	d["build_mines"] = max(count, 0)
	orders[str(planet_id)] = d
	_maybe_save(game_id)


func set_build_factories(game_id: int, planet_id: int, count: int) -> void:
	var d := _ensure_planet_dict(planet_id)
	d["build_factories"] = max(count, 0)
	orders[str(planet_id)] = d
	_maybe_save(game_id)


func get_build_mines_override(planet_id: int) -> int:
	var pid := str(planet_id)
	if not orders.has(pid):
		return -1
	var d: Dictionary = orders[pid] as Dictionary
	return int(d.get("build_mines", -1))


func get_build_factories_override(planet_id: int) -> int:
	var pid := str(planet_id)
	if not orders.has(pid):
		return -1
	var d: Dictionary = orders[pid] as Dictionary
	return int(d.get("build_factories", -1))


func clear_build_mines(game_id: int, planet_id: int) -> void:
	if _has_key(planet_id, "build_mines"):
		(orders[str(planet_id)] as Dictionary).erase("build_mines")
		_maybe_save(game_id)


func clear_build_factories(game_id: int, planet_id: int) -> void:
	if _has_key(planet_id, "build_factories"):
		(orders[str(planet_id)] as Dictionary).erase("build_factories")
		_maybe_save(game_id)


# --- New: Auto-managed flag --------------------------------------------------

func set_auto_managed(game_id: int, planet_id: int, val: bool) -> void:
	var d := _ensure_planet_dict(planet_id)
	if bool(d.get("auto_managed", false)) == val:
		return
	d["auto_managed"] = val
	orders[str(planet_id)] = d
	_maybe_save(game_id)


func is_auto_managed(planet_id: int) -> bool:
	var pid := str(planet_id)
	if not orders.has(pid):
		return false
	var d: Dictionary = orders[pid] as Dictionary
	return bool(d.get("auto_managed", false))


func clear_auto_managed(game_id: int, planet_id: int) -> void:
	if _has_key(planet_id, "auto_managed"):
		(orders[str(planet_id)] as Dictionary).erase("auto_managed")
		_maybe_save(game_id)
