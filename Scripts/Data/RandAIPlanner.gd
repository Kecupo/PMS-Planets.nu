extends Node
class_name RandAIPlanner

const CYBORG_RACE_ID: int = 6


static func apply_to_planets(
	_game_id: int,
	_cur_turn: int,
	owner_race_id: int,
	my_planets: Array,
	cfg: Node,
	orders_store: Node,
	_planet_math: Node,
	rng: RandomNumberGenerator
) -> void:
	GameState.begin_batch_changes()

	# Global FC operations first
	_apply_fc_special_case(my_planets, cfg, rng)
	_apply_fc_randomize_others(my_planets, cfg, rng)

	for p in my_planets:
		if p == null:
			continue

		var planet_id: int = int(p.planet_id)

		# Safety: only own planets
		if int(p.ownerid) != GameState.my_player_id:
			continue

		# Only manage planets flagged as auto-managed
		if not orders_store.is_auto_managed(planet_id):
			continue

		# -------------------------
		# Native tax
		# -------------------------
		var nat_tax: int = _calculate_native_tax(p, cfg, owner_race_id)

		# -------------------------
		# Colonist tax
		# -------------------------
		var col_tax: int = _calculate_colonist_tax(p, cfg, owner_race_id)

		col_tax = PlanetMath.colonist_tax_rate_for_planet_income_cap(
			p,
			col_tax,
			nat_tax,
			owner_race_id
		)

		if nat_tax != int(p.nativetaxrate):
			GameState.set_planet_native_taxrate(planet_id, nat_tax)
		if col_tax != int(p.colonisttaxrate):
			GameState.set_planet_colonist_taxrate(planet_id, col_tax)

		_apply_planet_build_targets(
			p,
			cfg,
			_cur_turn,
			owner_race_id,
			nat_tax
		)

	GameState.end_batch_changes()


static func apply_to_planets_async(
	_game_id: int,
	_cur_turn: int,
	owner_race_id: int,
	my_planets: Array,
	cfg: Node,
	orders_store: Node,
	_planet_math: Node,
	rng: RandomNumberGenerator,
	progress_callback: Callable = Callable()
) -> Dictionary:
	var result: Dictionary = {
		"success": true,
		"processed": 0,
		"managed": 0,
		"changed": 0,
		"message": ""
	}

	GameState.begin_batch_changes()

	# Global FC operations first
	_apply_fc_special_case(my_planets, cfg, rng)
	_apply_fc_randomize_others(my_planets, cfg, rng)

	var total: int = my_planets.size()
	for i in range(total):
		var p = my_planets[i]
		if p == null:
			continue

		var planet_id: int = int(p.planet_id)
		result["processed"] = int(result["processed"]) + 1

		if int(p.ownerid) != GameState.my_player_id:
			continue

		if not orders_store.is_auto_managed(planet_id):
			continue

		var old_nat_tax: int = int(p.nativetaxrate)
		var old_col_tax: int = int(p.colonisttaxrate)
		var nat_tax: int = _calculate_native_tax(p, cfg, owner_race_id)
		var col_tax: int = _calculate_colonist_tax(p, cfg, owner_race_id)

		col_tax = PlanetMath.colonist_tax_rate_for_planet_income_cap(
			p,
			col_tax,
			nat_tax,
			owner_race_id
		)

		if nat_tax != old_nat_tax:
			GameState.set_planet_native_taxrate(planet_id, nat_tax)
		if col_tax != old_col_tax:
			GameState.set_planet_colonist_taxrate(planet_id, col_tax)

		var targets_changed: bool = _apply_planet_build_targets(
			p,
			cfg,
			_cur_turn,
			owner_race_id,
			nat_tax
		)

		result["managed"] = int(result["managed"]) + 1
		if nat_tax != old_nat_tax or col_tax != old_col_tax or targets_changed:
			result["changed"] = int(result["changed"]) + 1

		if i % 10 == 0:
			_emit_progress(progress_callback, i + 1, total)
			var tree: SceneTree = Engine.get_main_loop() as SceneTree
			if tree != null:
				await tree.process_frame

	GameState.end_batch_changes()
	_emit_progress(progress_callback, total, total)
	result["message"] = "Success: managed %d planets, changed %d." % [
		int(result["managed"]),
		int(result["changed"])
	]
	return result


static func _apply_planet_build_targets(
	p: PlanetData,
	cfg: RandAI_Config,
	cur_turn: int,
	owner_race_id: int,
	planned_native_tax: int
) -> bool:
	var target_mines: int = -1
	var target_factories: int = -1
	var target_defense: int = -1

	if bool(cfg.calc_optimal_factories_mines):
		var turns: int = _target_mining_turns(cfg, cur_turn)
		var current_mines: int = max(0, int(p.mines))
		var current_factories: int = max(0, int(p.factories))
		var max_mines_v: int = max(current_mines, Planet_Math.max_mines(p))
		var max_factories_v: int = max(current_factories, Planet_Math.max_factories(p))
		target_mines = clamp(
			_required_mines_to_deplete_planet(p, owner_race_id, turns),
			current_mines,
			max_mines_v
		)
		target_factories = max(current_factories, max_factories_v)

		if _has_taxable_natives(p) and owner_race_id != CYBORG_RACE_ID:
			var balanced: Dictionary = _balance_native_planet_build_targets(
				p,
				target_mines,
				target_factories,
				planned_native_tax
			)
			target_mines = int(balanced.get("mines", target_mines))
			target_factories = int(balanced.get("factories", target_factories))

	if bool(cfg.build_defense_enabled):
		var current_defense: int = max(0, int(p.defense))
		var max_defense_v: int = max(current_defense, Planet_Math.max_defense(p))
		var desired_defense: int = max_defense_v
		if int(cfg.planet_defense_build_mode) == RandAI_Config.PlanetDefenseBuildMode.BUILD_21:
			desired_defense = min(21, max_defense_v)
		target_defense = max(current_defense, desired_defense)

	if target_mines < 0 and target_factories < 0 and target_defense < 0:
		return false

	return GameState.set_planet_building_targets(
		int(p.planet_id),
		target_mines,
		target_factories,
		target_defense
	)


static func _target_mining_turns(cfg: RandAI_Config, cur_turn: int) -> int:
	if int(cfg.planet_mining_target_mode) == RandAI_Config.PlanetMiningTargetMode.TO_TURN:
		return max(1, int(cfg.planet_mining_to_turn) - cur_turn)
	return max(1, int(cfg.planet_mining_in_turns))


static func _required_mines_to_deplete_planet(p: PlanetData, owner_race_id: int, turns: int) -> int:
	var required: int = int(p.mines)
	required = max(required, _required_mines_for_mineral(
		int(p.groundneutronium),
		int(p.densityneutronium),
		owner_race_id,
		_native_mining_multiplier_int(p),
		turns
	))
	required = max(required, _required_mines_for_mineral(
		int(p.groundtritanium),
		int(p.densitytritanium),
		owner_race_id,
		_native_mining_multiplier_int(p),
		turns
	))
	required = max(required, _required_mines_for_mineral(
		int(p.groundduranium),
		int(p.densityduranium),
		owner_race_id,
		_native_mining_multiplier_int(p),
		turns
	))
	required = max(required, _required_mines_for_mineral(
		int(p.groundmolybdenum),
		int(p.densitymolybdenum),
		owner_race_id,
		_native_mining_multiplier_int(p),
		turns
	))
	return required


static func _required_mines_for_mineral(
	ground_kt: int,
	density_pct: int,
	owner_race_id: int,
	native_multiplier: int,
	turns: int
) -> int:
	if ground_kt <= 0:
		return 0
	if density_pct <= 0 or turns <= 0:
		return 0

	var rate_step: int = int(round(float(_race_mining_rate(owner_race_id)) * float(density_pct) / 100.0))
	var mining_rate: int = rate_step * max(native_multiplier, 1)
	if mining_rate <= 0:
		return 0

	return int(ceil(float(ground_kt) * 100.0 / (float(mining_rate) * float(turns))))


static func _race_mining_rate(owner_race_id: int) -> int:
	match owner_race_id:
		1:
			return 70
		2:
			return 200
		_:
			return 100


static func _native_mining_multiplier_int(p: PlanetData) -> int:
	return 2 if int(p.nativetype) == 3 or String(p.nativeracename) == "Reptilian" else 1


static func _has_taxable_natives(p: PlanetData) -> bool:
	if p == null:
		return false
	if int(p.nativeclans) <= 0:
		return false
	if int(p.clans) <= 0:
		return false
	if int(p.nativetype) == 5:
		return false
	if String(p.nativeracename).strip_edges().to_lower() == "none":
		return false
	if String(p.nativeracename).strip_edges().to_lower() == "amorphous":
		return false
	return true


static func _balance_native_planet_build_targets(
	p: PlanetData,
	target_mines: int,
	target_factories: int,
	planned_native_tax: int
) -> Dictionary:
	var current_mines: int = max(0, int(p.mines))
	var current_factories: int = max(0, int(p.factories))
	var native_clans_for_balance: int = _native_balance_clans(p)
	var mines_v: int = max(target_mines, current_mines)
	var factories_v: int = max(target_factories, current_factories)

	if _is_bovinoid(p):
		var bov_supplies: int = min(int(native_clans_for_balance / 100), max(0, int(p.clans)))
		factories_v = max(current_factories, factories_v - bov_supplies)

	while factories_v > current_factories and _native_happiness_for_buildings(p, native_clans_for_balance, mines_v, factories_v, planned_native_tax) < 70:
		factories_v -= 1

	while mines_v > current_mines and _native_happiness_for_buildings(p, native_clans_for_balance, mines_v, factories_v, planned_native_tax) < 70:
		mines_v -= 1

	return {
		"mines": mines_v,
		"factories": factories_v
	}


static func _native_balance_clans(p: PlanetData) -> int:
	var max_native: int = Planet_Math.native_max_clans(p)
	if max_native <= 0:
		return max(0, int(p.nativeclans))
	return max(max_native, int(p.nativeclans))


static func _is_bovinoid(p: PlanetData) -> bool:
	return int(p.nativetype) == 2 or String(p.nativeracename) == "Bovinoid"


static func _native_happiness_for_buildings(
	p: PlanetData,
	native_clans: int,
	mines: int,
	factories: int,
	native_tax_rate: int
) -> int:
	if String(p.nativeracename) == "none":
		return 100
	if not p.raw.has("nativehappypoints"):
		return 100

	var term: float = 1000.0 \
		- sqrt(float(max(0, native_clans))) \
		- (float(clamp(native_tax_rate, 0, 100)) * 85.0) \
		- float(int((max(0, factories) + max(0, mines)) / 2)) \
		- (50.0 * (10.0 - float(max(0, int(p.nativegovernment)))))

	var delta_core: int = int(term / 100.0)
	var delta_total: int = delta_core + PlanetMath.native_race_bonus(p)
	var new_h: int = int(p.nativehappypoints) + delta_total
	return min(new_h, 100)


static func _emit_progress(progress_callback: Callable, value: int, total: int) -> void:
	if progress_callback.is_valid():
		progress_callback.call(value, total)


static func _calculate_native_tax(p: PlanetData, cfg: RandAI_Config, owner_race_id: int) -> int:
	if not _should_tax_natives(p, cfg):
		return 0

	var cyborg_tax: int = _cyborg_always_native_tax(p, cfg, owner_race_id)
	if cyborg_tax >= 0:
		return cyborg_tax

	var nat_cap_tax: int = _native_cap_tax(p, cfg, owner_race_id)
	if nat_cap_tax >= 0:
		return nat_cap_tax
	return _choose_tax_natives(p, cfg, owner_race_id)


static func _calculate_colonist_tax(p: PlanetData, cfg: RandAI_Config, owner_race_id: int) -> int:
	if not _should_tax_colonists(p, cfg, owner_race_id):
		return 0

	var col_cap_tax: int = _apply_colonist_cap_mode(p, cfg, owner_race_id)
	if col_cap_tax >= 0:
		return col_cap_tax
	return _choose_tax_colonists(p, cfg, owner_race_id)


# -----------------------------------------------------------------------------
# FC logic
# -----------------------------------------------------------------------------

static func _permute_case(rng: RandomNumberGenerator, s: String) -> String:
	var out: String = ""
	for i in range(s.length()):
		var ch: String = s.substr(i, 1)
		if (ch >= "A" and ch <= "Z") or (ch >= "a" and ch <= "z"):
			if rng.randi() % 2 == 0:
				out += ch.to_upper()
			else:
				out += ch.to_lower()
		else:
			out += ch
	return out


static func _apply_fc_special_case(my_planets: Array, cfg: Node, rng: RandomNumberGenerator) -> void:
	if not bool(cfg.permute_special_fcs_case):
		return

	var special: PackedStringArray = cfg.SPECIAL_FCS_CASE_DEFAULT

	for p in my_planets:
		if p == null:
			continue

		if int(p.ownerid) != GameState.my_player_id:
			continue

		var fc: String = String(p.friendlycode)
		var fc_u: String = fc.strip_edges().to_upper()

		if special.has(fc_u):
			var new_fc: String = _permute_case(rng, fc_u)
			if new_fc != fc:
				GameState.set_planet_friendlycode(int(p.planet_id), new_fc)


static func _apply_fc_randomize_others(my_planets: Array, cfg: Node, rng: RandomNumberGenerator) -> void:
	if not bool(cfg.randomize_other_fcs):
		return

	for p in my_planets:
		if p == null:
			continue

		if int(p.ownerid) != GameState.my_player_id:
			continue

		var fc: String = String(p.friendlycode).strip_edges().to_upper()

		# Protected FCs must never be changed
		if cfg.is_fc_protected(fc):
			continue

		var new_fc: String = _rand_fc(rng, cfg)
		GameState.set_planet_friendlycode(int(p.planet_id), new_fc)


static func _rand_fc(rng: RandomNumberGenerator, cfg: Node) -> String:
	const LETTERS: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	const ALNUM: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

	var specials: PackedStringArray = cfg.SPECIAL_FCS_CASE_DEFAULT

	for _i in range(200):
		var a: String = LETTERS[rng.randi_range(0, LETTERS.length() - 1)]
		var b: String = ALNUM[rng.randi_range(0, ALNUM.length() - 1)]
		var c: String = ALNUM[rng.randi_range(0, ALNUM.length() - 1)]
		var fc: String = a + b + c

		if specials.has(fc):
			continue

		if cfg.is_fc_protected(fc):
			continue

		return fc

	return "AAA"


# -----------------------------------------------------------------------------
# Native tax logic
# -----------------------------------------------------------------------------

static func _should_tax_natives(p: PlanetData, cfg: RandAI_Config) -> bool:
	if not bool(cfg.nat_tax_enabled):
		return false

	# No natives / no collectors
	if int(p.nativeclans) <= 0:
		return false
	if int(p.clans) <= 0:
		return false

	# Amorphous never pay
	if int(p.nativetype) == 5:
		return false
	if String(p.nativeracename).strip_edges().to_lower() == "amorphous":
		return false

	return true


static func _choose_tax_natives(p: PlanetData, cfg: RandAI_Config, owner_race_id: int) -> int:
	if not _should_tax_natives(p, cfg):
		return 0

	# Nur Pulse-Tax, wenn sich der Planet bei Tax=0 bis nächste Runde auf 100 erholt
	var next_h0: int = PlanetMath.native_happiness_next_turn_with_tax(p, 0)
	if next_h0 < 100:
		return 0

	var target_next: int = 70

	# Growth Plus: tieferer Pulse
	if int(cfg.nat_tax_method) == RandAI_Config.TaxMethod.GROWTH_PLUS:
		target_next = 70 - PlanetMath.native_happiness_delta_next_turn(p)

	return _best_native_tax_for_target_happiness(p, target_next, owner_race_id)

static func _native_cap_tax(p: PlanetData, cfg: RandAI_Config, owner_race_id: int) -> int:
	if not bool(cfg.nat_tax_cap_enabled):
		return -1

	if not _should_tax_natives(p, cfg):
		return 0

	if not PlanetMath.native_is_maxed(p):
		return -1

	var target: int = int(cfg.nat_tax_happy_target)
	return _best_native_tax_for_target_happiness(p, target, owner_race_id)


static func _cyborg_always_native_tax(p: PlanetData, cfg: RandAI_Config, owner_race_id: int) -> int:
	if owner_race_id != CYBORG_RACE_ID:
		return -1

	if not bool(cfg.cyborg_always_tax_natives):
		return -1

	var target_next: int = 40
	if int(p.clans) >= int(p.nativeclans):
		target_next = -1000

	return _best_native_tax_for_target_happiness(p, target_next, owner_race_id)


static func _best_native_tax_for_target_happiness(p: PlanetData, target_next: int, owner_race_id: int) -> int:
	var best_tax: int = 0
	var best_mc: int = -1

	for t in range(0, 101):
		var next_h: int = PlanetMath.native_happiness_next_turn_with_tax(p, t)
		if next_h < target_next:
			continue

		var mc: int = PlanetMath.native_tax_mc(p, t, owner_race_id)

		if mc > best_mc:
			best_mc = mc
			best_tax = t
		elif mc == best_mc and t < best_tax:
			best_tax = t

	return best_tax


# -----------------------------------------------------------------------------
# Colonist tax logic
# -----------------------------------------------------------------------------

static func _should_tax_colonists(
	p: PlanetData,
	cfg: RandAI_Config,
	owner_race_id: int
) -> bool:
	if not bool(cfg.col_tax_enabled):
		return false

	if int(p.clans) <= 0:
		return false

	match int(cfg.col_tax_gate_mode):
		RandAI_Config.ColTaxGateMode.MIN_CLANS:
			return int(p.clans) >= int(cfg.col_tax_min_clans)

		RandAI_Config.ColTaxGateMode.MIN_INCOME:
			var mc: int = PlanetMath.colonist_tax_mc(p, 100, owner_race_id)
			return mc >= int(cfg.col_tax_min_income_mc)

	return false

static func _choose_tax_colonists(
	p: PlanetData,
	cfg: RandAI_Config,
	owner_race_id: int
) -> int:
	if not _should_tax_colonists(p, cfg, owner_race_id):
		return 0

	# Nur Pulse-Tax, wenn sich der Planet bei Tax=0 bis nächste Runde auf 100 erholt
	var next_h0: int = PlanetMath.colonist_happiness_next_turn_with_tax(p, 0)
	if next_h0 < 100:
		return 0

	var target_next: int = 70

	# Growth Plus: tieferer Pulse
	if int(cfg.col_tax_method) == RandAI_Config.TaxMethod.GROWTH_PLUS:
		target_next = 70 - PlanetMath.colonist_happiness_delta_next_turn(p)

	return _best_colonist_tax_for_target_happiness(p, target_next, owner_race_id)

static func _apply_colonist_cap_mode(
	p: PlanetData,
	cfg: RandAI_Config,
	owner_race_id: int
) -> int:
	if not bool(cfg.col_tax_cap_enabled):
		return -1

	if not PlanetMath.colonist_is_maxed(p, owner_race_id):
		return -1

	var target: int = int(cfg.col_tax_happy_target)
	return _best_colonist_tax_for_target_happiness(p, target, owner_race_id)


static func _best_colonist_tax_for_target_happiness(p: PlanetData, target_next: int, owner_race_id: int) -> int:
	var best_tax: int = 0
	var best_mc: int = -1

	for t in range(0, 101):
		var next_h: int = PlanetMath.colonist_happiness_next_turn_with_tax(p, t)
		if next_h < target_next:
			continue

		var mc: int = PlanetMath.colonist_tax_mc(p, t, owner_race_id)

		if mc > best_mc:
			best_mc = mc
			best_tax = t
		elif mc == best_mc and t < best_tax:
			best_tax = t

	return best_tax
