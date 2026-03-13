extends Node
class_name RandAIPlanner

static func apply_to_planets(
	game_id: int,
	cur_turn: int,
	owner_race_id: int,
	my_planets: Array,
	cfg: Node,
	orders_store: Node,
	planet_math: Node,
	rng: RandomNumberGenerator
) -> void:
	GameState.begin_batch_changes()
	_apply_fc_special_case(my_planets, cfg, rng)
	_apply_fc_randomize_others(my_planets, cfg, rng)

	for p in GameState.get_my_planets():
		var planet_id: int = int(p.planet_id)

		# only manage planets flagged as auto-managed
		if not orders_store.is_auto_managed(planet_id):
			continue

		# --- FC
		var fc_cfg: Dictionary = _call_dict(cfg, "fc_for_planet", [planet_id], {})
		if bool(fc_cfg.get("enabled", true)):
			var fc: String = _choose_fc(p, fc_cfg, rng)
			if fc != "":
				orders_store.set_friendly_code(game_id, planet_id, fc)

		# --- TAX
		var tax_cfg: Dictionary = _call_dict(cfg, "tax_for_planet", [planet_id], {})

		var n_cfg: Dictionary = _dict_get_dict(tax_cfg, "native_default", {})
		var c_cfg: Dictionary = _dict_get_dict(tax_cfg, "colonist_default", {})

		# planet overrides (if present)
		var n_ov: Dictionary = _dict_get_dict(tax_cfg, "native", {})
		if not n_ov.is_empty():
			n_cfg = n_ov

		var c_ov: Dictionary = _dict_get_dict(tax_cfg, "colonist", {})
		if not c_ov.is_empty():
			c_cfg = c_ov

		var nat_tax: int = 0
		if _should_tax_natives(p, cfg):
			var cap_tax:int = _native_cap_tax(p, cfg, owner_race_id)
			if cap_tax>=0:
				nat_tax = cap_tax
			else:
				nat_tax = _choose_tax_natives(p, cfg, owner_race_id)
		else:
			nat_tax = 0
		GameState.set_planet_native_taxrate(int(p.planet_id),nat_tax)
		var col_tax: int = 0
		if _should_tax_colonists(p, cfg, owner_race_id):
			var cap_tax: int = _apply_colonist_cap_mode(p, cfg, owner_race_id)
			if cap_tax >= 0:
				col_tax = cap_tax
			else:
				col_tax = _choose_tax_colonists(p, cfg, owner_race_id)
		else:
			col_tax = 0
		# nur eigene Planeten managen
		if int(p.ownerid) != GameState.my_player_id:
			continue

		GameState.set_planet_native_taxrate(planet_id, nat_tax)
		GameState.set_planet_colonist_taxrate(planet_id, col_tax)
	GameState.end_batch_changes()
# -----------------------------------------------------------------------------
# Strict helpers: avoid Variant inference
# -----------------------------------------------------------------------------

static func _dict_get_dict(d: Dictionary, key: String, default_dict: Dictionary) -> Dictionary:
	var v: Variant = d.get(key, null)
	if v is Dictionary:
		return v as Dictionary
	return default_dict

static func _call_dict(obj: Object, method: StringName, args: Array, default_dict: Dictionary) -> Dictionary:
	if obj == null or not obj.has_method(method):
		return default_dict
	var v: Variant = obj.callv(method, args)
	if v is Dictionary:
		return v as Dictionary
	return default_dict


# -----------------------------------------------------------------------------
# FC logic
# -----------------------------------------------------------------------------

static func _choose_fc(p, fc_cfg: Dictionary, rng: RandomNumberGenerator) -> String:
	var mode: String = String(fc_cfg.get("mode", "random"))
	if mode == "off":
		return ""

	var fc_current: String = String(p.friendlycode)
	var fc_upper: String = fc_current.to_upper()

	# protected list (case-insensitive)
	var protected_v: Variant = fc_cfg.get("protected", [])
	var protected: Array = protected_v as Array
	for x in protected:
		if String(x).to_upper() == fc_upper:
			return "" # do not change

	# case-only list (case-insensitive)
	var case_only_v: Variant = fc_cfg.get("case_only", [])
	var case_only: Array = case_only_v as Array
	for x2 in case_only:
		if String(x2).to_upper() == fc_upper:
			var vars: Array[String] = _case_variants3(fc_upper)
			return vars[rng.randi_range(0, vars.size() - 1)]

	# per-planet override mode
	if mode == "protected":
		return ""
	if mode == "case_only":
		var vars2: Array[String] = _case_variants3(fc_upper)
		return vars2[rng.randi_range(0, vars2.size() - 1)]

	# random from pool
	var pool_v: Variant = fc_cfg.get("pool", [])
	var pool: Array = pool_v as Array
	if pool.is_empty():
		return ""
	return String(pool[rng.randi_range(0, pool.size() - 1)])


static func _case_variants3(s: String) -> Array[String]:
	var u: String = s.to_upper()
	if u.length() != 3:
		return [s]

	var out: Array[String] = []
	for mask in range(8):
		var t: String = ""
		for i in range(3):
			var ch: String = u.substr(i, 1)
			t += (ch.to_lower() if ((mask >> i) & 1) == 1 else ch)
		out.append(t)
	return out


# -----------------------------------------------------------------------------
# TAX logic
# -----------------------------------------------------------------------------

static func _target_h(cur_turn: int, cfg: Dictionary) -> int:
	var mode: String = String(cfg.get("mode", "adaptive"))

	if mode == "growth-tax-plus":
		return int(cfg.get("target", 70))
	if mode == "down-to":
		return int(cfg.get("target", 40))

	# adaptive
	var start_target: int = int(cfg.get("start_target", 85))
	var end_target: int = int(cfg.get("end_target", 55))
	var deadline_turn: int = int(cfg.get("deadline_turn", 0))
	if deadline_turn <= 0:
		return start_target

	var remaining: int = max(deadline_turn - cur_turn, 0)
	var window: float = float(cfg.get("ramp_window", 8.0))
	var u: float = clamp(1.0 - (float(remaining) / window), 0.0, 1.0)
	return int(round(lerp(float(start_target), float(end_target), u)))

static func _should_tax_natives(p: PlanetData, cfg: RandAI_Config) -> bool:
	if not cfg.nat_tax_cap_enabled:
		return false

	# Amorphous zahlen keine Steuern
	if String(p.nativeracename).to_lower() == "amorphous":
		return false

	# keine Natives -> nichts zu besteuern
	if int(p.nativeclans) <= 0:
		return false

	return true
	
static func _choose_tax_natives(p: PlanetData, cfg: RandAI_Config, owner_race_id: int) -> int:
	var current_h: int = int(p.nativehappypoints) # falls dein Feld anders heißt, anpassen!
	var target_next: int = 70

	# method: 0 growth, 1 growth_plus
	if int(cfg.nat_tax_method) == 1:
		var next_h0: int = Planet_Math.native_happiness_next_turn_with_tax(p, 0, owner_race_id)
		var delta0: int = next_h0 - current_h
		target_next = 70 - delta0
		target_next = clamp(target_next, 40, 100)

	var best_tax: int = 0
	for t in range(0, 101):
		var next_h: int = Planet_Math.native_happiness_next_turn_with_tax(p, t, owner_race_id)
		if next_h >= target_next:
			best_tax = t
	return best_tax

static func _native_cap_tax(p: PlanetData, cfg: RandAI_Config, owner_race_id: int) -> int:
	if not cfg.nat_tax_cap_enabled:
		return -1

	if not Planet_Math.native_is_maxed(p):
		return -1

	var target: int = int(cfg.nat_tax_happy_target)
	var best_tax: int = 0

	for t in range(0, 101):
		var next_h: int = Planet_Math.native_happiness_next_turn_with_tax(p, t, owner_race_id)
		if next_h >= target:
			best_tax = t

	return best_tax

static func _should_tax_colonists(
	p: PlanetData,
	cfg: RandAI_Config,
	owner_race_id: int
) -> bool:

	match cfg.col_tax_gate_mode:
		RandAI_Config.ColTaxGateMode.OFF:
			return false

		RandAI_Config.ColTaxGateMode.MIN_CLANS:
			return int(p.clans) >= cfg.col_tax_min_clans

		RandAI_Config.ColTaxGateMode.MIN_INCOME:
			var max_tax: int = 100
			var mc: int = Planet_Math.colonist_tax_mc(p, max_tax, owner_race_id)
			return mc >= cfg.col_tax_min_income_mc

	return false

static func _choose_tax_colonists(
	p: PlanetData,
	cfg: RandAI_Config,
	owner_race_id: int
) -> int:
	# GrowthTax: tax so that next turn happiness >= 70
	# GrowthTaxPlus: choose next turn happiness so that with tax=0 the following turn
	# returns to 70. Approximation using current state's tax=0 delta:
	# target_next = 70 - (next_h0 - current_h)
	var current_h: int = int(p.colonisthappypoints)
	var target_next: int = 70

	# cfg.col_tax_method: 0 = GrowthTax, 1 = GrowthTaxPlus
	if int(cfg.col_tax_method) == 1:
		var next_h0: int = Planet_Math.colonist_happiness_next_turn_with_tax(p, 0, owner_race_id)
		var delta0: int = next_h0 - current_h
		target_next = 70 - delta0

		# Safety: avoid riots zone; also keep reasonable bounds
		target_next = clamp(target_next, 40, 100)

	var best_tax: int = 0

	# Pick the highest tax that keeps next happiness >= target_next
	for t in range(0, 101):
		var next_h: int = Planet_Math.colonist_happiness_next_turn_with_tax(p, t, owner_race_id)
		if next_h >= target_next:
			best_tax = t

	return best_tax

static func _permute_case(rng: RandomNumberGenerator, s: String) -> String:
	var out: String = ""
	for i in range(s.length()):
		var ch: String = s.substr(i, 1)
		# Nur Buchstaben randomisieren; Ziffern bleiben wie sie sind
		if ch >= "A" and ch <= "Z" or ch >= "a" and ch <= "z":
			out += ch.to_upper() if rng.randi() % 2 == 0 else ch.to_lower()
		else:
			out += ch
	return out

static func _apply_fc_special_case(my_planets: Array, cfg: Node, rng: RandomNumberGenerator) -> void:
	if not cfg.permute_special_fcs_case:
		return

	var special: PackedStringArray = cfg.SPECIAL_FCS_CASE_DEFAULT

	for p in my_planets:
		var fc: String = String(p.friendlycode)
		var fc_u: String = fc.strip_edges().to_upper()

		if special.has(fc_u):
			var new_fc: String = _permute_case(rng, fc_u)
			if new_fc != fc:
				GameState.set_planet_friendlycode(int(p.planet_id), new_fc)
			
static func _apply_fc_randomize_others(my_planets: Array, cfg: Node, rng: RandomNumberGenerator) -> void:
	if not cfg.randomize_other_fcs:
		return

	for p in my_planets:
		var fc: String = String(p.friendlycode).strip_edges().to_upper()

		# wenn geschützt (prefix 1–3 oder specials), dann nicht ändern
		if cfg.is_fc_protected(fc):
			continue

		var new_fc: String = _rand_fc(rng, cfg)
		GameState.set_planet_friendlycode(int(p.planet_id), new_fc)

static func _rand_fc(rng: RandomNumberGenerator, cfg: Node) -> String:
	const LETTERS: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	const ALNUM: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

	# Fast lookup: specials
	var specials: PackedStringArray = cfg.SPECIAL_FCS_CASE_DEFAULT

	# Wir versuchen ein paar Mal; praktisch findet er immer schnell was
	for _i in range(200):
		var a: String = LETTERS[rng.randi_range(0, LETTERS.length() - 1)]
		var b: String = ALNUM[rng.randi_range(0, ALNUM.length() - 1)]
		var c: String = ALNUM[rng.randi_range(0, ALNUM.length() - 1)]
		var fc: String = a + b + c

		# 1) nie Special erzeugen
		if specials.has(fc):
			continue

		# 2) optional: nie etwas erzeugen, was durch Prefix-Regeln geschützt wäre
		# (z.B. wenn User "PB" in blacklist hat, sollen wir nicht PB7 erzeugen)
		if cfg.is_fc_protected(fc):
			continue

		return fc

	# Fallback (sollte praktisch nie passieren)
	return "AAA"

static func _apply_colonist_cap_mode(
	p: PlanetData,
	cfg: RandAI_Config,
	owner_race_id: int
) -> int:

	if not cfg.col_tax_cap_enabled:
		return -1

	if not Planet_Math.colonist_is_maxed(p, owner_race_id):
		return -1

	var target: int = cfg.col_tax_happy_target  # 70 oder 40
	var best_tax: int = 0

	for t in range(0, 101):
		var next_h: int = Planet_Math.colonist_happiness_next_turn_with_tax(
			p,
			t,
			owner_race_id
		)
		if next_h >= target:
			best_tax = t

	return best_tax
