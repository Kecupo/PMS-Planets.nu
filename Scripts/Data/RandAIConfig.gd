extends Node
var current_game_id: int = 0
var dirty: bool = false

# -------------------------
# Enums
# -------------------------
enum ColTaxGateMode {
	MIN_CLANS = 0,
	MIN_INCOME = 1
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
var fc_never_change_raw: String = "MF"
var randomize_other_fcs: bool = false

# -------------------------
# Colonist Tax Config
# -------------------------
# Gate:
var col_tax_enabled: bool = false
#   OFF = never tax colonists
#   MIN_CLANS = tax only if clans >= threshold
#   MIN_INCOME = tax only if max possible income >= threshold
var col_tax_gate_mode: int = ColTaxGateMode.MIN_CLANS
var col_tax_min_clans: int = 10000
var col_tax_min_income_mc: int = 100

# Method:
#   GROWTH = keep next-turn happiness >= 70
#   GROWTH_PLUS = tax deeper so zero-tax next turn can recover to 70
var col_tax_method: int = TaxMethod.GROWTH

# Cap mode: if planet is already maxed, hold happiness at target
var col_tax_cap_enabled: bool = false
var col_tax_happy_target: int = 70

# -------------------------
# Native Tax Config
# -------------------------
var nat_tax_enabled: bool = false
var nat_tax_method: int = TaxMethod.GROWTH
var nat_tax_cap_enabled: bool = false
var nat_tax_happy_target: int = 70

# -------------------------
# Race Colors
# Stored per game in same config JSON
# -------------------------
var race_colors: Dictionary = {}
var neutral_color: String = "#ffffff"

const DEFAULT_RACE_COLORS: Dictionary = {
	0: "#ffffff", # neutral / unknown
	1: "#00ff00",
	2: "#ff6060",
	3: "#60a0ff",
	4: "#ffaa40", 
	5: "#c060ff",
	6: "#40ffff",
	7: "#ff80c0",
	8: "#c0c0c0",
	9: "#ff8000",
	10: "#80ff40",
	11: "#8080ff",
	12: "#ffd060",
	13: "#ff60ff"
}

# -----------------------------------------------------------------------------
# Game switching / persistence
# -----------------------------------------------------------------------------

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

	_apply_defaults()

	if not d.is_empty():
		_apply_from_dict(d)
	else:
		dirty = true
		save_for_game(game_id)

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

# -----------------------------------------------------------------------------
# Defaults / load / save
# -----------------------------------------------------------------------------

func _apply_defaults() -> void:
	# FC
	permute_special_fcs_case = false
	fc_never_change_raw = "MF"
	randomize_other_fcs = false

	# Colonists
	col_tax_enabled = false
	col_tax_gate_mode = ColTaxGateMode.MIN_CLANS
	col_tax_min_clans = 10000
	col_tax_min_income_mc = 100
	col_tax_method = TaxMethod.GROWTH
	col_tax_cap_enabled = false
	col_tax_happy_target = 70

	# Natives
	nat_tax_enabled = false
	nat_tax_method = TaxMethod.GROWTH
	nat_tax_cap_enabled = false
	nat_tax_happy_target = 70

	# Race colors
	race_colors = DEFAULT_RACE_COLORS.duplicate(true)
	neutral_color = "#ffffff"

func _apply_from_dict(d: Dictionary) -> void:
	# FC
	permute_special_fcs_case = _read_bool(d, "permute_special_fcs_case", false)
	fc_never_change_raw = _read_string(d, "fc_never_change_raw", "")
	randomize_other_fcs = _read_bool(d, "randomize_other_fcs", false)

	# Colonists
	col_tax_enabled = _read_bool(d, "col_tax_enabled", false)
	col_tax_gate_mode = _read_int(d, "col_tax_gate_mode", ColTaxGateMode.MIN_CLANS)
	col_tax_min_clans = _read_int(d, "col_tax_min_clans", 10000)
	col_tax_min_income_mc = _read_int(d, "col_tax_min_income_mc", 100)
	col_tax_method = _read_int(d, "col_tax_method", TaxMethod.GROWTH)
	col_tax_cap_enabled = _read_bool(d, "col_tax_cap_enabled", false)
	col_tax_happy_target = _read_int(d, "col_tax_happy_target", 70)

	if col_tax_gate_mode < ColTaxGateMode.MIN_CLANS or col_tax_gate_mode > ColTaxGateMode.MIN_INCOME:
		col_tax_gate_mode = ColTaxGateMode.MIN_CLANS

	if col_tax_method < TaxMethod.GROWTH or col_tax_method > TaxMethod.GROWTH_PLUS:
		col_tax_method = TaxMethod.GROWTH

	if col_tax_happy_target != 70 and col_tax_happy_target != 40:
		col_tax_happy_target = 70

	# Natives
	nat_tax_enabled = _read_bool(d, "nat_tax_enabled", false)
	nat_tax_method = _read_int(d, "nat_tax_method", TaxMethod.GROWTH)
	nat_tax_cap_enabled = _read_bool(d, "nat_tax_cap_enabled", false)
	nat_tax_happy_target = _read_int(d, "nat_tax_happy_target", 70)

	if nat_tax_method < TaxMethod.GROWTH or nat_tax_method > TaxMethod.GROWTH_PLUS:
		nat_tax_method = TaxMethod.GROWTH

	if nat_tax_happy_target != 70 and nat_tax_happy_target != 40:
		nat_tax_happy_target = 70

	# Race colors
	neutral_color = _read_string(d, "neutral_color", "#ffffff")

	var rc_v: Variant = d.get("race_colors", {})
	if rc_v is Dictionary:
		race_colors.clear()
		var rc: Dictionary = rc_v as Dictionary
		for k in rc.keys():
			var key_i: int = _read_int_from_variant(k, -1)
			if key_i >= 0:
				race_colors[key_i] = String(rc[k])

func _to_dict() -> Dictionary:
	var d: Dictionary = {}

	# FC
	d["permute_special_fcs_case"] = permute_special_fcs_case
	d["fc_never_change_raw"] = fc_never_change_raw
	d["randomize_other_fcs"] = randomize_other_fcs

	# Colonists
	d["col_tax_enabled"] = col_tax_enabled
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

	# Race colors
	d["neutral_color"] = neutral_color
	d["race_colors"] = race_colors

	return d

# -----------------------------------------------------------------------------
# Race color helpers
# -----------------------------------------------------------------------------

func get_race_color(race_id: int) -> Color:
	var s: String = neutral_color

	if race_colors.has(race_id):
		s = String(race_colors[race_id])
	elif DEFAULT_RACE_COLORS.has(race_id):
		s = String(DEFAULT_RACE_COLORS[race_id])

	return Color.from_string(s, Color.WHITE)


func set_race_color(race_id: int, color: Color) -> void:
	race_colors[race_id] = color.to_html()
	mark_dirty()

# -----------------------------------------------------------------------------
# FC helpers
# -----------------------------------------------------------------------------

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

func get_fc_never_change_set() -> Dictionary:
	var s: Dictionary = {}

	var tokens: PackedStringArray = fc_never_change_raw.split(",", false)
	for t in tokens:
		var fc: String = t.strip_edges().to_upper()
		if fc.length() >= 1 and fc.length() <= 3:
			s[fc] = true

	for fc2 in SPECIAL_FCS_CASE_DEFAULT:
		s[String(fc2).to_upper()] = true

	return s

func is_fc_protected(fc: String) -> bool:
	var f: String = fc.strip_edges().to_upper()
	if f.is_empty():
		return false

	var prefixes: PackedStringArray = get_fc_never_change_prefixes()
	for pref in prefixes:
		if f.begins_with(pref):
			return true

	return false

# -----------------------------------------------------------------------------
# Readers
# -----------------------------------------------------------------------------

static func _read_bool(d: Dictionary, key: String, default_value: bool) -> bool:
	if not d.has(key):
		return default_value

	var v: Variant = d[key]

	if v is bool:
		return bool(v)

	if typeof(v) == TYPE_INT:
		return int(v) != 0

	if typeof(v) == TYPE_FLOAT:
		return int(float(v)) != 0

	if typeof(v) == TYPE_STRING:
		var s: String = String(v).strip_edges().to_lower()
		return s == "true" or s == "1"

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

static func _read_int_from_variant(v: Variant, default_value: int) -> int:
	if typeof(v) == TYPE_INT:
		return int(v)
	if typeof(v) == TYPE_FLOAT:
		return int(float(v))
	if typeof(v) == TYPE_STRING:
		var s: String = String(v)
		if s.is_valid_int():
			return s.to_int()
	return default_value
