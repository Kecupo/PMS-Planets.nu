class_name StarshipData
extends RefCounted

var ship_id: int = -1
var ownerid: int = -1
var x: float = 0.0
var y: float = 0.0
var heading: float = 0.0
var warp: float = 0.0
var targetx: float = 0.0
var targety: float = 0.0
var hullid: int = -1
var hullname: String = ""
var name: String = ""
var ishidden: bool = false
var raw: Dictionary = {}

func apply_dict(d: Dictionary, hull_names_by_id: Dictionary = {}) -> void:
	raw = d
	ship_id = _read_int(d, ["id", "shipid"], ship_id)
	ownerid = _read_int(d, ["ownerid"], ownerid)
	x = _read_float(d, ["x"], x)
	y = _read_float(d, ["y"], y)
	heading = _read_float(d, ["heading"], heading)
	warp = _read_float(d, ["warp"], warp)
	targetx = _read_float(d, ["targetx"], x)
	targety = _read_float(d, ["targety"], y)
	hullid = _read_int(d, ["hullid", "truehullid"], hullid)
	name = _read_string(d, ["name", "shipname"], name)
	hullname = _read_string(d, ["hullname", "hull", "hullfullname", "shiphull"], hullname)
	ishidden = bool(d.get("ishidden", ishidden))

	if hullname.is_empty() and hull_names_by_id.has(hullid):
		hullname = String(hull_names_by_id[hullid])

func display_hull_name() -> String:
	if not hullname.is_empty():
		return hullname
	if not name.is_empty():
		return name
	return "Unknown Hull"

func has_target() -> bool:
	return targetx != x or targety != y

static func _read_int(d: Dictionary, keys: Array[String], default_value: int) -> int:
	for key: String in keys:
		if not d.has(key):
			continue
		var v: Variant = d.get(key)
		if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
			return int(v)
		var s: String = String(v)
		if s.is_valid_int():
			return int(s)
		if s.is_valid_float():
			return int(float(s))
	return default_value

static func _read_float(d: Dictionary, keys: Array[String], default_value: float) -> float:
	for key: String in keys:
		if not d.has(key):
			continue
		var v: Variant = d.get(key)
		if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
			return float(v)
		var s: String = String(v)
		if s.is_valid_float():
			return float(s)
	return default_value

static func _read_string(d: Dictionary, keys: Array[String], default_value: String) -> String:
	for key: String in keys:
		if d.has(key):
			return String(d.get(key, default_value))
	return default_value
