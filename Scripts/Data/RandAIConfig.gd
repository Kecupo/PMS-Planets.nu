extends Node
class_name RandAIConfig

var current_game_id: int = 0
var dirty: bool = false
var permute_special_fcs_case: bool = false
var cfg: Dictionary = {}
var fc_never_change_raw: String = ""  # vom User eingegebener Text
var randomize_other_fcs: bool = false # neue Checkbox
# --- Colonist tax config ---
enum ColTaxMode { OFF, MIN_CLANS, MIN_INCOME }
var col_tax_mode: int = ColTaxMode.MIN_CLANS
# -------------------------
# Colonist Tax Config (UI only for now)
# -------------------------

# Gate: 0 = OFF, 1 = MIN_CLANS, 2 = MIN_INCOME
var col_tax_gate_mode: int = 1

# Thresholds
var col_tax_min_clans: int = 10000
var col_tax_min_income_mc: int = 100

# Method: 0 = Growth Tax, 1 = Growth Tax Plus
var col_tax_method: int = 0

# Cap mode (when colonists are at max by temperature)
var col_tax_cap_enabled: bool = false

# Target happiness for cap mode (70 or 40)
var col_tax_happy_target: int = 70
const SPECIAL_FCS_CASE_DEFAULT: PackedStringArray = [
	"NUK", "ATT", "BUM","DMP",
	"PB0","PB1","PB2","PB3","PB4","PB5","PB6","PB7","PB8","PB9",
	"RB0","RB1","RB2","RB3","RB4","RB5","RB6","RB7","RB8","RB9"
]
# -------------------------
# Native Tax Config (UI + Planner)
# -------------------------

# Gate: 0 = OFF, 1 = MIN_CLANS, 2 = MIN_INCOME
var nat_tax_gate_mode: int = 1

# Method: 0 = Growth Tax, 1 = Growth Tax Plus
var nat_tax_method: int = 0

# Cap mode when natives are maxed
var nat_tax_cap_enabled: bool = false

# Target happiness for cap mode
var nat_tax_happy_target: int = 70

func load_for_game(game_id: int) -> void:
	GameStorage.ensure_game_dir(game_id)
	var path: String = GameStorage.rand_ai_config_path(game_id)
	var d: Dictionary = GameStorage.load_json(path)

	if d.is_empty():
		_apply_defaults()
		dirty = true
		save_for_game(game_id) # Default einmalig schreiben
		return

	_apply_from_dict(d)
	dirty = false

func save_for_game(game_id: int) -> void:
	if game_id <= 0:
		return
	GameStorage.ensure_game_dir(game_id)
	var path: String = GameStorage.rand_ai_config_path(game_id)
	GameStorage.save_json(path, _to_dict())
	dirty = false

func mark_dirty() -> void:
	dirty = true

func _apply_defaults() -> void:
	permute_special_fcs_case = false
	fc_never_change_raw = ""
	randomize_other_fcs = false
	col_tax_mode = ColTaxMode.MIN_CLANS
	col_tax_min_clans = 10000
	col_tax_min_income_mc = 100
	col_tax_gate_mode = 1
	col_tax_min_clans = 10000
	col_tax_min_income_mc = 100
	col_tax_method = 0
	col_tax_cap_enabled = false
	col_tax_happy_target = 70
	nat_tax_gate_mode = 1
	nat_tax_method = 0
	nat_tax_cap_enabled = false
	nat_tax_happy_target = 70
	
func _apply_from_dict(d: Dictionary) -> void:
	permute_special_fcs_case = _read_bool(d, "permute_special_fcs_case", false)
	fc_never_change_raw = _read_string(d, "fc_never_change_raw", "")
	randomize_other_fcs = _read_bool(d, "randomize_other_fcs", false)

	col_tax_gate_mode = _read_int(d, "col_tax_gate_mode", 1)
	col_tax_min_clans = _read_int(d, "col_tax_min_clans", 10000)
	col_tax_min_income_mc = _read_int(d, "col_tax_min_income_mc", 100)

	col_tax_method = _read_int(d, "col_tax_method", 0)
	col_tax_mode = _read_bool(d, "col_tax_mode", false)
	col_tax_happy_target = _read_int(d, "col_tax_happy_target", 70)
	nat_tax_gate_mode = _read_int(d, "nat_tax_gate_mode", 1)
	nat_tax_method = _read_int(d,"nat_tax_method",0)
	nat_tax_cap_enabled = _read_bool(d,"nat_tax_cap_enabled",false)
	nat_tax_happy_target = _read_int(d,"nat_tax_happy_target",70)
		
func _to_dict() -> Dictionary:
	return {
		"permute_special_fcs_case": permute_special_fcs_case,
		"fc_never_change_raw": fc_never_change_raw,
		"randomize_other_fcs": randomize_other_fcs,
		"col_tax_mode": col_tax_mode,
		"col_tax_min_clans": col_tax_min_clans,
		"col_tax_min_income_mc": col_tax_min_income_mc,
		"col_tax_gate_mode": col_tax_gate_mode,
		"col_tax_method": col_tax_method,
		"col_tax_cap_enabled": col_tax_cap_enabled,
		"col_tax_happy_target": col_tax_happy_target,
		"nat_tax_gate_mode": nat_tax_gate_mode,
		"nat_tax_method": nat_tax_method,
		"nat_tax_cap_enabled": nat_tax_cap_enabled,
		"nat_tax_happy_target": nat_tax_happy_target,
	}
	
func set_current_game(game_id: int) -> void:
	if game_id == current_game_id:
		return
	# Optional: wenn du sicher gehen willst, vorher speichern
	if dirty and current_game_id > 0:
		save_for_game(current_game_id)

	current_game_id = game_id
	load_for_game(game_id)

func _default_config() -> Dictionary:
	return {
		"fc": {
			"enabled": true,
			"protected": [],            # list of FCs (case-insensitive)
			"case_only": ["ATT", "NUK"],
			"pool": ["000", "123", "abc"],
			"per_planet": {}            # planet_id -> {"mode":"protected|case_only|random|off", "pool":[...]}
		},
		"tax": {
			"native_default": {"mode":"adaptive", "start_target":85, "end_target":55, "deadline_turn":0, "floor":40},
			"colonist_default": {"mode":"adaptive", "start_target":85, "end_target":60, "deadline_turn":0, "floor":40, "min_income_to_tax":50},
			"per_planet": {}            # planet_id -> {"native":{...}, "colonist":{...}}
		},
		"build": {
			"enabled": false,
			"max_builds_per_turn": 20,
			"horizon_turns": 12,
			"target_turn": 0,
			"weights": {"mc":1.0, "sup":0.3, "neut":1.0, "trit":1.0, "dura":1.0, "moly":1.0}
		}
	}

# --- convenient merged access -----------------------------------------------

func _pid_key(planet_id: int) -> String:
	return str(planet_id)

func fc_for_planet(planet_id: int) -> Dictionary:
	var base: Dictionary = cfg.get("fc", {})
	var per: Dictionary = base.get("per_planet", {})
	var ov: Dictionary = per.get(_pid_key(planet_id), {})
	var out := base.duplicate(true)
	# keep only needed keys, merge ov shallow
	for k in ov.keys():
		out[k] = ov[k]
	return out

func tax_for_planet(planet_id: int) -> Dictionary:
	var base: Dictionary = cfg.get("tax", {})
	var per: Dictionary = base.get("per_planet", {})
	var ov: Dictionary = per.get(_pid_key(planet_id), {})
	var out := base.duplicate(true)
	for k in ov.keys():
		out[k] = ov[k]
	return out

func build_cfg() -> Dictionary:
	return cfg.get("build", {})

func get_fc_never_change_set() -> Dictionary:
	# Dictionary als Set: key -> true
	var s: Dictionary = {}

	# 1) user list
	var raw: String = fc_never_change_raw
	var tokens: PackedStringArray = raw.split(",", false)
	for t in tokens:
		var fc: String = t.strip_edges().to_upper()
		if fc.length() == 3:
			s[fc] = true

	# 2) specials (immer geschützt)
	for fc2 in SPECIAL_FCS_CASE_DEFAULT:
		s[String(fc2).to_upper()] = true

	return s

func get_fc_never_change_prefixes() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()

	# user list: comma-separated
	var tokens: PackedStringArray = fc_never_change_raw.split(",", false)
	for t in tokens:
		var s: String = t.strip_edges().to_upper()
		if s.length() >= 1 and s.length() <= 3:
			out.append(s)

	# specials: immer schützen (als volle 3-char FCs)
	for fc2 in SPECIAL_FCS_CASE_DEFAULT:
		out.append(String(fc2).to_upper())

	return out

func is_fc_protected(fc: String) -> bool:
	var f: String = fc.strip_edges().to_upper()
	if f.is_empty():
		return false

	var prefixes: PackedStringArray = get_fc_never_change_prefixes()
	for pref in prefixes:
		# Prefix-Regel: wenn fc mit pref beginnt -> geschützt
		if f.begins_with(pref):
			return true
	return false

static func _read_bool(d: Dictionary, key: String, def: bool) -> bool:
	if not d.has(key):
		return def
	var v: Variant = d[key]
	if v is bool:
		return bool(v)
	return def

static func _read_int(d: Dictionary, key: String, def: int) -> int:
	if not d.has(key):
		return def
	var v: Variant = d[key]
	var t: int = typeof(v)
	if t == TYPE_INT:
		return int(v)
	if t == TYPE_FLOAT:
		return int(float(v))
	if t == TYPE_STRING:
		var s: String = String(v)
		if s.is_valid_int():
			return s.to_int()
	return def

static func _read_string(d: Dictionary, key: String, def: String) -> String:
	if not d.has(key):
		return def
	var v: Variant = d[key]
	if typeof(v) == TYPE_STRING:
		return String(v)
	return def
