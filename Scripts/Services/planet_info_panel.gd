extends PanelContainer
# planet_info_panel.gd (Godot 4.5.1)
#
# Overlay that displays the currently selected planet.
#
# Uses Unique Names (%Name) for referenced labels.
# Conventions:
# - V_* : primary value labels
# - M_* : meta labels (growth, delta, max, mining, etc.)
# - L_* : caption labels (optional to hide)
@onready var close_btn: Button = %Close_Overlay
@onready var game_state = get_node("/root/GameState")

# -------------------------
# Header
# -------------------------
@onready var planet_id_lbl: Label = %PlanetIdLabel
@onready var planet_name_lbl: Label = %PlanetNameLabel
@onready var planet_fc_lbl: Label = %PlanetFcLabel
@onready var planet_owner_lbl: Label = %PlanetOwnerLabel
@onready var coord_temp_lbl: Label = %CoordTempLabel  # temperature only (label name stays)

# -------------------------
# Economy (GridContainer columns=3)
# -------------------------
@onready var v_mc: Label = %V_Megacredits
@onready var v_sup: Label = %V_Supplies
# Optional meta for supplies next turn (create if you want it)
@onready var col_max: Label = %L_Colonist_Max
@onready var v_col: Label = %V_Colonists
@onready var m_col_growth: Label = %M_Colonists_Growth
@onready var v_col_tax_spin: SpinBox = %V_ColonistTaxSpin
@onready var v_col_happy: Label = %V_ColonistHappy
@onready var m_col_happy_d: Label = %M_ColonistHappyDelta
@onready var m_mc_total: Label = get_node_or_null("%M_Megacredits")
@onready var m_sup_next: Label = get_node_or_null("%M_Supplies")

# -------------------------
# Natives (block)
# -------------------------
@onready var v_nat_race: Label = %V_NativeRace
@onready var v_nat_gov: Label = %V_NativeGov
@onready var m_nat_gov_tax_factor: Label = %M_NativeGovTaxFactor

@onready var v_nat_clans: Label = %V_NativeClans
@onready var m_nat_max_clans: Label = %M_NativeMaxClans
@onready var m_nat_growth: Label = %M_Natives_Growth

@onready var v_nat_tax_spin: SpinBox = %V_NativeTaxSpin
@onready var v_nat_happy: Label = %V_NativeHappy
@onready var m_nat_happy_d: Label = %M_NativeHappyDelta
@onready var nat_lbl: Label = %Natives_lbl
# Captions that should also hide when no natives
@onready var l_nat_tax: Label = get_node_or_null("%L_NativeTax")
@onready var l_nat_happy: Label = get_node_or_null("%L_NativeHappy")

# -------------------------
# Industry (GridContainer columns=3)
# -------------------------
@onready var v_fact: Label = %V_Factories
@onready var m_fact_max: Label = %M_Factories_Max
@onready var v_mines: Label = %V_Mines
@onready var m_mines_max: Label = %M_Mines_Max
@onready var v_def: Label = %V_Defense
@onready var m_def_max: Label = %M_Defense_Max

# -------------------------
# Minerals (GridContainer columns=5)
# Mineral | Surface | Ground | Density | Mining
# -------------------------
@onready var v_n_s: Label = %V_Neut_Surface
@onready var v_n_g: Label = %V_Neut_Ground
@onready var v_n_d: Label = %V_Neut_Density
@onready var m_n_mining: Label = %M_Neut_Mining

@onready var v_t_s: Label = %V_Trit_Surface
@onready var v_t_g: Label = %V_Trit_Ground
@onready var v_t_d: Label = %V_Trit_Density
@onready var m_t_mining: Label = %M_Trit_Mining
@onready var m_col_tax_income: Label = get_node_or_null("%M_ColonistTaxIncome")
@onready var m_nat_tax_income: Label = get_node_or_null("%M_NativeTaxIncome")

@onready var v_du_s: Label = %V_Dura_Surface
@onready var v_du_g: Label = %V_Dura_Ground
@onready var v_du_d: Label = %V_Dura_Density
@onready var m_du_mining: Label = %M_Dura_Mining

@onready var v_m_s: Label = %V_Moly_Surface
@onready var v_m_g: Label = %V_Moly_Ground
@onready var v_m_d: Label = %V_Moly_Density
@onready var m_m_mining: Label = %M_Moly_Mining
var _ui_lock: bool = false

func _ready() -> void:
	close_btn.pressed.connect(_on_close_pressed)
	game_state.selection_changed.connect(_on_selection_changed)
	_update()
	v_col_tax_spin.value_changed.connect(_on_colonist_tax_changed)
	v_nat_tax_spin.value_changed.connect(_on_native_tax_changed)
	GameState.orders_changed.connect(_on_orders_changed)
	
func _on_close_pressed() -> void:
	hide()
	
func _on_selection_changed(kind: String, _selected_id: int) -> void:
	if kind == "planet":
		_update()
	if self.visible == false: self.visible = true

# -------------------------
# Helpers
# -------------------------
func _fmt_int(v: float) -> String:
	return str(int(v))

func _fmt_int_unknown(v: float) -> String:
	return "?" if v < 0.0 else str(int(v))

func _fmt_pct_unknown(v: float) -> String:
	return "?" if v < 0.0 else "%d%%" % int(v)

func _dash() -> String:
	return "—"

func _set_label(lbl: Label, value: String) -> void:
	if lbl == null:
		return
	lbl.text = value

func _set_visible(node: CanvasItem, is_visible_v: bool) -> void:
	if node == null:
		return
	node.visible = is_visible_v

func _owner_abbrev(ownerid: int) -> String:
	if game_state.config == null:
		return "—" if ownerid == 0 else str(ownerid)
	return game_state.config.get_owner_abbrev(ownerid)

func _has_natives(p: PlanetData) -> bool:
	# Consider "none" and negative clans as no natives for display
	if p.nativeracename == "none":
		return false
	return p.nativeclans >= 0.0

func _gov_tax_eff_text(p: PlanetData) -> String:
	# Shows the native tax value used by planets.nu client logic.
	if p.nativegovernment < 0.0:
		return _dash()

	var tax_value: int = int(p.nativetaxvalue)
	return "%d%%" % tax_value

# -------------------------
# Update
# -------------------------
func _update() -> void:
	var p: PlanetData = game_state.get_selected_planet()
	var is_mine: bool = game_state.is_my_planet(p)

	v_col_tax_spin.editable = is_mine
	v_col_tax_spin.focus_mode = Control.FOCUS_ALL if is_mine else Control.FOCUS_NONE

	v_nat_tax_spin.editable = is_mine
	v_nat_tax_spin.focus_mode = Control.FOCUS_ALL if is_mine else Control.FOCUS_NONE
	v_col_tax_spin.modulate = Color.WHITE if is_mine else Color(0.6, 0.6, 0.6)
	v_nat_tax_spin.modulate = Color.WHITE if is_mine else Color(0.6, 0.6, 0.6)
	if p == null:
		planet_id_lbl.text = ""
		planet_name_lbl.text = "No selection"
		planet_fc_lbl.text = ""
		planet_owner_lbl.text = ""
		coord_temp_lbl.text = ""
		_set_all_unknown()
		_set_natives_block_visible(false)
		return
	# Effective tax rates (including orders)
	var col_tax: int = game_state.get_effective_colonist_taxrate(p)
	var nat_tax: int = game_state.get_effective_native_taxrate(p)

	_set_spin_value(v_col_tax_spin, col_tax)
	_set_spin_value(v_nat_tax_spin, nat_tax)

	# Header
	planet_id_lbl.text = "ID %d" % p.planet_id
	planet_name_lbl.text = p.name
	planet_fc_lbl.text = p.friendlycode
	var rid: int = int(p.ownerid)
	planet_owner_lbl.text = _owner_abbrev(rid)
	planet_owner_lbl.add_theme_color_override(
	"font_color",
	RandAI_Config.get_race_color(rid)
)
	coord_temp_lbl.text = "%.0f°" % p.temperature

	# -------------------------
	# Economy
	# -------------------------
	_set_label(v_mc, _fmt_int_unknown(p.megacredits))
	_set_label(v_sup, _fmt_int_unknown(p.supplies))

	# Supplies produced next turn = factories
	if m_sup_next != null:
		var sup_next: int = Planet_Math.supplies_produced_next_turn(p)
		_set_label(m_sup_next, "+%d" % sup_next if sup_next >= 0 else _dash())

	_set_label(v_col, _fmt_int_unknown(p.clans))
	var col_growth: int = PlanetMath.colonist_growth_clans_most(
	int(p.temperature),
	int(p.clans),
	int(p.colonisttaxrate),
	int(p.colonisthappypoints),
	false
	)
	if p.nativeracename == "Amorphous":
		if col_growth >= 5: col_growth -= 5
		else: col_growth = 0
	if col_growth > 0:
		_set_label(m_col_growth, "+" + str(col_growth))
	elif col_growth == 0:
		_set_label(m_col_growth, "0")
	else:
		_set_label(m_col_growth, _dash())
	
	# Colonist happiness (may be negative!) -> do NOT treat negative as unknown in display
	_set_label(v_col_happy, _fmt_int(p.colonisthappypoints) if p.raw.has("colonisthappypoints") else "?")
	if is_mine: 
		_set_label(col_max, "Max: " + str(PlanetMath.colonist_max_clans(p.temperature, rid)))
	else:
		_set_label(col_max, "???")
		
	# Colonist happiness delta next turn
	var base_temp: float = 50.0 # TODO later from config
	var col_new_h: int = PlanetMath.colonist_happiness_next_turn_with_tax(p, col_tax, base_temp)
	
	var col_delta_h: int = 0
	if col_new_h >= 0 and p.raw.has("colonisthappypoints"):
		col_delta_h = col_new_h - int(p.colonisthappypoints)
		_set_label(m_col_happy_d, " %d" % col_delta_h)
	else:
		_set_label(m_col_happy_d, " " + _dash())

	# -------------------------
	# Natives
	# -------------------------
	var natives_exist := _has_natives(p)
	_set_natives_block_visible(natives_exist)

	if natives_exist:
		# Row: Natives | Race | Government | Tax Efficiency
		_set_label(v_nat_race, p.nativeracename)
		_set_label(v_nat_gov, p.nativegovernmentname if p.nativegovernmentname != "" else "gov ?")
		_set_label(m_nat_gov_tax_factor, _gov_tax_eff_text(p))

		# Row: Clans | Max | Growth
		_set_label(v_nat_clans, _fmt_int_unknown(p.nativeclans))
		var max_nat: int = Planet_Math.native_max_clans(p)
		if max_nat >= 0:
			_set_label(m_nat_max_clans, "Max: %d" % max_nat)
		else:
			_set_label(m_nat_max_clans, "Max: —")

		var owner_race_id: int = GameState.get_owner_race_id_of_planet(p)
		
		var g_nat: int = Planet_Math.native_growth_clans(p, nat_tax, owner_race_id)
		_set_label(m_nat_growth, "+%d" % g_nat if g_nat >= 0 else "—")

		# Tax + Happy
		
		# Native happiness can be negative
		_set_label(v_nat_happy, _fmt_int(p.nativehappypoints) if p.raw.has("nativehappypoints") else "?")

		# Native happiness delta next turn (nebula/combat ignored for now -> 0)
		var nat_new_h: int = PlanetMath.native_happiness_next_turn_with_tax(p, nat_tax, 0, 0)

		if nat_new_h >= 0 and p.raw.has("nativehappypoints"):
			var nat_delta_h: int = nat_new_h - int(p.nativehappypoints)
			_set_label(m_nat_happy_d, " %d" % nat_delta_h)
		else:
			_set_label(m_nat_happy_d, " " + _dash())

	# -------------------------
	# Industry
	# -------------------------
	_set_label(v_fact, _fmt_int_unknown(p.factories))
	_set_label(v_mines, _fmt_int_unknown(p.mines))
	_set_label(v_def, _fmt_int_unknown(p.defense))

	var max_f: int = Planet_Math.max_factories(p)
	_set_label(m_fact_max, "%d" % max_f if max_f >= 0 else "Max: —")

	var max_m: int = Planet_Math.max_mines(p)
	_set_label(m_mines_max, "%d" % max_m if max_m >= 0 else "Max: —")

	var max_d: int = Planet_Math.max_defense(p)
	_set_label(m_def_max, "%d" % max_d if max_d >= 0 else "Max: —")


	# -------------------------
	# Minerals
	# -------------------------
	_set_label(v_n_s, _fmt_int_unknown(p.neutronium))
	_set_label(v_n_g, _fmt_int_unknown(p.groundneutronium))
	_set_label(v_n_d, _fmt_int_unknown(p.densityneutronium))
	_set_label(m_n_mining, _dash())  # TODO formula

	_set_label(v_t_s, _fmt_int_unknown(p.tritanium))
	_set_label(v_t_g, _fmt_int_unknown(p.groundtritanium))
	_set_label(v_t_d, _fmt_int_unknown(p.densitytritanium))
	_set_label(m_t_mining, _dash())

	_set_label(v_du_s, _fmt_int_unknown(p.duranium))
	_set_label(v_du_g, _fmt_int_unknown(p.groundduranium))
	_set_label(v_du_d, _fmt_int_unknown(p.densityduranium))
	_set_label(m_du_mining, _dash())

	_set_label(v_m_s, _fmt_int_unknown(p.molybdenum))
	_set_label(v_m_g, _fmt_int_unknown(p.groundmolybdenum))
	_set_label(v_m_d, _fmt_int_unknown(p.densitymolybdenum))
	_set_label(m_m_mining, _dash())
	var eff_col_tax: int = game_state.get_effective_colonist_taxrate(p)
	var eff_nat_tax: int = game_state.get_effective_native_taxrate(p)
	var my_race_id: int = game_state.my_race_id
	var col_mc: int = PlanetMath.colonist_tax_mc(p, eff_col_tax, my_race_id)
	var nat_mc: int = PlanetMath.native_tax_mc(p, eff_nat_tax, my_race_id)
	_set_label(%M_ColonistTaxIncome, "+%d" % col_mc if col_mc >= 0 else "—")
	if m_nat_tax_income != null:
		_set_label(m_nat_tax_income, "+%d" % nat_mc if nat_mc >= 0 else "—")
	# --- Total MC income preview (Colonists + Natives) in M_Megacredits ---
	if m_mc_total != null:
		
	# Treat unknown (-1) as unknown total
		if col_mc < 0 or nat_mc < 0:
			_set_label(m_mc_total, "—")
		else:
			_set_label(m_mc_total, "+%d" % (col_mc + nat_mc))

# --- Supplies produced next turn (= factories) in M_Supplies ---
	if m_sup_next != null:
		var sup_next: int = Planet_Math.supplies_produced_next_turn(p)
		_set_label(m_sup_next, "+%d" % sup_next if sup_next >= 0 else "—")
	var owner_race_id: int = GameState.get_owner_race_id_of_planet(p)

	var pleasure: bool = false # TODO later from game config/campaigns

	var n_m: int = Planet_Math.planet_mining_neut(p, owner_race_id, pleasure)
	_set_label(m_n_mining, "+%d" % n_m if n_m >= 0 else "—")

	var t_m: int = Planet_Math.planet_mining_trit(p, owner_race_id, pleasure)
	_set_label(m_t_mining, "+%d" % t_m if t_m >= 0 else "—")

	var d_m: int = Planet_Math.planet_mining_dura(p, owner_race_id, pleasure)
	_set_label(m_du_mining, "+%d" % d_m if d_m >= 0 else "—")

	var mo_m: int = Planet_Math.planet_mining_moly(p, owner_race_id, pleasure)
	_set_label(m_m_mining, "+%d" % mo_m if mo_m >= 0 else "—")


func _set_natives_block_visible(is_visible_v: bool) -> void:
	_set_visible(nat_lbl, is_visible_v)
	_set_visible(v_nat_race, is_visible_v)
	_set_visible(v_nat_gov, is_visible_v)
	_set_visible(m_nat_gov_tax_factor, is_visible_v)

	_set_visible(v_nat_clans, is_visible_v)
	_set_visible(m_nat_max_clans, is_visible_v)
	_set_visible(m_nat_growth, is_visible_v)

	_set_visible(v_nat_tax_spin, is_visible_v)
	_set_visible(v_nat_happy, is_visible_v)
	_set_visible(m_nat_happy_d, is_visible_v)
	_set_visible(m_nat_growth, is_visible_v)
	# Captions that otherwise remain visible
	_set_visible(l_nat_tax, is_visible_v)
	_set_visible(l_nat_happy, is_visible_v)
	_set_visible(m_nat_tax_income, is_visible_v)

func _set_all_unknown() -> void:
	# Economy
	_set_label(v_mc, "?")
	_set_label(v_sup, "?")
	if m_sup_next != null:
		_set_label(m_sup_next, "?")

	_set_label(v_col, "?")
	_set_label(m_col_growth, "?")

	_set_label(v_col_happy, "?")
	_set_label(m_col_happy_d, "?")

	# Natives
	_set_label(v_nat_race, "?")
	_set_label(v_nat_gov, "?")
	_set_label(m_nat_gov_tax_factor, "?")
	_set_label(v_nat_clans, "?")
	_set_label(m_nat_max_clans, "?")
	_set_label(m_nat_growth, "?")

	_set_label(v_nat_happy, "?")
	_set_label(m_nat_happy_d, "?")

	# Industry
	_set_label(v_fact, "?")
	_set_label(m_fact_max, "Max: ?")
	_set_label(v_mines, "?")
	_set_label(m_mines_max, "Max: ?")
	_set_label(v_def, "?")
	_set_label(m_def_max, "Max: ?")

	# Minerals
	_set_label(v_n_s, "?")
	_set_label(v_n_g, "?")
	_set_label(v_n_d, "?")
	_set_label(m_n_mining, "?")

	_set_label(v_t_s, "?")
	_set_label(v_t_g, "?")
	_set_label(v_t_d, "?")
	_set_label(m_t_mining, "?")

	_set_label(v_du_s, "?")
	_set_label(v_du_g, "?")
	_set_label(v_du_d, "?")
	_set_label(m_du_mining, "?")

	_set_label(v_m_s, "?")
	_set_label(v_m_g, "?")
	_set_label(v_m_d, "?")
	_set_label(m_m_mining, "?")

func _on_colonist_tax_changed(val: float) -> void:
	if _ui_lock:
		return
	
	var p: PlanetData = game_state.get_selected_planet()
	if p == null:
		return
	if int(p.ownerid) != game_state.get_my_race_id():
		return
	game_state.set_planet_colonist_taxrate(p.planet_id, int(round(val)))
	_update()

func _on_native_tax_changed(val: float) -> void:
	if _ui_lock:
		return
	var p: PlanetData = game_state.get_selected_planet()
	if p == null:
		return
	if int(p.ownerid) != game_state.get_my_race_id():
		return
	game_state.set_planet_native_taxrate(p.planet_id, int(round(val)))
	_update()

func _set_spin_value(spin: SpinBox, v: int) -> void:
	if spin == null:
		return

	spin.set_block_signals(true)
	spin.value = float(v)
	spin.set_block_signals(false)

	var le: LineEdit = spin.get_line_edit()
	if le != null:
		# nur überschreiben, wenn der User nicht gerade tippt
		if not le.has_focus():
			le.text = str(v)
		
func _on_orders_changed() -> void:
	_update()
