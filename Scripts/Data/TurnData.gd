class_name _TurnData
extends RefCounted
const IonStormCircle_Data = preload("res://Scripts/Data/IonStormCircleData.gd")
const IonStorm_Data = preload("res://Scripts/Data/IonStormData.gd")
const Minefield_Data = preload("res://Scripts/Data/MinefieldData.gd")
const NebulaCircle_Data = preload("res://Scripts/Data/NebulaCircleData.gd")
const Nebula_Data = preload("res://Scripts/Data/NebulaData.gd")
const StarCluster_Data = preload("res://Scripts/Data/StarClusterData.gd")
const Starship_Data = preload("res://Scripts/Data/StarshipData.gd")
var starbase_planet_ids: Dictionary = {}
var planets: Array[PlanetData] = []
var starships: Array[Starship_Data] = []
var minefields: Array[Minefield_Data] = []
var ionstorms: Array[IonStorm_Data] = []
var nebulas: Array[Nebula_Data] = []
var starclusters: Array[StarCluster_Data] = []

func load_from_turn(rst: Dictionary) -> void:
	planets.clear()
	starships.clear()
	minefields.clear()
	starbase_planet_ids.clear()
	ionstorms.clear()
	nebulas.clear()
	starclusters.clear()
	if rst.has("stars"):
		var stars_array: Array = rst.get("stars", [])

		for star_json: Variant in stars_array:
			if star_json is not Dictionary:
				continue

			var star: StarClusterData = StarClusterData.new()
			star.apply_dict(star_json as Dictionary)
			starclusters.append(star)
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

	if rst.has("ships"):
		var hull_names_by_id: Dictionary = _build_hull_names_by_id(rst)
		var ship_array: Array = rst.get("ships", [])

		for ship_json: Variant in ship_array:
			if ship_json is not Dictionary:
				continue

			var ship: StarshipData = StarshipData.new()
			ship.apply_dict(ship_json as Dictionary, hull_names_by_id)
			starships.append(ship)

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
	if rst.has("nebulas"):
		var nebula_array: Array = rst.get("nebulas", [])
		var nebulas_by_name: Dictionary = {}

		for nebula_json: Variant in nebula_array:
			if nebula_json is not Dictionary:
				continue

			var circle: NebulaCircleData = NebulaCircleData.new()
			circle.apply_dict(nebula_json as Dictionary)

			if circle.name.is_empty():
				continue

			if not nebulas_by_name.has(circle.name):
				var nebula: NebulaData = NebulaData.new()
				nebula.name = circle.name
				nebulas_by_name[circle.name] = nebula

			var grouped_nebula: NebulaData = nebulas_by_name[circle.name]
			grouped_nebula.circles.append(circle)

		for nebula_name: Variant in nebulas_by_name.keys():
			nebulas.append(nebulas_by_name[nebula_name])

func _build_hull_names_by_id(rst: Dictionary) -> Dictionary:
	var hull_names_by_id: Dictionary = {}
	var hulls_v: Variant = rst.get("hulls", [])
	if not (hulls_v is Array):
		return hull_names_by_id

	for hull_v: Variant in hulls_v:
		if not (hull_v is Dictionary):
			continue

		var hull: Dictionary = hull_v as Dictionary
		var id_v: Variant = hull.get("id", -1)
		var hull_id: int = int(id_v) if typeof(id_v) == TYPE_INT else int(float(id_v))
		if hull_id <= 0:
			continue

		var hull_name: String = String(hull.get("name", ""))
		if not hull_name.is_empty():
			hull_names_by_id[hull_id] = hull_name

	return hull_names_by_id
