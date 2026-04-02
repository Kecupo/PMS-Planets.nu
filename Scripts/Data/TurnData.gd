class_name _TurnData
extends RefCounted

var planets: Array[PlanetData] = []

func load_from_turn(rst: Dictionary) -> void:
	planets.clear()
	if not rst.has("planets"):
		return

	var planet_array: Array = rst.get("planets", [])
	var by_id: Dictionary = {}

	for planet_json in planet_array:
		if planet_json is not Dictionary:
			continue

		var pid: int = int((planet_json as Dictionary).get("id", -1))
		if pid < 0:
			continue

		if not by_id.has(pid):
			by_id[pid] = PlanetData.new(planet_json)
		else:
			(by_id[pid] as PlanetData).merge_prefer_known(planet_json)

	# finalize
	for pid in by_id.keys():
		planets.append(by_id[pid])
