class_name _TurnData
extends RefCounted
const IonStormCircle_Data = preload("res://Scripts/Data/IonStormCircleData.gd")
const IonStorm_Data = preload("res://Scripts/Data/IonStormData.gd")
const Minefield_Data = preload("res://Scripts/Data/MinefieldData.gd")
var starbase_planet_ids: Dictionary = {}
var planets: Array[PlanetData] = []
var minefields: Array[Minefield_Data] = []
var ionstorms: Array[IonStorm_Data] = []

func load_from_turn(rst: Dictionary) -> void:
	planets.clear()
	minefields.clear()
	starbase_planet_ids.clear()
	ionstorms.clear()
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
	if rst.has("ionstorms"):
		var ionstorm_array: Array = rst.get("ionstorms", [])

		var circles_by_id: Dictionary = {}
		var storms_by_root_id: Dictionary = {}

		# 1) alle Kreise einlesen
		for ionstorm_json: Variant in ionstorm_array:
			if ionstorm_json is not Dictionary:
				continue

			var circle: IonStormCircleData = IonStormCircleData.new()
			circle.apply_dict(ionstorm_json as Dictionary)
			circles_by_id[circle.storm_id] = circle

		# 2) Hauptstürme anlegen (parent_id == 0)
		for circle_id: Variant in circles_by_id.keys():
			var root_circle: IonStormCircleData = circles_by_id[circle_id]
			if root_circle.parent_id != 0:
				continue

			var storm: IonStormData = IonStormData.new()
			storm.storm_id = root_circle.storm_id
			storm.heading = root_circle.heading
			storm.warp = root_circle.warp
			storm.voltage = root_circle.voltage
			storm.is_growing = root_circle.is_growing
			storm.circles.append(root_circle)

			storms_by_root_id[storm.storm_id] = storm

		# 3) Teilkreise ihren Hauptstürmen zuordnen
		for circle_id: Variant in circles_by_id.keys():
			var child_circle: IonStormCircleData = circles_by_id[circle_id]
			if child_circle.parent_id == 0:
				continue

			if storms_by_root_id.has(child_circle.parent_id):
				var parent_storm: IonStormData = storms_by_root_id[child_circle.parent_id]
				parent_storm.circles.append(child_circle)

		# 4) ins Array übernehmen
		for storm_id: Variant in storms_by_root_id.keys():
			ionstorms.append(storms_by_root_id[storm_id])
