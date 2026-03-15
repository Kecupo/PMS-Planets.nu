extends Node
class_name PlanetMath

# Godot 4.5.1
# Pure calculation helpers (no UI, no IO).

const _PI_APPROX: float = 3.14

# ------------------------------------------------------------
# Basic helpers
# ------------------------------------------------------------

static func _to_int(v: Variant) -> int:
	if typeof(v) == TYPE_INT:
		return int(v)
	if typeof(v) == TYPE_FLOAT:
		return int(float(v))
	if typeof(v) == TYPE_STRING:
		var s: String = String(v)
		if s.is_valid_int():
			return s.to_int()
	return 0

static func _to_float(v: Variant) -> float:
	if typeof(v) == TYPE_INT:
		return float(int(v))
	if typeof(v) == TYPE_FLOAT:
		return float(v)
	if typeof(v) == TYPE_STRING:
		return float(String(v).to_float())
	return 0.0

static func _known_nonneg(v: float) -> bool:
	return v >= 0.0

static func _trunc(x: float) -> int:
	return int(x)

static func _has(p: PlanetData, key: String) -> bool:
	return not p.raw.is_empty() and p.raw.has(key)

static func _native_type(p: PlanetData) -> int:
	return int(p.nativetype)

static func _native_race_name_lc(p: PlanetData) -> String:
	return String(p.nativeracename).strip_edges().to_lower()

# ------------------------------------------------------------
# Buildings
# ------------------------------------------------------------

static func max_building(clans: int, base_amount: int) -> int:
	if clans <= 0:
		return 0
	if clans <= base_amount:
		return clans
	return int(floor(float(base_amount) + sqrt(float(clans - base_amount))))

func max_mines(p: PlanetData) -> int:
	if not _known_nonneg(p.clans):
		return -1
	return max_building(int(p.clans), 200)

func max_factories(p: PlanetData) -> int:
	if not _known_nonneg(p.clans):
		return -1
	return max_building(int(p.clans), 100)

func max_defense(p: PlanetData) -> int:
	if not _known_nonneg(p.clans):
		return -1
	return max_building(int(p.clans), 50)

# ------------------------------------------------------------
# Colonist happiness
# Official style formula already close to planets.nu docs
# ------------------------------------------------------------

static func colonist_happiness_next_turn(p: PlanetData, base_temp: float = 50.0) -> int:
	return colonist_happiness_next_turn_with_tax(p, int(p.colonisttaxrate), base_temp)

static func colonist_happiness_next_turn_with_tax(p: PlanetData, tax_rate: int, base_temp: float = 50.0) -> int:
	if not _has(p, "colonisthappypoints"):
		return -1

	if not (_known_nonneg(p.clans)
		and _known_nonneg(p.temperature)
		and _known_nonneg(p.factories)
		and _known_nonneg(p.mines)):
		return -1

	var old_h: float = float(p.colonisthappypoints)
	var clans: float = float(p.clans)
	var tax: float = float(clamp(tax_rate, 0, 100))
	var temp: float = float(p.temperature)
	var factories: float = float(p.factories)
	var mines: float = float(p.mines)

	var term: float = 1000.0 \
		- sqrt(clans) \
		- 80.0 * tax \
		- abs(base_temp - temp) * 3.0 \
		- (factories + mines) / 3.0

	var delta: int = _trunc(term / 100.0)
	var new_h: int = int(old_h) + delta

	if new_h > 100:
		new_h = 100
	return new_h

static func colonist_happiness_delta_next_turn(p: PlanetData, base_temp: float = 50.0) -> int:
	var new_h: int = colonist_happiness_next_turn(p, base_temp)
	if new_h < 0:
		return -999999
	return new_h - int(p.colonisthappypoints)

# ------------------------------------------------------------
# Native happiness
# ------------------------------------------------------------

static func native_race_bonus(p: PlanetData) -> int:
	# Client/host style: Avians give +10
	return 10 if int(p.nativetype) == 4 else 0

static func native_happiness_next_turn(
	p: PlanetData,
	nebula_bonus: int = 0,
	combat_penalty: int = 0
) -> int:
	return native_happiness_next_turn_with_tax(p, int(p.nativetaxrate), nebula_bonus, combat_penalty)

static func native_happiness_next_turn_with_tax(
	p: PlanetData,
	tax_rate: int,
	nebula_bonus: int = 0,
	combat_penalty: int = 0
) -> int:
	if String(p.nativeracename) == "none":
		return -1
	if not _has(p, "nativehappypoints"):
		return -1

	if not (_known_nonneg(p.nativeclans)
		and _known_nonneg(p.factories)
		and _known_nonneg(p.mines)
		and _known_nonneg(p.nativegovernment)):
		return -1

	var old_h: float = float(p.nativehappypoints)
	var nclans: float = float(p.nativeclans)
	var tax: float = float(clamp(tax_rate, 0, 100))
	var factories: float = float(p.factories)
	var mines: float = float(p.mines)
	var gov_level: int = int(p.nativegovernment)

	var term: float = 1000.0 \
		- sqrt(nclans) \
		- (tax * 85.0) \
		- float(_trunc((factories + mines) / 2.0)) \
		- (50.0 * (10.0 - float(gov_level)))

	var delta_core: int = _trunc(term / 100.0)
	var delta_total: int = delta_core + native_race_bonus(p) + nebula_bonus - combat_penalty

	var new_h: int = int(old_h) + delta_total
	if new_h > 100:
		new_h = 100
	return new_h

static func native_happiness_delta_next_turn(
	p: PlanetData,
	nebula_bonus: int = 0,
	combat_penalty: int = 0
) -> int:
	var new_h: int = native_happiness_next_turn(p, nebula_bonus, combat_penalty)
	if new_h < 0:
		return -999999
	return new_h - int(p.nativehappypoints)

# ------------------------------------------------------------
# Colonist tax
# Client-style:
# round(tax * clans / 1000), then apply race bonus
# ------------------------------------------------------------

static func colonist_tax_mc(p: PlanetData, tax_rate: int, owner_race_id: int) -> int:
	if int(p.colonisthappypoints) <= 30:
		return 0

	var clans: int = int(p.clans)
	if clans <= 0:
		return 0

	var tax_i: int = clamp(tax_rate, 0, 100)
	var col_tax: int = int(round(float(tax_i) * float(clans) / 1000.0))

	# Federation bonus
	var tax_bonus: int = 2 if owner_race_id == 1 else 1
	col_tax = int(floor(float(col_tax) * float(tax_bonus)))

	if col_tax > 5000:
		col_tax = 5000

	return max(col_tax, 0)

# ------------------------------------------------------------
# Native tax
# Exact client snippet style:
# round(tax * nativeTaxValue / 100 * nativeclans / 1000)
# cap by colonists first, then insectoids x2, then 5000 cap
# nativetaxvalue is already present in the turn json
# ------------------------------------------------------------

static func native_tax_mc(p: PlanetData, native_tax_rate: int, owner_race_id: int) -> int:
	if int(p.nativehappypoints) <= 30:
		return 0

	var native_type: int = int(p.nativetype)

	# Amorphous
	if native_type == 5:
		return 0

	var col_clans: int = int(p.clans)
	if col_clans <= 0:
		return 0

	var native_clans: int = int(p.nativeclans)
	if native_clans <= 0:
		return 0

	var tax_i: int = clamp(native_tax_rate, 0, 100)

	# Cyborg/Borg cap
	if owner_race_id == 6 and tax_i > 20:
		tax_i = 20

	# This value is already supplied by the client/turn data and matches the JS formula.
	var native_tax_value: float = float(p.nativetaxvalue)

	var val: int = int(round(
		float(tax_i) * native_tax_value / 100.0 * float(native_clans) / 1000.0
	))

	# Collector cap first
	if val > col_clans:
		val = col_clans

	# Insectoids double after collector cap
	if native_type == 6:
		val *= 2

	if val > 5000:
		val = 5000

	return max(val, 0)

# ------------------------------------------------------------
# Colonist max population / growth
# Client-aligned standard formulas
# ------------------------------------------------------------

static func _colonist_max_most_formula(temp: int) -> int:
	var t: int = clamp(temp, 0, 100)

	if t > 84:
		return int(floor((20099.9 - 200.0 * float(t)) / 10.0))
	elif t < 15:
		return int(floor((299.9 + 200.0 * float(t)) / 10.0))
	else:
		return max(0, int(round(sin(_PI_APPROX * (100.0 - float(t)) / 100.0) * 100000.0)))

static func colonist_growth_possible_most(temp: int, col_happy: int, is_planetoid: bool) -> bool:
	if is_planetoid:
		return false
	if col_happy < 70:
		return false
	return temp >= 15 and temp <= 84

static func colonist_max_clans_most(temp: int) -> int:
	return _colonist_max_most_formula(clamp(temp, 0, 100))

static func colonist_max_clans(
	temp: int,
	owner_race_id: int,
	crystal_desert_advantage: bool = true,
	is_planetoid: bool = false,
	has_mining_station: bool = false,
	burrow_size: int = 0,
	native_type: int = 0,
	native_clans: int = 0
) -> int:
	var t: int = clamp(temp, 0, 100)
	var max_supported: int = 0

	if owner_race_id == 7:
		# Crystals
		if crystal_desert_advantage:
			max_supported = t * 1000
		else:
			max_supported = _colonist_max_most_formula(t)
	else:
		max_supported = _colonist_max_most_formula(t)

		# Horwasp slot if present in a classic Nu-compatible game
		if owner_race_id == 12:
			max_supported *= 3

	# Planetoids
	if is_planetoid:
		max_supported = 500 if has_mining_station else 0

	# Fascists/Fury, Robots, Rebels, Colonies minimum 60 on hot planets
	if owner_race_id == 4 or owner_race_id == 9 or owner_race_id == 10 or owner_race_id == 11:
		if t > 80:
			max_supported = max(max_supported, 60)

	# Rebel arctic advantage
	if owner_race_id == 10 and t <= 19:
		max_supported = max(max_supported, 90000)

	# Horwasp burrow protection
	if owner_race_id == 12:
		max_supported = max(max_supported, burrow_size)

	# Client snippet special case: nativetype 11 boosts max pop by 1.5
	if native_type == 11 and native_clans > 0:
		max_supported = int(round(float(max_supported) * 1.5))

	return max_supported

static func colonist_is_maxed(
	p: PlanetData,
	owner_race_id: int,
	crystal_desert_advantage: bool = true,
	is_planetoid: bool = false,
	has_mining_station: bool = false
) -> bool:
	var clans: int = int(p.clans)
	if clans <= 0:
		return false

	var max_c: int = colonist_max_clans(
		int(p.temperature),
		owner_race_id,
		crystal_desert_advantage,
		is_planetoid,
		has_mining_station,
		int(p.burrowsize),
		int(p.nativetype),
		int(p.nativeclans)
	)

	if max_c <= 0:
		return false

	return clans >= max_c

static func colonist_growth_clans_most(
	temp: int,
	col_clans: int,
	col_tax_rate: int,
	col_happy: int,
	is_planetoid: bool
) -> int:
	if col_clans <= 0:
		return 0
	if not colonist_growth_possible_most(temp, col_happy, is_planetoid):
		return 0

	var max_pop: int = colonist_max_clans_most(temp)
	if max_pop > 0 and col_clans >= max_pop:
		return 0

	var t: int = clamp(temp, 0, 100)
	var tax: int = clamp(col_tax_rate, 0, 100)

	var g: int = 0
	if t >= 15 and t <= 84:
		g = int(round(
			sin(_PI_APPROX * (100.0 - float(t)) / 100.0) *
			(float(col_clans) / 20.0) *
			(5.0 / (float(tax) + 5.0))
		))

	if col_clans > 66000:
		g = int(round(float(g) / 2.0))

	if g < 0:
		g = 0

	if max_pop > 0 and col_clans + g > max_pop:
		g = max_pop - col_clans

	if g < 0:
		g = 0

	return g

static func colonist_min_to_grow_most(temp: int) -> int:
	var t: int = clamp(temp, 0, 100)
	if t < 15 or t > 84:
		return -1

	var clans: int = 1
	while clans <= 1000:
		var g: int = colonist_growth_clans_most(t, clans, 0, 70, false)
		if g >= 1:
			return clans
		clans += 1
	return -1

static func colonist_min_to_grow_amorph_most(temp: int) -> int:
	var t: int = clamp(temp, 0, 100)
	if t < 15 or t > 84:
		return -1

	var clans: int = 1
	while clans <= 200000:
		var g: int = colonist_growth_clans_most(t, clans, 0, 70, false)
		if g >= 6:
			return clans
		clans += 1
	return -1

# ------------------------------------------------------------
# Native max population / growth
# ------------------------------------------------------------

func native_max_clans(p: PlanetData) -> int:
	if String(p.nativeracename) == "none":
		return 0

	if not _known_nonneg(p.temperature):
		return -1

	var t: float = float(p.temperature)

	# Siliconoids
	if int(p.nativetype) == 9 or String(p.nativeracename) == "Siliconoid":
		var max_si: int = int(round(t * 1000.0))
		if max_si < 0:
			max_si = 0
		return max_si

	var max_other: int = int(round(sin(_PI_APPROX * (100.0 - t) / 100.0) * 150000.0))
	if max_other < 0:
		max_other = 0
	return max_other

static func native_is_maxed(p: PlanetData) -> bool:
	if String(p.nativeracename) == "none":
		return false

	var current: int = int(p.nativeclans)
	if current <= 0:
		return false

	var max_n: int = PlanetMath.new().native_max_clans(p)
	if max_n <= 0:
		return false

	return current >= max_n

func native_growth_clans(p: PlanetData, native_tax_rate: int, owner_race_id: int) -> int:
	if String(p.nativeracename) == "none":
		return 0

	# must be colonized
	if int(p.ownerid) <= 0:
		return 0

	if not _has(p, "nativehappypoints"):
		return -1

	if not (_known_nonneg(p.nativeclans)
		and _known_nonneg(p.temperature)):
		return -1

	var happy_after_tax: int = native_happiness_next_turn_with_tax(p, native_tax_rate)
	if happy_after_tax < 70:
		return 0

	var nclans: int = int(p.nativeclans)
	if nclans <= 0:
		return 0

	var cap: int = native_max_clans(p)
	if cap >= 0 and nclans > cap:
		return 0

	var tax_i: int = clamp(native_tax_rate, 0, 100)
	var t: float = float(p.temperature)

	var growth: int = 0

	if int(p.nativetype) == 9 or String(p.nativeracename) == "Siliconoid":
		growth = int(round(
			(t / 100.0) *
			(float(nclans) / 25.0) *
			(5.0 / (float(tax_i) + 5.0))
		))
	else:
		growth = int(round(
			sin(_PI_APPROX * (100.0 - t) / 100.0) *
			(float(nclans) / 25.0) *
			(5.0 / (float(tax_i) + 5.0))
		))

	if nclans > 66000 and owner_race_id != 12:
		growth = int(round(float(growth) / 2.0))

	# client snippet special case:
	# Horwasp-owned planets with Avian natives grow +25%
	if owner_race_id == 12 and int(p.nativetype) == 4:
		growth = int(floor(float(growth) * 1.25))

	if growth < 0:
		growth = 0

	return growth

# ------------------------------------------------------------
# Supplies
# ------------------------------------------------------------

func bovinoid_supply_contribution(p: PlanetData) -> int:
	# Bovinoid = nativetype 2 in classic planets data
	if int(p.nativetype) != 2 and String(p.nativeracename) != "Bovinoid":
		return 0

	if not (_known_nonneg(p.nativeclans) and _known_nonneg(p.clans)):
		return 0

	var native_clans: int = int(p.nativeclans)
	var col_clans: int = int(p.clans)

	var possible: int = int(native_clans / 100)
	return min(possible, col_clans)

func supplies_produced_next_turn(p: PlanetData) -> int:
	if not _known_nonneg(p.factories):
		return -1

	var factories: int = int(p.factories)
	var bov_sup: int = bovinoid_supply_contribution(p)

	return factories + bov_sup

# ------------------------------------------------------------
# Mining
# Standard/default rates
# ------------------------------------------------------------

func _race_mining_rate(owner_race_id: int) -> int:
	match owner_race_id:
		1: return 70   # Feds
		2: return 200  # Lizards
		_: return 100

func _native_mining_multiplier_int(p: PlanetData) -> int:
	# Reptilian natives
	return 2 if int(p.nativetype) == 3 or String(p.nativeracename) == "Reptilian" else 1

func mined_kt(
	mines: int,
	density_pct: int,
	ground_kt: int,
	owner_race_id: int,
	is_pleasure_planets_active: bool,
	native_rf: int
) -> int:
	if mines < 0 or density_pct < 0 or ground_kt < 0:
		return -1

	var rmr: int = _race_mining_rate(owner_race_id)

	# Mining_rate = ROUND(RaceMiningRate * Density / 100) * RF
	var rate_step: int = int(round(float(rmr) * float(density_pct) / 100.0))
	var mining_rate: int = rate_step * max(native_rf, 1)

	# Max_minerals_mined = TRUNC(Mining_rate * Mine_count / 100)
	var max_mined: int = int(floor(float(mining_rate) * float(mines) / 100.0))

	if is_pleasure_planets_active:
		max_mined = int(floor(float(max_mined) * 0.5))

	if max_mined < 0:
		max_mined = 0
	if max_mined > ground_kt:
		max_mined = ground_kt

	return max_mined

func planet_mining_neut(p: PlanetData, owner_race_id: int, is_pleasure_planets_active: bool = false) -> int:
	if not (_known_nonneg(p.mines) and _known_nonneg(p.densityneutronium) and _known_nonneg(p.groundneutronium)):
		return -1
	var rf: int = _native_mining_multiplier_int(p)
	return mined_kt(
		_to_int(p.mines),
		_to_int(p.densityneutronium),
		_to_int(p.groundneutronium),
		owner_race_id,
		is_pleasure_planets_active,
		rf
	)

func planet_mining_trit(p: PlanetData, owner_race_id: int, is_pleasure_planets_active: bool = false) -> int:
	if not (_known_nonneg(p.mines) and _known_nonneg(p.densitytritanium) and _known_nonneg(p.groundtritanium)):
		return -1
	var rf: int = _native_mining_multiplier_int(p)
	return mined_kt(
		_to_int(p.mines),
		_to_int(p.densitytritanium),
		_to_int(p.groundtritanium),
		owner_race_id,
		is_pleasure_planets_active,
		rf
	)

func planet_mining_dura(p: PlanetData, owner_race_id: int, is_pleasure_planets_active: bool = false) -> int:
	if not (_known_nonneg(p.mines) and _known_nonneg(p.densityduranium) and _known_nonneg(p.groundduranium)):
		return -1
	var rf: int = _native_mining_multiplier_int(p)
	return mined_kt(
		_to_int(p.mines),
		_to_int(p.densityduranium),
		_to_int(p.groundduranium),
		owner_race_id,
		is_pleasure_planets_active,
		rf
	)

func planet_mining_moly(p: PlanetData, owner_race_id: int, is_pleasure_planets_active: bool = false) -> int:
	if not (_known_nonneg(p.mines) and _known_nonneg(p.densitymolybdenum) and _known_nonneg(p.groundmolybdenum)):
		return -1
	var rf: int = _native_mining_multiplier_int(p)
	return mined_kt(
		_to_int(p.mines),
		_to_int(p.densitymolybdenum),
		_to_int(p.groundmolybdenum),
		owner_race_id,
		is_pleasure_planets_active,
		rf
	)
