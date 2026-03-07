extends Node

var current_game_id: int = 0
var dirty: bool = false
enum ColTaxGateMode {
	OFF = 0,
	MIN_CLANS = 1,
	MIN_INCOME = 2
}

enum TaxMethod {
	GROWTH = 0,
	GROWTH_PLUS = 1
}
# -------------------------
# FC Config
# -------------------------
const SPECIAL_FCS_CASE_DEFAULT: PackedStringArray = [
	"NUK", "ATT",
	"PB0", "PB1", "PB2", "PB3", "PB4", "PB5", "PB6", "PB7", "PB8", "PB9",
	"RB0", "RB1", "RB2", "RB3", "RB4", "RB5", "RB6", "RB7", "RB8", "RB9"
]

var permute_special_fcs_case: bool = false
var fc_never_change_raw: String = ""
var randomize_other_fcs: bool = false

# -------------------------
# Colonist Tax Config
# Gate: 0 = OFF, 1 = MIN_CLANS, 2 = MIN_INCOME
# Method: 0 = Growth Tax, 1 = Growth Tax Plus
# -------------------------
var col_tax_gate_mode: int = 1
var col_tax_min_clans: int = 10000
var col_tax_min_income_mc: int = 100
var col_tax_method: int = 0
var col_tax_cap_enabled: bool = false
var col_tax_happy_target: int = 70

# -------------------------
# Native Tax Config
# enabled: true/false
# Method: 0 = Growth Tax, 1 = Growth Tax Plus
# -------------------------
var nat_tax_enabled: bool = false
var nat_tax_method: int = 0
var nat_tax_cap_enabled: bool = false
var nat_tax_happy_target: int = 70


func set_current_game(game_id: int) -> void:
	if game_id <= 0:
		return

	if game_id == current_game_id:
		return

	if dirty and current_game_id > 0:
		save_for_game(current_game_id)

	current_game_id = game_id
	load_for_game(game_id)


func load_for_game(game_id: int) -> void:
	GameStorage.ensure_game_dir(game_id)

	var path: String = GameStorage.rand_ai_config_path(game_id)
	var d: Dictionary = GameStorage.load_json(path)

	if d.is_empty():
		_apply_defaults()
		dirty = true
		save_for_game(game_id)
		return

	_apply_defaults()
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
	# FC
	permute_special_fcs_case = false
	fc_never_change_raw = ""
	randomize_other_fcs = false

	# Colonists
	col_tax_gate_mode = 1
	col_tax_min_clans = 10000
	col_tax_min_income_mc = 100
	col_tax_method = 0
	col_tax_cap_enabled = false
	col_tax_happy_target = 70

	# Natives
	nat_tax_enabled = false
	nat_tax_method = 0
	nat_tax_cap_enabled = false
	nat_tax_happy_target = 70


func _apply_from_dict(d: Dictionary) -> void:
	# FC
	permute_special_fcs_case = _read_bool(d, "permute_special_fcs_case", false)
	fc_never_change_raw = _read_string(d, "fc_never_change_raw", "")
	randomize_other_fcs = _read_bool(d, "randomize_other_fcs", false)

	# Colonists
	col_tax_gate_mode = _read_int(d, "col_tax_gate_mode", 1)
	col_tax_min_clans = _read_int(d, "col_tax_min_clans", 10000)
	col_tax_min_income_mc = _read_int(d, "col_tax_min_income_mc", 100)
	col_tax_method = _read_int(d, "col_tax_method", 0)
	col_tax_cap_enabled = _read_bool(d, "col_tax_cap_enabled", false)
	col_tax_happy_target = _read_int(d, "col_tax_happy_target", 70)

	if col_tax_gate_mode < 0 or col_tax_gate_mode > 2:
		col_tax_gate_mode = 1
	if col_tax_method < 0 or col_tax_method > 1:
		col_tax_method = 0
	if col_tax_happy_target != 70 and col_tax_happy_target != 40:
		col_tax_happy_target = 70

	# Natives
	nat_tax_enabled = _read_bool(d, "nat_tax_enabled", false)
	nat_tax_method = _read_int(d, "nat_tax_method", 0)
	nat_tax_cap_enabled = _read_bool(d, "nat_tax_cap_enabled", false)
	nat_tax_happy_target = _read_int(d, "nat_tax_happy_target", 70)

	if nat_tax_method < 0 or nat_tax_method > 1:
		nat_tax_method = 0
	if nat_tax_happy_target != 70 and nat_tax_happy_target != 40:
		nat_tax_happy_target = 70


func _to_dict() -> Dictionary:
	var d: Dictionary = {}

	# FC
	d["permute_special_fcs_case"] = permute_special_fcs_case
	d["fc_never_change_raw"] = fc_never_change_raw
	d["randomize_other_fcs"] = randomize_other_fcs

	# Colonists
	d["col_tax_gate_mode"] = col_tax_gate_mode
	d["col_tax_min_clans"] = col_tax_min_clans
	d["col_tax_min_income_mc"] = col_tax_min_income_mc
	d["col_tax_method"] = col_tax_method
	d["col_tax_cap_enabled"] = col_tax_cap_enabled
	d["col_tax_happy_target"] = col_tax_happy_target

	# Natives
	d["nat_tax_enabled"] = nat_tax_enabled
	d["nat_tax_method"] = nat_tax_method
	d["nat_tax_cap_enabled"] = nat_tax_cap_enabled
	d["nat_tax_happy_target"] = nat_tax_happy_target

	return d


static func _read_bool(d: Dictionary, key: String, default_value: bool) -> bool:
	if not d.has(key):
		return default_value

	var v: Variant = d[key]
	if v is bool:
		return bool(v)

	return default_value


static func _read_int(d: Dictionary, key: String, default_value: int) -> int:
	if not d.has(key):
		return default_value

	var v: Variant = d[key]

	if typeof(v) == TYPE_INT:
		return int(v)

	if typeof(v) == TYPE_FLOAT:
		return int(float(v))

	if typeof(v) == TYPE_STRING:
		var s: String = String(v)
		if s.is_valid_int():
			return s.to_int()

	return default_value


static func _read_string(d: Dictionary, key: String, default_value: String) -> String:
	if not d.has(key):
		return default_value

	var v: Variant = d[key]
	if typeof(v) == TYPE_STRING:
		return String(v)

	return default_value


func get_fc_never_change_prefixes() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()

	var tokens: PackedStringArray = fc_never_change_raw.split(",", false)
	for t in tokens:
		var s: String = t.strip_edges().to_upper()
		if s.length() >= 1 and s.length() <= 3:
			out.append(s)

	for fc in SPECIAL_FCS_CASE_DEFAULT:
		out.append(String(fc).to_upper())

	return out


func is_fc_protected(fc: String) -> bool:
	var f: String = fc.strip_edges().to_upper()
	if f.is_empty():
		return false

	var prefixes: PackedStringArray = get_fc_never_change_prefixes()
	for pref in prefixes:
		if f.begins_with(pref):
			return true

	return false

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
