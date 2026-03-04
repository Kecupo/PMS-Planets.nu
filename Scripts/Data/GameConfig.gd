class_name GameConfig
extends RefCounted

const Race_Data = preload("res://Scripts/Data/RaceData.gd")

var races: Array[Race_Data] = []
var races_by_id: Dictionary = {}   # int -> Race_Data

func load_from_turn_json(parsed: Dictionary) -> void:
	# Try several common locations
	var races_array: Array = []

	if parsed.has("races"):
		races_array = parsed.get("races", [])
	elif parsed.has("rst") and parsed["rst"] is Dictionary and (parsed["rst"] as Dictionary).has("races"):
		races_array = (parsed["rst"] as Dictionary).get("races", [])
	elif parsed.has("game") and parsed["game"] is Dictionary and (parsed["game"] as Dictionary).has("races"):
		races_array = (parsed["game"] as Dictionary).get("races", [])
	elif parsed.has("settings") and parsed["settings"] is Dictionary and (parsed["settings"] as Dictionary).has("races"):
		races_array = (parsed["settings"] as Dictionary).get("races", [])

	races.clear()
	races_by_id.clear()

	for r in races_array:
		if r is Dictionary:
			var rd := Race_Data.new(r)

			# IMPORTANT: ensure dictionary key is int (not float)
			var key: int = int(rd.id)
			races.append(rd)
			races_by_id[key] = rd

	print("GameConfig: races loaded =", races.size(), " keys =", races_by_id.size())
	if races.size() > 0:
		print("GameConfig: sample race id=", races[0].id, " adjective=", races[0].adjective, " shortname=", races[0].shortname)


func get_race(owner_id: int) -> Race_Data:
	return races_by_id.get(owner_id, null)

func get_owner_abbrev(owner_id: int) -> String:
	if owner_id == 0:
		return "—"
	var rd: Race_Data = get_race(owner_id)
	if rd == null:
		return str(owner_id)
	return rd.owner_abbrev()
