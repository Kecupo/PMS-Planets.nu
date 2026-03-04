extends Node
class_name PlanetMath
# Godot 4.5.1
# Pure calculation helpers (no UI, no IO).
#
# -------------------------
# Helpers
# -------------------------
#
# ------------------------------------------------------------
# Colonists (Most races, non-Crystals): max pop, growth, min-to-grow
# Based on Planets.nu "Taxes, Happiness and Growth - Details"
# ------------------------------------------------------------

const _PI_APPROX: float = 3.14

static func colonist_growth_possible_most(
	temp: int,
	col_happy: int,
	is_planetoid: bool
) -> bool:
	if is_planetoid:
		return false
	if col_happy < 70:
		return false
	return temp >= 15 and temp <= 84


static func colonist_max_clans_most(temp: int) -> int:
	var t: int = clamp(temp, 0, 100)

	# For Birds, Cyborg, Empire, Federation, Lizards, Privateers (Most races)
	# <15: TRUNC((299.9 + 200*T)/10)
	# >84: TRUNC((20099.9 - 200*T)/10)
	# else: ROUND(SIN(3.14*(100-T)/100)*100000)
	# Source: Planets.nu taxes-details
	if t < 15:
		var v_cold: float = (299.9 + (200.0 * float(t))) / 10.0
		return int(floor(v_cold))
	if t > 84:
		var v_hot: float = (20099.9 - (200.0 * float(t))) / 10.0
		return int(floor(v_hot))

	var s: float = sin(_PI_APPROX * (100.0 - float(t)) / 100.0)
	var v_mid: float = round(s * 100000.0)
	var out: int = int(v_mid)
	if out < 0:
		out = 0
	return out


static func colonist_growth_clans_most(
	temp: int,
	col_clans: int,
	col_tax_rate: int,
	col_happy: int,
	is_planetoid: bool
) -> int:
	# Preconditions
	if col_clans <= 0:
		return 0
	if not colonist_growth_possible_most(temp, col_happy, is_planetoid):
		return 0

	var max_pop: int = colonist_max_clans_most(temp)
	# "The population will not grow if it exceeds the maximum population."
	if col_clans >= max_pop and max_pop > 0:
		return 0

	var t: int = clamp(temp, 0, 100)
	var tax: int = clamp(col_tax_rate, 0, 100)

	# Growth formula (non-crystals, 15..84):
	# ROUND( SIN(3.14*(100-T)/100) * (Clans)/20 * 5 / (Tax+5) )
	var s: float = sin(_PI_APPROX * (100.0 - float(t)) / 100.0)
	var base: float = s * (float(col_clans) / 20.0) * (5.0 / (float(tax) + 5.0))
	var g: int = int(round(base))

	# If more than 66,000 clans, growth is cut in half.
	if col_clans > 66000:
		g = int(floor(float(g) / 2.0))

	# Growth can't be negative here, but clamp anyway.
	if g < 0:
		g = 0

	# Also: population will not grow if it would exceed max pop
	# (i.e. cap the growth so next <= max)
	if max_pop > 0 and col_clans + g > max_pop:
		g = max(0, max_pop - col_clans)

	return g


static func colonist_min_to_grow_most(temp: int) -> int:
	# "Minimum clans required to get growth >= 1" assuming:
	# - temp 15..84
	# - tax=0
	# - happiness>=70
	# - no planetoid
	var t: int = clamp(temp, 0, 100)
	if t < 15 or t > 84:
		return -1

	# brute-force small search is cheap and matches ROUND behavior exactly
	var clans: int = 1
	while clans <= 1000:
		var g: int = colonist_growth_clans_most(t, clans, 0, 70, false)
		if g >= 1:
			return clans
		clans += 1
	return -1


static func colonist_min_to_grow_amorph_most(temp: int) -> int:
	# Amorphous eat at least 5 clans per turn,
	# so we need growth >= 6 for population to increase.
	# Source: Planets.nu taxes-details (Amorphous section)
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

static func colonist_max_clans(
	temp: int,
	owner_race_id: int,
	crystal_desert_advantage: bool = true,
	is_planetoid: bool = false,
	has_mining_station: bool = false
) -> int:
	var t: int = clamp(temp, 0, 100)

	# Planetoid special case (optional; you said you don't use it yet)
	if is_planetoid:
		return 500 if has_mining_station else 0

	# Race IDs in Planets.nu:
	# 1 Feds, 2 Lizards, 3 Birds, 4 Fascists, 5 Privateers, 6 Cyborg,
	# 7 Crystals, 8 Empire, 9 Robots, 10 Rebels, 11 Colonies
	# (Fury/Horwasp not in classic 11-race list; adjust if your data uses other ids)

	# Crystals
	if owner_race_id == 7:
		if crystal_desert_advantage:
			# Max = Temp * 1000  (Planets.nu standard with Crystal desert advantage)
			return t * 1000
		# If desert advantage is OFF, crystals behave like other colonists (host option).
		# => fall through to "most races" formula.

	# Rebels: max 90,000 if temp < 20; also min 60 on hot planets.
	if owner_race_id == 10:
		if t < 20:
			return 90000
		# Otherwise use "most races" but clamp to >= 60 on hot planets (>84 zone)
		var m_reb: int = _colonist_max_most_formula(t)
		if t > 84 and m_reb < 60:
			return 60
		return m_reb

	# Colonies/Fury/Robots: min 60 on hot planets.
	# Colonies id=11, Robots id=9. Fury depends on your schema (often campaign race / different id).
	if owner_race_id == 11 or owner_race_id == 9 or owner_race_id == 12:
		var m_cr: int = _colonist_max_most_formula(t)
		if t > 84 and m_cr < 60:
			return 60
		return m_cr

	# Default: "most races" formula
	return _colonist_max_most_formula(t)


static func _colonist_max_most_formula(t: int) -> int:
	# Birds, Cyborg, Empire, Federation, Lizards and Privateers:
	# >84: TRUNC((20099.9 - 200*T)/10)
	# <15: TRUNC((299.9 + 200*T)/10)
	# else: ROUND(SIN(3.14*(100-T)/100) * 100000)
	if t < 15:
		var v_cold: float = (299.9 + (200.0 * float(t))) / 10.0
		return int(floor(v_cold))
	if t > 84:
		var v_hot: float = (20099.9 - (200.0 * float(t))) / 10.0
		return int(floor(v_hot))

	var s: float = sin(_PI_APPROX * (100.0 - float(t)) / 100.0)
	var v_mid: float = round(s * 100000.0)
	var out: int = int(v_mid)
	return max(out, 0)

static func native_is_maxed(p: PlanetData) -> bool:
	if p.nativeracename == "none":
		return false
	var t: float = float(p.temperature)

	# Siliconoids special case
	if p.nativeracename == "Siliconoid":
		var max_si: int = int(round(t * 1000.0))
		if max_si < 0:
			max_si = 0
		if p.nativeclans >= max_si:
			return true

	# Others
	var angle: float = 3.14 * (100.0 - t) / 100.0
	var max_other: int = int(round(sin(angle) * 150000.0))
	if max_other < 0:
		max_other = 0
	if max_other >= p.nativeclans:
		return true
	else:
		return false
			
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

	var max_c: int = colonist_max_clans(int(p.temperature), owner_race_id, crystal_desert_advantage, is_planetoid, has_mining_station)
	if max_c <= 0:
		return false

	return clans >= max_c
	
static func colonist_is_maxed_most(p: PlanetData) -> bool:
	# Defensive: unknown/negative clans -> not maxed
	var clans: int = int(p.clans)
	if clans <= 0:
		return false

	var temp: int = int(p.temperature)
	var max_clans: int = colonist_max_clans_most(temp)

	# If max_clans is 0 (e.g. outside growth range in our model), treat as not maxed
	if max_clans <= 0:
		return false

	return clans >= max_clans
	
func _has(p: PlanetData, key: String) -> bool:
	return not p.raw.is_empty() and p.raw.has(key)

func _known_nonneg(v: float) -> bool:
	# For values that use -1 as "unknown" and should not be negative in normal play
	return v >= 0.0

func _trunc(x: float) -> int:
	# TRUNC = towards zero
	return int(x)

# -------------------------
# Government: Tax Efficiency (for later use in native tax)
# -------------------------
func native_government_tax_efficiency(gov_level: int) -> float:
	match gov_level:
		0: return 0.00
		1: return 0.20
		2: return 0.40
		3: return 0.60
		4: return 0.80
		5: return 1.00
		6: return 1.20
		7: return 1.40
		8: return 1.60
		9: return 1.80
		_: return 1.00

# -------------------------
# Production
# -------------------------
func supplies_produced_next_turn(p: PlanetData) -> int:
	if not _known_nonneg(p.factories):
		return -1
	return int(p.factories)

# -------------------------
# Colonist Happiness (Next Turn)
# -------------------------
func colonist_happiness_next_turn(p: PlanetData, base_temp: float = 50.0) -> int:
	if not _has(p, "colonisthappypoints"):
		return -1

	if not (_known_nonneg(p.clans)
		and _known_nonneg(p.colonisttaxrate)
		and _known_nonneg(p.temperature)
		and _known_nonneg(p.factories)
		and _known_nonneg(p.mines)):
		return -1

	var old_h: float = float(p.colonisthappypoints)
	var clans: float = float(p.clans)
	var tax: float = float(p.colonisttaxrate)
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

	# Cap at 100 (colonist happiness cannot exceed 100)
	if new_h > 100:
		new_h = 100
	return new_h


func colonist_happiness_next_turn_with_tax(p: PlanetData, tax_rate: int, base_temp: float = 50.0) -> int:
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


func colonist_happiness_delta_next_turn(p: PlanetData, base_temp: float = 50.0) -> int:
	var new_h: int = colonist_happiness_next_turn(p, base_temp)
	if new_h < 0:
		return -999999
	return new_h - int(p.colonisthappypoints)

# -------------------------
# Colonist Taxes (MegaCredits)
#
# If happiness > 30:
# Taxes = ColonistClans * ColonistTaxRate * RacialTaxModifier / 10
# Cap: max 5000 MC
# RacialTaxModifier: 2.0 for Solar Federation, else 1.0
# If happiness <= 30 -> taxes are 0
# -------------------------
func colonist_racial_tax_modifier(owner_race_id: int) -> float:
	return 2.0 if owner_race_id == 1 else 1.0

func colonist_tax_mc(p: PlanetData, colonist_tax_rate: int, owner_race_id: int) -> int:
	# happiness gate
	if int(p.colonisthappypoints) <= 30:
		return 0

	var col_clans: int = int(p.clans)
	if col_clans <= 0:
		return 0

	var tax_i: int = clamp(colonist_tax_rate, 0, 100)

	# racial modifier: Fed = 2.0, most others = 1.0
	var mod: float = 2.0 if owner_race_id == 1 else 1.0

	# Base formula with rounding (to match ingame last MCs)
	var mc_f: float = (float(col_clans) * float(tax_i) * mod) / 10.0
	var mc: int = int(round(mc_f*0.01))

	# cap
	if mc > 5000:
		mc = 5000

	return max(mc, 0)


# -------------------------
# Native Race Bonus (happiness)
# -------------------------
func native_race_bonus(p: PlanetData) -> int:
	return 10 if p.nativeracename == "Avian" else 0

# -------------------------
# Native Happiness (Next Turn)
# -------------------------
func native_happiness_next_turn(
	p: PlanetData,
	nebula_bonus: int = 0,
	combat_penalty: int = 0
	) -> int:
	if p.nativeracename == "none":
		return -1
	if not _has(p, "nativehappypoints"):
		return -1

	if not (_known_nonneg(p.nativeclans)
		and _known_nonneg(p.nativetaxrate)
		and _known_nonneg(p.factories)
		and _known_nonneg(p.mines)
		and _known_nonneg(p.nativegovernment)):
		return -1

	var old_h: float = float(p.nativehappypoints)
	var nclans: float = float(p.nativeclans)
	var tax: float = float(p.nativetaxrate)
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

func native_happiness_delta_next_turn(
	p: PlanetData,
	nebula_bonus: int = 0,
	combat_penalty: int = 0
	) -> int:
	var new_h: int = native_happiness_next_turn(p, nebula_bonus, combat_penalty)
	if new_h < 0:
		return -999999
	return new_h - int(p.nativehappypoints)
# 
#-------------------------
# Native Taxes (MegaCredits)
#
# If native happiness > 30:
# Taxes = NativeClans * NativeTaxRate * PlanetTaxEfficiency / 10
# Cap: max 5000 MC
# Notes (Planets.nu):
# - Insectoids: 2 MC per clan (i.e., double)
# - Amorphous: pay 0 (even though they can be taxed)
# - Cyborg: no additional revenue above 20% tax rate (income capped to rate=20)
# -------------------------
func native_tax_mc(p: PlanetData, native_tax_rate: int, owner_race_id: int) -> int:
	# gates
	if int(p.nativehappypoints) <= 30:
		return 0
	if String(p.nativeracename) == "Amorphous":
		return 0

	var col_clans: int = int(p.clans)
	if col_clans <= 0:
		return 0

	var native_clans: int = int(p.nativeclans)
	if native_clans <= 0:
		return 0

	var tax_i: int = clamp(native_tax_rate, 0, 100)

	# cyborg income cap
	if owner_race_id == 6 and tax_i > 20:
		tax_i = 20

	# insectoid collector factor
	var ifac: int = 2 if String(p.nativeracename) == "Insectoid" else 1

	# government efficiency as PERCENT (e.g. 20..180)
	var eff_pct: float = (native_government_tax_efficiency(int(p.nativegovernment)))

	# --- Core math ---
	# Base (your original formula) with rounding:
	# MC = Round( native_clans * tax% * eff% / 1000 )
	var base_mc_f: float = (float(native_clans) * float(tax_i) * float(eff_pct)) / 1000.0
	var base_mc: int = int(round(base_mc_f))

	# Collector cap
	var collector_cap: int = col_clans * ifac
	if base_mc > collector_cap:
		base_mc = collector_cap

	# Planet cap
	if base_mc > 5000:
		base_mc = 5000

	return max(base_mc, 0)

func native_happiness_next_turn_with_tax(
	p: PlanetData,
	tax_rate: int,
	nebula_bonus: int = 0,
	combat_penalty: int = 0
	) -> int:
	if p.nativeracename == "none":
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

# -------------------------
# Native Maximum Population (clans)
#
# Siliconoids:
#   Max = Temperature * 1000
# Other races:
#   Max = ROUND( SIN(3.14 * (100 - Temperature) / 100) * 150000 )
#
# Returns -1 if required data is unknown.
# -------------------------
func native_max_clans(p: PlanetData) -> int:
	# Need natives to make sense
	if p.nativeracename == "none":
		return 0

	# Temperature must be known
	if not _known_nonneg(p.temperature):
		return -1

	var t: float = float(p.temperature)

	# Siliconoids special case
	if p.nativeracename == "Siliconoid":
		var max_si: int = int(round(t * 1000.0))
		if max_si < 0:
			max_si = 0
		return max_si

	# Others
	var angle: float = 3.14 * (100.0 - t) / 100.0
	var max_other: int = int(round(sin(angle) * 150000.0))
	if max_other < 0:
		max_other = 0
	return max_other

# -------------------------
# Native Population Growth (clans / turn)
#
# Global rules:
# - No growth if happiness < 70
# - No growth on uncolonized planets (ownerid == 0)
# - If native clans > 66000, growth is halved unless colonists are Horwasp
# - No growth if at or over capacity
# - Full growth applies even if it pushes over capacity
#
# Siliconoids:
#   growth = ROUND( (Temp/100) * (NativeClans/25) * 5 / (Tax+5) )
# Other:
#   growth = ROUND( SIN(3.14*(100-Temp)/100) * (NativeClans/25) * 5 / (Tax+5) )
#
# Parameters:
# - native_tax_rate: effective tax rate (orders included)
# - owner_race_id: colonist race slot id (for Horwasp exception)
# Returns:
# - growth clans as int (>=0), or -1 if unknown inputs
# -------------------------
func native_growth_clans(p: PlanetData, native_tax_rate: int, owner_race_id: int) -> int:
	# Must have natives
	if p.nativeracename == "none":
		return 0

	# Must be colonized
	if int(p.ownerid) <= 0:
		return 0

	# Need happiness present (can be negative)
	if not _has(p, "nativehappypoints"):
		return -1

	# Required numeric inputs
	if not (_known_nonneg(p.nativeclans)
		and _known_nonneg(p.temperature)
		and _known_nonneg(p.nativegovernment)):
		return -1

	var happy: int = int(p.nativehappypoints)
	if happy < 70:
		return 0

	var nclans: float = float(p.nativeclans)
	if nclans <= 0.0:
		return 0

	# Capacity check
	var cap: int = native_max_clans(p)
	if cap >= 0 and int(nclans) >= cap:
		return 0

	var tax_i: int = clamp(native_tax_rate, 0, 100)
	var t: float = float(p.temperature)

	# Core multiplier (Siliconoids vs others)
	var base_factor: float
	if p.nativeracename == "Siliconoid":
		base_factor = (t / 100.0)
	else:
		var angle: float = 3.14 * (100.0 - t) / 100.0
		base_factor = sin(angle)

	# Formula:
	# ROUND( base_factor * (NativeClans/25) * 5 / (Tax+5) )
	var growth_f: float = base_factor * (nclans / 25.0) * 5.0 / (float(tax_i) + 5.0)
	var growth: int = int(round(growth_f))
	if growth < 0:
		growth = 0

	# 66,000+ halving unless Horwasp colonists
	# (Standard Horwasp id is 12)
	if int(nclans) > 66000 and owner_race_id != 12:
		growth = int(floor(float(growth) / 2.0))

	return growth

# -------------------------
# Max planet buildings based on colonist clans
# Mines:
#   clans <= 200: max = clans
#   clans > 200:  max = 200 + SQRT(clans - 200)
# Factories:
#   clans <= 100: max = clans
#   clans > 100:  max = 100 + SQRT(clans - 100)
# Defense:
#   clans <= 50:  max = clans
#   clans > 50:   max = 50 + SQRT(clans - 50)
#
# Note: We return int via truncation (towards zero).
# Returns -1 if clans unknown.
# -------------------------
func max_mines(p: PlanetData) -> int:
	if not _known_nonneg(p.clans):
		return -1
	var c: float = float(p.clans)
	if c <= 200.0:
		return int(c)
	return int(200.0 + sqrt(c - 200.0))

func max_factories(p: PlanetData) -> int:
	if not _known_nonneg(p.clans):
		return -1
	var c: float = float(p.clans)
	if c <= 100.0:
		return int(c)
	return int(100.0 + sqrt(c - 100.0))

func max_defense(p: PlanetData) -> int:
	if not _known_nonneg(p.clans):
		return -1
	var c: float = float(p.clans)
	if c <= 50.0:
		return int(c)
	return int(50.0 + sqrt(c - 50.0))

# -------------------------
# Mining output (kt / turn)
#
# Base:
#   mined = TRUNC( mines * density / 100 )
# Limited by available ground mineral (cannot mine more than ground).
#
# Modifiers:
# - Player race mining rate (host-configurable; we implement defaults)
#   Fed 70%, Lizards 200% by default. :contentReference[oaicite:4]{index=4}
# - Reptilian natives double mining. :contentReference[oaicite:5]{index=5}
# - Pleasure Planets campaign halves mined minerals. :contentReference[oaicite:6]{index=6}
#
# For now:
# - We implement player + reptilian natives + optional pleasure_planets flag.
# - Custom games can change race mining rates => later read from config.
# -------------------------

func _race_mining_rate(owner_race_id: int) -> int:
	match owner_race_id:
		1: return 70   # Feds
		2: return 200  # Lizards
		_: return 100  # Others

func _native_mining_multiplier_int(p: PlanetData) -> int:
	return 2 if String(p.nativeracename) == "Reptilian" else 1
	
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

	# Mining_rate = Round(RaceMiningRate * Density / 100) * RF
	var rate_step: int = int(round((float(rmr) * float(density_pct)) / 100.0))
	var mining_rate: int = rate_step * max(native_rf, 1)

	# Max_minerals_mined = Trunc(Mining_rate * Mine_count / 100)
	var max_mined: int = int(floor((float(mining_rate) * float(mines)) / 100.0))

	# Pleasure Planets halbieren Mining (wenn aktiv).
	# Wichtig: hier mit Trunc arbeiten (nicht round), sonst bekommst du wieder ±1 Effekte.
	if is_pleasure_planets_active:
		max_mined = int(floor(float(max_mined) * 0.5))

	if max_mined < 0:
		max_mined = 0
	if max_mined > ground_kt:
		max_mined = ground_kt

	return max_mined

# Convenience per mineral (uses planet fields)

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
func _to_int(v: Variant) -> int:
	if typeof(v) == TYPE_INT:
		return int(v)
	if typeof(v) == TYPE_FLOAT:
		return int(round(float(v)))  # oder floor(), je nachdem was semantisch passt
	return 0
