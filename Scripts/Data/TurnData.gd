class_name _TurnData
extends RefCounted

const Minefield_Data = preload("res://Scripts/Data/MinefieldData.gd")
var starbase_planet_ids: Dictionary = {}
var planets: Array[PlanetData] = []
var minefields: Array[Minefield_Data] = []

func load_from_turn(rst: Dictionary) -> void:
	planets.clear()
	minefields.clear()
	starbase_planet_ids.clear()
	if rst.has("planets"):
		var planet_array: Array = rst.get("planets", [])
		var by_id: Dictionary = {}

		for planet_json: Variant in planet_array:
			if planet_json is not Dictionary:
				continue

			var pid: int = int(float((planet_json as Dictionary).get("id", -1)))
			if pid < 0:
				continue

			if not by_id.has(pid):
				by_id[pid] = PlanetData.new(planet_json)
			else:
				(by_id[pid] as PlanetData).merge_prefer_known(planet_json)

		for pid: Variant in by_id.keys():
			planets.append(by_id[pid])

	if rst.has("minefields"):
		var minefield_array: Array = rst.get("minefields", [])

		for minefield_json: Variant in minefield_array:
			if minefield_json is not Dictionary:
				continue

			var mf: MinefieldData = MinefieldData.new()
			mf.apply_dict(minefield_json as Dictionary)
			minefields.append(mf)
	if rst.has("starbases"):
		var starbase_array: Array = rst.get("starbases", [])

		for starbase_json: Variant in starbase_array:
			if starbase_json is not Dictionary:
				continue

			var d: Dictionary = starbase_json as Dictionary
			var planet_id: int = int(float(d.get("planetid", -1)))
			if planet_id > 0:
				starbase_planet_ids[planet_id] = true
