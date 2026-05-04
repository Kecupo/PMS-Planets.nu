extends Window
class_name ConfigPopup
var _syncing: bool = false
var _wired_natives: bool = false
@onready var chk_perm_case: CheckButton = $"RootVBox/Tabs/Manage Planets/MarginContainer/VBoxContainer/ChkPermuteSPecialFcsCase"
@onready var tabs: TabContainer = $RootVBox/Tabs
@onready var close_btn: Button = $RootVBox/ButtonsRow/CloseBtn
@onready var manage_planets_vbox: VBoxContainer = $"RootVBox/Tabs/Manage Planets/MarginContainer/VBoxContainer"
@onready var txt_never: TextEdit = $"RootVBox/Tabs/Manage Planets/MarginContainer/VBoxContainer/TxtNeverChangeFcs"
@onready var chk_randomize: CheckButton = $"RootVBox/Tabs/Manage Planets/MarginContainer/VBoxContainer/ChkRandomizeOtherFcs"
# --- Colonist Tax Tab ---
@onready var chk_col_tax_enabled: CheckButton = %ChkColTaxEnabed
@onready var rb_col_gate_min_clans: Button = %RbColGateMinCLans
@onready var rb_col_gate_min_income: Button = %RbColGateMinIncome
@onready var spin_col_min_clans: SpinBox = %SpinColMinClans
@onready var spin_col_min_income: SpinBox = %SpinColMinIncome

@onready var rb_col_method_growth: Button = %RbColMethodGrowthTax
@onready var rb_col_method_growth_plus: Button = %RbColMethodGrowthTaxPlus
@onready var chk_nat_tax_enabled: CheckButton = %BtnNatGateOff
@onready var btn_nat_method_growth: Button = %BtnNatMethodGrowthTax
@onready var btn_nat_method_growth_plus: Button = %BtnNatMethodGrowthTaxPlus
@onready var chk_nat_cap: CheckButton = %ChkNatCapEnabled
@onready var btn_nat_cap_70: Button = %BtnNatCap70
@onready var btn_nat_cap_40: Button = %BtnNatCap40
@onready var chk_cyborg_always_tax_natives: CheckButton = %ChkCyborgAlwaysTaxNatives
@onready var chk_col_cap_mode: CheckButton = %ChkColCapModeEnabled
@onready var rb_col_cap_70: Button = %RbColCap70
@onready var rb_col_cap_40: Button = %RbColCap40
@onready var race_colors_vbox: VBoxContainer = %RaceColorsVbox
var chk_calc_optimal_buildings: CheckButton = null
var btn_mine_in_turns: Button = null
var btn_mine_to_turn: Button = null
var spin_mine_in_turns: SpinBox = null
var spin_mine_to_turn: SpinBox = null
var chk_build_defense: CheckButton = null
var btn_build_21_defense: Button = null
var btn_max_defense: Button = null

func _ready() -> void:
	_build_manage_planets_controls()
	close_btn.pressed.connect(_on_close_pressed)
	close_requested.connect(_on_close_pressed)

	# Connect UI -> Config
	chk_perm_case.toggled.connect(_on_chk_perm_case_toggled)
	txt_never.text_changed.connect(_on_txt_never_changed)
	chk_randomize.toggled.connect(_on_chk_randomize_toggled)
	_wire_manage_planets_tab()
	_wire_colonist_tab()
	_wire_native_tab()
	# Initial pull
	#_build_race_color_tab()
	sync_from_config()
	_apply_config_button_themes(self)
	
	
func open_popup() -> void:
	# beim Öffnen immer aktuellen Spiel-Stand laden
	if GameState.current_game_id > 0:
		RandAI_Config.set_current_game(GameState.current_game_id)
	_build_race_color_tab()
	sync_from_config()
	visible = true
	popup_centered()
	grab_focus()

# -------------------------
# Wiring: Colonists Tab
# -------------------------
func _wire_colonist_tab() -> void:
	# Gate (wann besteuern)
	chk_col_tax_enabled.toggled.connect(_on_col_enabled_toggled)
	rb_col_gate_min_clans.toggled.connect(_on_col_gate_changed)
	rb_col_gate_min_income.toggled.connect(_on_col_gate_changed)

	# Spinboxes
	spin_col_min_clans.value_changed.connect(_on_col_min_clans_changed)
	spin_col_min_income.value_changed.connect(_on_col_min_income_changed)

	# Method (wie besteuern)
	rb_col_method_growth.toggled.connect(_on_col_method_changed)
	rb_col_method_growth_plus.toggled.connect(_on_col_method_changed)

	# Cap Mode
	chk_col_cap_mode.toggled.connect(_on_col_cap_mode_toggled)
	rb_col_cap_70.toggled.connect(_on_col_cap_target_changed)
	rb_col_cap_40.toggled.connect(_on_col_cap_target_changed)

func _wire_native_tab() -> void:
	if _wired_natives:
		return
	_wired_natives = true
	chk_nat_tax_enabled.toggled.connect(_on_nat_enabled_toggled)
	btn_nat_method_growth.toggled.connect(_on_nat_method_changed)
	btn_nat_method_growth_plus.toggled.connect(_on_nat_method_changed)

	chk_cyborg_always_tax_natives.toggled.connect(_on_cyborg_always_tax_natives_toggled)
	chk_nat_cap.toggled.connect(_on_nat_cap_toggled)
	btn_nat_cap_70.toggled.connect(_on_nat_cap_target_changed)
	btn_nat_cap_40.toggled.connect(_on_nat_cap_target_changed)

func _build_manage_planets_controls() -> void:
	if chk_calc_optimal_buildings != null:
		return

	manage_planets_vbox.add_child(HSeparator.new())

	chk_calc_optimal_buildings = CheckButton.new()
	chk_calc_optimal_buildings.text = "Calculate optimal factories&mines"
	chk_calc_optimal_buildings.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	manage_planets_vbox.add_child(chk_calc_optimal_buildings)

	var mining_group: ButtonGroup = ButtonGroup.new()
	mining_group.allow_unpress = false
	var mine_row_1: HBoxContainer = HBoxContainer.new()
	mine_row_1.add_theme_constant_override("separation", 8)
	manage_planets_vbox.add_child(mine_row_1)
	btn_mine_in_turns = _make_toggle_option("Mine the planet in", mining_group)
	mine_row_1.add_child(btn_mine_in_turns)
	spin_mine_in_turns = _make_turn_spinbox()
	mine_row_1.add_child(spin_mine_in_turns)
	mine_row_1.add_child(_make_option_suffix_label("turns"))

	var mine_row_2: HBoxContainer = HBoxContainer.new()
	mine_row_2.add_theme_constant_override("separation", 8)
	manage_planets_vbox.add_child(mine_row_2)
	btn_mine_to_turn = _make_toggle_option("Mine the planets to turn", mining_group)
	mine_row_2.add_child(btn_mine_to_turn)
	spin_mine_to_turn = _make_turn_spinbox()
	mine_row_2.add_child(spin_mine_to_turn)

	manage_planets_vbox.add_child(HSeparator.new())

	chk_build_defense = CheckButton.new()
	chk_build_defense.text = "Build defense"
	chk_build_defense.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	manage_planets_vbox.add_child(chk_build_defense)

	var defense_group: ButtonGroup = ButtonGroup.new()
	defense_group.allow_unpress = false
	var defense_row: HBoxContainer = HBoxContainer.new()
	defense_row.add_theme_constant_override("separation", 8)
	manage_planets_vbox.add_child(defense_row)
	btn_build_21_defense = _make_toggle_option("Build 21 defense", defense_group)
	btn_max_defense = _make_toggle_option("Max defense", defense_group)
	defense_row.add_child(btn_build_21_defense)
	defense_row.add_child(btn_max_defense)

func _make_toggle_option(text: String, group: ButtonGroup) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.toggle_mode = true
	btn.button_group = group
	btn.focus_mode = Control.FOCUS_ALL
	return btn

func _make_turn_spinbox() -> SpinBox:
	var spin: SpinBox = SpinBox.new()
	spin.min_value = 1.0
	spin.max_value = 999.0
	spin.step = 1.0
	spin.rounded = true
	spin.custom_minimum_size = Vector2(70, 0)
	spin.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return spin

func _make_option_suffix_label(text: String) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl

func _wire_manage_planets_tab() -> void:
	chk_calc_optimal_buildings.toggled.connect(_on_calc_optimal_buildings_toggled)
	btn_mine_in_turns.toggled.connect(_on_mining_target_mode_changed)
	btn_mine_to_turn.toggled.connect(_on_mining_target_mode_changed)
	spin_mine_in_turns.value_changed.connect(_on_mine_in_turns_changed)
	spin_mine_to_turn.value_changed.connect(_on_mine_to_turn_changed)
	chk_build_defense.toggled.connect(_on_build_defense_toggled)
	btn_build_21_defense.toggled.connect(_on_defense_build_mode_changed)
	btn_max_defense.toggled.connect(_on_defense_build_mode_changed)
# -------------------------
# Sync UI <- Config
# -------------------------
func sync_from_config() -> void:
	_syncing = true

	_sync_planet_manage_tab_from_config()
	_sync_colonist_tab_from_config()
	_sync_native_tab_from_config()

	_syncing = false

func _sync_native_tab_from_config() -> void:

	chk_nat_tax_enabled.button_pressed = RandAI_Config.nat_tax_enabled

	var m: int = int(RandAI_Config.nat_tax_method)

	btn_nat_method_growth.button_pressed = (m == 0)
	btn_nat_method_growth_plus.button_pressed = (m == 1)

	chk_nat_cap.button_pressed = bool(RandAI_Config.nat_tax_cap_enabled)
	chk_cyborg_always_tax_natives.button_pressed = bool(RandAI_Config.cyborg_always_tax_natives)

	var tgt: int = int(RandAI_Config.nat_tax_happy_target)

	btn_nat_cap_70.button_pressed = (tgt == 70)
	btn_nat_cap_40.button_pressed = (tgt == 40)

	_update_native_controls()
	
func _sync_planet_manage_tab_from_config() -> void:
	chk_perm_case.button_pressed = bool(RandAI_Config.permute_special_fcs_case)
	txt_never.text = String(RandAI_Config.fc_never_change_raw)
	chk_randomize.button_pressed = bool(RandAI_Config.randomize_other_fcs)
	chk_calc_optimal_buildings.button_pressed = bool(RandAI_Config.calc_optimal_factories_mines)
	btn_mine_in_turns.button_pressed = int(RandAI_Config.planet_mining_target_mode) == RandAI_Config.PlanetMiningTargetMode.IN_TURNS
	btn_mine_to_turn.button_pressed = int(RandAI_Config.planet_mining_target_mode) == RandAI_Config.PlanetMiningTargetMode.TO_TURN
	spin_mine_in_turns.value = float(RandAI_Config.planet_mining_in_turns)
	spin_mine_to_turn.value = float(RandAI_Config.planet_mining_to_turn)
	chk_build_defense.button_pressed = bool(RandAI_Config.build_defense_enabled)
	btn_build_21_defense.button_pressed = int(RandAI_Config.planet_defense_build_mode) == RandAI_Config.PlanetDefenseBuildMode.BUILD_21
	btn_max_defense.button_pressed = int(RandAI_Config.planet_defense_build_mode) == RandAI_Config.PlanetDefenseBuildMode.MAX_DEFENSE
	_update_manage_planets_controls()
	
func _sync_colonist_tab_from_config() -> void:
	chk_col_tax_enabled.button_pressed = bool(RandAI_Config.col_tax_enabled)

	var gate_mode: int = int(RandAI_Config.col_tax_gate_mode)
	rb_col_gate_min_clans.button_pressed = (gate_mode == RandAI_Config.ColTaxGateMode.MIN_CLANS)
	rb_col_gate_min_income.button_pressed = (gate_mode == RandAI_Config.ColTaxGateMode.MIN_INCOME)

	spin_col_min_clans.value = float(RandAI_Config.col_tax_min_clans)
	spin_col_min_income.value = float(RandAI_Config.col_tax_min_income_mc)

	var method: int = int(RandAI_Config.col_tax_method)
	rb_col_method_growth.button_pressed = (method == RandAI_Config.TaxMethod.GROWTH)
	rb_col_method_growth_plus.button_pressed = (method == RandAI_Config.TaxMethod.GROWTH_PLUS)

	chk_col_cap_mode.button_pressed = bool(RandAI_Config.col_tax_cap_enabled)

	var cap_target: int = int(RandAI_Config.col_tax_happy_target)
	rb_col_cap_70.button_pressed = (cap_target == 70)
	rb_col_cap_40.button_pressed = (cap_target == 40)

	_update_colonist_gate_controls()
	_update_colonist_cap_controls()
	
func _update_native_controls() -> void:
	var on: bool = chk_nat_tax_enabled.button_pressed

	btn_nat_method_growth.disabled = not on
	btn_nat_method_growth_plus.disabled = not on

	chk_cyborg_always_tax_natives.visible = _is_my_race_cyborg()
	chk_cyborg_always_tax_natives.disabled = not on

	chk_nat_cap.disabled = not on
	var cap_on: bool = on and chk_nat_cap.button_pressed
	btn_nat_cap_70.disabled = not cap_on
	btn_nat_cap_40.disabled = not cap_on

func _update_manage_planets_controls() -> void:
	var calc_on: bool = chk_calc_optimal_buildings.button_pressed
	btn_mine_in_turns.disabled = not calc_on
	btn_mine_to_turn.disabled = not calc_on
	spin_mine_in_turns.editable = calc_on and btn_mine_in_turns.button_pressed
	spin_mine_to_turn.editable = calc_on and btn_mine_to_turn.button_pressed
	spin_mine_in_turns.focus_mode = Control.FOCUS_ALL if spin_mine_in_turns.editable else Control.FOCUS_NONE
	spin_mine_to_turn.focus_mode = Control.FOCUS_ALL if spin_mine_to_turn.editable else Control.FOCUS_NONE

	var defense_on: bool = chk_build_defense.button_pressed
	btn_build_21_defense.disabled = not defense_on
	btn_max_defense.disabled = not defense_on
	btn_build_21_defense.focus_mode = Control.FOCUS_ALL if defense_on else Control.FOCUS_NONE
	btn_max_defense.focus_mode = Control.FOCUS_ALL if defense_on else Control.FOCUS_NONE
	
func _on_close_pressed() -> void:
	if RandAI_Config.dirty and GameState.current_game_id > 0:
		RandAI_Config.save_for_game(GameState.current_game_id)
	hide()

func _on_chk_perm_case_toggled(on: bool) -> void:
	if _syncing:
		return
	RandAI_Config.permute_special_fcs_case = on
	RandAI_Config.mark_dirty()
	_update_check_color(chk_perm_case)
	
func _on_txt_never_changed() -> void:
	if _syncing:
		return
	RandAI_Config.fc_never_change_raw = txt_never.text
	RandAI_Config.mark_dirty()

func _on_chk_randomize_toggled(on: bool) -> void:
	if _syncing:
		return
	RandAI_Config.randomize_other_fcs = on
	RandAI_Config.mark_dirty()

func _on_calc_optimal_buildings_toggled(on: bool) -> void:
	if _syncing:
		return
	RandAI_Config.calc_optimal_factories_mines = on
	RandAI_Config.mark_dirty()
	_update_manage_planets_controls()

func _on_mining_target_mode_changed(on: bool) -> void:
	if _syncing:
		return
	if not on:
		return
	if btn_mine_to_turn.button_pressed:
		RandAI_Config.planet_mining_target_mode = RandAI_Config.PlanetMiningTargetMode.TO_TURN
	else:
		RandAI_Config.planet_mining_target_mode = RandAI_Config.PlanetMiningTargetMode.IN_TURNS
	RandAI_Config.mark_dirty()
	_update_manage_planets_controls()

func _on_mine_in_turns_changed(value: float) -> void:
	if _syncing:
		return
	RandAI_Config.planet_mining_in_turns = max(1, int(round(value)))
	RandAI_Config.mark_dirty()

func _on_mine_to_turn_changed(value: float) -> void:
	if _syncing:
		return
	RandAI_Config.planet_mining_to_turn = max(1, int(round(value)))
	RandAI_Config.mark_dirty()

func _on_build_defense_toggled(on: bool) -> void:
	if _syncing:
		return
	RandAI_Config.build_defense_enabled = on
	RandAI_Config.mark_dirty()
	_update_manage_planets_controls()

func _on_defense_build_mode_changed(on: bool) -> void:
	if _syncing:
		return
	if not on:
		return
	if btn_max_defense.button_pressed:
		RandAI_Config.planet_defense_build_mode = RandAI_Config.PlanetDefenseBuildMode.MAX_DEFENSE
	else:
		RandAI_Config.planet_defense_build_mode = RandAI_Config.PlanetDefenseBuildMode.BUILD_21
	RandAI_Config.mark_dirty()

func _on_col_tax_mode_selected(idx: int) -> void:
	if _syncing:
		return
		
	var gate_mode: int = 1
	if chk_col_cap_mode.button_pressed:
		gate_mode = 0
	elif rb_col_gate_min_income.button_pressed:
		gate_mode = 2
	else:
		gate_mode = 1
	RandAI_Config.col_tax_mode = idx
	RandAI_Config.mark_dirty()
	_update_col_tax_controls()
	
func _update_col_tax_controls() -> void:
	var mode_n: int = RandAI_Config.col_tax_mode
	spin_col_min_clans.editable = (mode_n == RandAI_Config.ColTaxMode.MIN_CLANS)
	spin_col_min_income.editable = (mode_n == RandAI_Config.ColTaxMode.MIN_INCOME)
	RandAI_Config.mark_dirty()

func _on_nat_enabled_toggled(on: bool) -> void:
	if _syncing: return
	RandAI_Config.nat_tax_enabled = on
	RandAI_Config.mark_dirty()
	_update_native_controls()

func _on_nat_method_changed(_on: bool) -> void:
	if _syncing: return
	RandAI_Config.nat_tax_method = 1 if btn_nat_method_growth_plus.button_pressed else 0
	RandAI_Config.mark_dirty()

func _on_cyborg_always_tax_natives_toggled(on: bool) -> void:
	if _syncing: return
	RandAI_Config.cyborg_always_tax_natives = on
	RandAI_Config.mark_dirty()

func _on_nat_cap_toggled(on: bool) -> void:
	if _syncing: return
	RandAI_Config.nat_tax_cap_enabled = on
	if on:
		if RandAI_Config.nat_tax_happy_target != 40 and RandAI_Config.nat_tax_happy_target != 70:
			RandAI_Config.nat_tax_happy_target = 40

		btn_nat_cap_40.button_pressed = (RandAI_Config.nat_tax_happy_target == 40)
		btn_nat_cap_70.button_pressed = (RandAI_Config.nat_tax_happy_target == 70)
	RandAI_Config.mark_dirty()
	_update_native_controls()

func _on_nat_cap_target_changed(_on: bool) -> void:
	if _syncing: return
	RandAI_Config.nat_tax_happy_target = 40 if btn_nat_cap_40.button_pressed else 70
	RandAI_Config.mark_dirty()

func _is_my_race_cyborg() -> bool:
	return int(GameState.get_my_race_id()) == RandAIPlanner.CYBORG_RACE_ID

# -------------------------
# UI State helpers
# -------------------------
func _update_colonist_gate_controls() -> void:
	var enabled: bool = chk_col_tax_enabled.button_pressed

	rb_col_gate_min_clans.disabled = not enabled
	rb_col_gate_min_income.disabled = not enabled

	spin_col_min_clans.editable = enabled and rb_col_gate_min_clans.button_pressed
	spin_col_min_clans.focus_mode = Control.FOCUS_ALL if spin_col_min_clans.editable else Control.FOCUS_NONE

	spin_col_min_income.editable = enabled and rb_col_gate_min_income.button_pressed
	spin_col_min_income.focus_mode = Control.FOCUS_ALL if spin_col_min_income.editable else Control.FOCUS_NONE

	rb_col_method_growth.disabled = not enabled
	rb_col_method_growth_plus.disabled = not enabled
	
func _update_colonist_cap_controls() -> void:
	var enabled: bool = chk_col_tax_enabled.button_pressed

	chk_col_cap_mode.disabled = not enabled

	var cap_on: bool = enabled and chk_col_cap_mode.button_pressed
	rb_col_cap_70.disabled = not cap_on
	rb_col_cap_40.disabled = not cap_on

	rb_col_cap_70.focus_mode = Control.FOCUS_ALL if cap_on else Control.FOCUS_NONE
	rb_col_cap_40.focus_mode = Control.FOCUS_ALL if cap_on else Control.FOCUS_NONE

# -------------------------
# Handlers (ohne Lambdas)
# -------------------------
func _on_col_gate_changed(on: bool) -> void:
	if _syncing:
		return
	if not on:
		return

	if rb_col_gate_min_income.button_pressed:
		RandAI_Config.col_tax_gate_mode = RandAI_Config.ColTaxGateMode.MIN_INCOME
	else:
		RandAI_Config.col_tax_gate_mode = RandAI_Config.ColTaxGateMode.MIN_CLANS

	RandAI_Config.mark_dirty()
	_update_colonist_gate_controls()

func _on_col_min_clans_changed(v: float) -> void:
	if _syncing:
		return
	if "col_tax_min_clans" in RandAI_Config:
		RandAI_Config.col_tax_min_clans = int(v)
		RandAI_Config.mark_dirty()

func _on_col_min_income_changed(v: float) -> void:
	if _syncing:
		return
	if "col_tax_min_income_mc" in RandAI_Config:
		RandAI_Config.col_tax_min_income_mc = int(v)
		RandAI_Config.mark_dirty()

func _on_col_method_changed(on: bool) -> void:
	if _syncing:
		return
	if not on:
		return

	if rb_col_method_growth_plus.button_pressed:
		RandAI_Config.col_tax_method = RandAI_Config.TaxMethod.GROWTH_PLUS
	else:
		RandAI_Config.col_tax_method = RandAI_Config.TaxMethod.GROWTH

	RandAI_Config.mark_dirty()

func _on_col_cap_mode_toggled(on: bool) -> void:
	if _syncing:
		return
	RandAI_Config.col_tax_cap_enabled = on
	if on:
		# Default Ziel: 40
		if RandAI_Config.col_tax_happy_target != 40 and RandAI_Config.col_tax_happy_target != 70:
			RandAI_Config.col_tax_happy_target = 40

		rb_col_cap_40.button_pressed = (RandAI_Config.col_tax_happy_target == 40)
		rb_col_cap_70.button_pressed = (RandAI_Config.col_tax_happy_target == 70)
	RandAI_Config.mark_dirty()
	_update_colonist_cap_controls()

func _update_check_color(btn: CheckButton) -> void:
	if btn.button_pressed:
		btn.add_theme_color_override("font_color", Color(0.2, 0.9, 0.2)) # grün
	else:
		btn.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2)) # rot

func _on_col_cap_target_changed(_on: bool) -> void:
	if _syncing:
		return

	var target: int = 70
	if rb_col_cap_40.button_pressed:
		target = 40

	if "col_tax_happy_target" in RandAI_Config:
		RandAI_Config.col_tax_happy_target = target
		RandAI_Config.mark_dirty()

func _make_check_button_theme() -> Theme:
	var th: Theme = Theme.new()

	# unchecked → rot
	th.set_color("font_color", "CheckButton", Color(0.9, 0.2, 0.2))
	th.set_color("font_hover_color", "CheckButton", Color(1.0, 0.3, 0.3))

	# checked → grün
	th.set_color("font_pressed_color", "CheckButton", Color(0.2, 0.9, 0.2))
	th.set_color("font_hover_pressed_color", "CheckButton", Color(0.3, 1.0, 0.3))
	th.set_color("font_focus_color", "CheckButton", Color(0.2, 0.9, 0.2))

	return th
func _make_toggle_button_theme() -> Theme:
	var th: Theme = Theme.new()

	th.set_color("font_color", "Button", Color(0.9, 0.2, 0.2))
	th.set_color("font_hover_color", "Button", Color(1.0, 0.3, 0.3))

	th.set_color("font_pressed_color", "Button", Color(0.2, 0.9, 0.2))
	th.set_color("font_hover_pressed_color", "Button", Color(0.3, 1.0, 0.3))
	th.set_color("font_focus_color", "Button", Color(0.2, 0.9, 0.2))

	return th
func _apply_config_button_themes(root: Node) -> void:
	var check_theme: Theme = _make_check_button_theme()
	var toggle_theme: Theme = _make_toggle_button_theme()

	_apply_themes_recursive(root, check_theme, toggle_theme)
func _apply_themes_recursive(node: Node, check_theme: Theme, toggle_theme: Theme) -> void:

	if node is CheckButton:
		node.theme = check_theme

	elif node is Button:
		# Toggle-Buttons (deine Radio-Button-Ersatz-Buttons)
		if (node as Button).toggle_mode:
			node.theme = toggle_theme

	for c in node.get_children():
		_apply_themes_recursive(c, check_theme, toggle_theme)

func _build_race_color_tab() -> void:
	for c in race_colors_vbox.get_children():
		c.queue_free()
	#_add_race_color_row(-1, "")
	# immer neutral anzeigen
	_add_race_color_row(0, -1, "   Neutral / Unknown")

	var players: Array[Dictionary] = GameState.get_players()

	if not players.is_empty():
		for player: Dictionary in players:
			var player_id: int = int(player.get("id", 0))
			var race_id: int = int(player.get("raceid", -1))
			if player_id > 0:
				_add_race_color_row(player_id, race_id, _player_color_display_name(player))
	else:
		# Fallback: klassische 13 Slots
		for player_id in range(1, 14):
			_add_race_color_row(player_id, -1, "   P%d - Player %d" % [player_id, player_id])
	
func _player_color_display_name(player: Dictionary) -> String:
	var player_id: int = int(player.get("id", 0))
	var race_id: int = int(player.get("raceid", -1))
	var race_name: String = _race_display_name(race_id)
	var player_name: String = _player_name_from_dict(player)

	if player_name.is_empty():
		return "   P%d - %s" % [player_id, race_name]

	return "   P%d - %s (%s)" % [player_id, race_name, player_name]

func _player_name_from_dict(player: Dictionary) -> String:
	var keys: PackedStringArray = [
		"username",
		"accountname",
		"playername",
		"name",
		"nickname"
	]
	for key: String in keys:
		var value: String = String(player.get(key, "")).strip_edges()
		if not value.is_empty():
			return value
	return ""

func _race_display_name(race_id: int) -> String:
	if GameState.config != null:
		var abbr: String = GameState.config.get_owner_abbrev(race_id)
		if not abbr.is_empty() and abbr != "—":
			return abbr

	return "Race %d" % race_id
	
func _add_race_color_row(player_id: int, race_id: int, label_text: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 30)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var lbl: Label = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(160, 24)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var picker: ColorPickerButton = ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(60, 24)
	picker.text = ""
	picker.set_meta("player_id", player_id)
	picker.set_meta("race_id", race_id)
	
	if player_id == 0:
		picker.color = Color.from_string(RandAI_Config.neutral_color, Color.WHITE)
	else:
		picker.color = RandAI_Config.get_player_color(player_id, race_id)

	picker.color_changed.connect(_on_race_color_changed.bind(picker))

	row.add_child(lbl)
	row.add_child(picker)

	race_colors_vbox.add_child(row)
	
func _on_race_color_changed(_color: Color, picker: ColorPickerButton) -> void:
	if _syncing:
		return

	var player_id: int = int(picker.get_meta("player_id"))
	var preview: ColorRect = picker.get_meta("preview") as ColorRect

	if preview != null:
		preview.color = picker.color

	if player_id == 0:
		RandAI_Config.neutral_color = picker.color.to_html()
		RandAI_Config.mark_dirty()
	else:
		RandAI_Config.set_player_color(player_id, picker.color)

func _on_col_enabled_toggled(on: bool) -> void:
	if _syncing:
		return

	RandAI_Config.col_tax_enabled = on
	RandAI_Config.mark_dirty()
	_update_colonist_gate_controls()
	_update_colonist_cap_controls()
