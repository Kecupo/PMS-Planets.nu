extends Window
class_name ConfigPopup
var _syncing: bool = false
var _wired_natives: bool = false
@onready var chk_perm_case: CheckButton = $"RootVBox/Tabs/Manage FCs/MarginContainer/VBoxContainer/ChkPermuteSPecialFcsCase"
@onready var tabs: TabContainer = $RootVBox/Tabs
@onready var close_btn: Button = $RootVBox/ButtonsRow/CloseBtn
@onready var txt_never: TextEdit = $"RootVBox/Tabs/Manage FCs/MarginContainer/VBoxContainer/TxtNeverChangeFcs"
@onready var chk_randomize: CheckButton = $"RootVBox/Tabs/Manage FCs/MarginContainer/VBoxContainer/ChkRandomizeOtherFcs"
# --- Colonist Tax Tab ---
@onready var rb_col_gate_off: Button = %RbColGateOff
@onready var rb_col_gate_min_clans: Button = %RbColGateMinCLans
@onready var rb_col_gate_min_income: Button = %RbColGateMinIncome
@onready var spin_col_min_clans: SpinBox = %SpinColMinClans
@onready var spin_col_min_income: SpinBox = %SpinColMinIncome

@onready var rb_col_method_growth: Button = %RbColMethodGrowthTax
@onready var rb_col_method_growth_plus: Button = %RbColMethodGrowthTaxPlus
@onready var chk_nat_tax_enabled: Button = %BtnNatGateOff
@onready var btn_nat_method_growth: Button = %BtnNatMethodGrowthTax
@onready var btn_nat_method_growth_plus: Button = %BtnNatMethodGrowthTaxPlus
@onready var chk_nat_cap: Button = %ChkNatCapEnabled
@onready var btn_nat_cap_70: Button = %BtnNatCap70
@onready var btn_nat_cap_40: Button = %BtnNatCap40
@onready var chk_col_cap_mode: CheckButton = %ChkColCapModeEnabled
@onready var rb_col_cap_70: Button = %RbColCap70
@onready var rb_col_cap_40: Button = %RbColCap40
@onready var race_colors_vbox: VBoxContainer = %RaceColorsVbox
func _ready() -> void:
	close_btn.pressed.connect(_on_close_pressed)
	close_requested.connect(_on_close_pressed)

	# Connect UI -> Config
	chk_perm_case.toggled.connect(_on_chk_perm_case_toggled)
	txt_never.text_changed.connect(_on_txt_never_changed)
	chk_randomize.toggled.connect(_on_chk_randomize_toggled)
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
	rb_col_gate_off.toggled.connect(_on_col_gate_changed)
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

	btn_nat_method_growth.toggled.connect(_on_nat_method_changed)
	btn_nat_method_growth_plus.toggled.connect(_on_nat_method_changed)

	chk_nat_cap.toggled.connect(_on_nat_cap_toggled)
	btn_nat_cap_70.toggled.connect(_on_nat_cap_target_changed)
	btn_nat_cap_40.toggled.connect(_on_nat_cap_target_changed)
# -------------------------
# Sync UI <- Config
# -------------------------
func sync_from_config() -> void:
	_syncing = true

	# ---------- Colonist Gate ----------
	var gate_mode: int = int(RandAI_Config.col_tax_gate_mode)

	rb_col_gate_off.button_pressed = (gate_mode == 0)
	rb_col_gate_min_clans.button_pressed = (gate_mode == 1)
	rb_col_gate_min_income.button_pressed = (gate_mode == 2)

	spin_col_min_clans.value = float(RandAI_Config.col_tax_min_clans)
	spin_col_min_income.value = float(RandAI_Config.col_tax_min_income_mc)

	# ---------- Colonist Method ----------
	var method: int = int(RandAI_Config.col_tax_method)

	rb_col_method_growth.button_pressed = (method == 0)
	rb_col_method_growth_plus.button_pressed = (method == 1)

	# ---------- Colonist Cap ----------
	chk_col_cap_mode.button_pressed = bool(RandAI_Config.col_tax_cap_enabled)

	var cap_target: int = int(RandAI_Config.col_tax_happy_target)

	rb_col_cap_70.button_pressed = (cap_target == 70)
	rb_col_cap_40.button_pressed = (cap_target == 40)

	_update_colonist_gate_controls()
	_update_colonist_cap_controls()

	# ---------- Native Tab ----------
	_sync_fc_tab_from_config()
	_sync_colonist_tab_from_config()
	_sync_native_tab_from_config()
	_syncing = false

func _sync_native_tab_from_config() -> void:

	chk_nat_tax_enabled.button_pressed = RandAI_Config.nat_tax_enabled

	var m: int = int(RandAI_Config.nat_tax_method)

	btn_nat_method_growth.button_pressed = (m == 0)
	btn_nat_method_growth_plus.button_pressed = (m == 1)

	chk_nat_cap.button_pressed = bool(RandAI_Config.nat_tax_cap_enabled)

	var tgt: int = int(RandAI_Config.nat_tax_happy_target)

	btn_nat_cap_70.button_pressed = (tgt == 70)
	btn_nat_cap_40.button_pressed = (tgt == 40)

	_update_native_controls()
	
func _sync_fc_tab_from_config() -> void:
	chk_perm_case.button_pressed = bool(RandAI_Config.permute_special_fcs_case)
	txt_never.text = String(RandAI_Config.fc_never_change_raw)
	chk_randomize.button_pressed = bool(RandAI_Config.randomize_other_fcs)
	
func _sync_colonist_tab_from_config() -> void:
	# Gate: 0 = OFF, 1 = MIN_CLANS, 2 = MIN_INCOME
	var gate_mode: int = int(RandAI_Config.col_tax_gate_mode)

	rb_col_gate_off.button_pressed = (gate_mode == 0)
	rb_col_gate_min_clans.button_pressed = (gate_mode == 1)
	rb_col_gate_min_income.button_pressed = (gate_mode == 2)

	# Thresholds
	spin_col_min_clans.value = float(RandAI_Config.col_tax_min_clans)
	spin_col_min_income.value = float(RandAI_Config.col_tax_min_income_mc)

	# Method: 0 = Growth Tax, 1 = Growth Tax Plus
	var method: int = int(RandAI_Config.col_tax_method)
	rb_col_method_growth.button_pressed = (method == 0)
	rb_col_method_growth_plus.button_pressed = (method == 1)

	# Cap mode
	chk_col_cap_mode.button_pressed = bool(RandAI_Config.col_tax_cap_enabled)

	# Target happiness
	var cap_target: int = int(RandAI_Config.col_tax_happy_target)
	rb_col_cap_70.button_pressed = (cap_target == 70)
	rb_col_cap_40.button_pressed = (cap_target == 40)

	_update_colonist_gate_controls()
	_update_colonist_cap_controls()
	
func _update_native_controls() -> void:
	var on: bool = chk_nat_tax_enabled.button_pressed

	btn_nat_method_growth.disabled = not on
	btn_nat_method_growth_plus.disabled = not on

	chk_nat_cap.disabled = false
	var cap_on: bool = on and chk_nat_cap.button_pressed
	btn_nat_cap_70.disabled = not cap_on
	btn_nat_cap_40.disabled = not cap_on
	
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

func _on_col_tax_mode_selected(idx: int) -> void:
	if _syncing:
		return
		
	var gate_mode: int = 1
	if rb_col_gate_off.button_pressed:
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

func _on_nat_cap_toggled(on: bool) -> void:
	if _syncing: return
	if on:
		if RandAI_Config.nat_tax_happy_target != 40 and RandAI_Config.nat_tax_happy_target != 70:
			RandAI_Config.nat_tax_happy_target = 40

		btn_nat_cap_40.button_pressed = (RandAI_Config.nat_tax_happy_target == 40)
		btn_nat_cap_70.button_pressed = (RandAI_Config.nat_tax_happy_target == 70)
	#RandAI_Config.mark_dirty()
	_update_native_controls()

func _on_nat_cap_target_changed(_on: bool) -> void:
	if _syncing: return
	RandAI_Config.nat_tax_happy_target = 40 if btn_nat_cap_40.button_pressed else 70
	RandAI_Config.mark_dirty()
# -------------------------
# UI State helpers
# -------------------------
func _update_colonist_gate_controls() -> void:

	var tax_enabled: bool = rb_col_gate_off.button_pressed

	rb_col_gate_min_clans.disabled = not tax_enabled
	rb_col_gate_min_income.disabled = not tax_enabled

	var clans_mode: bool = tax_enabled and rb_col_gate_min_clans.button_pressed
	var income_mode: bool = tax_enabled and rb_col_gate_min_income.button_pressed

	spin_col_min_clans.editable = clans_mode
	spin_col_min_clans.focus_mode = Control.FOCUS_ALL if clans_mode else Control.FOCUS_NONE

	spin_col_min_income.editable = income_mode
	spin_col_min_income.focus_mode = Control.FOCUS_ALL if income_mode else Control.FOCUS_NONE

func _update_colonist_cap_controls() -> void:
	var on: bool = chk_col_cap_mode.button_pressed

	rb_col_cap_70.disabled = not on
	rb_col_cap_40.disabled = not on

	# optional: wenn off, Fokus verhindern
	if not on:
		rb_col_cap_70.focus_mode = Control.FOCUS_NONE
		rb_col_cap_40.focus_mode = Control.FOCUS_NONE
	else:
		rb_col_cap_70.focus_mode = Control.FOCUS_ALL
		rb_col_cap_40.focus_mode = Control.FOCUS_ALL

# -------------------------
# Handlers (ohne Lambdas)
# -------------------------
func _on_col_gate_changed(_on: bool) -> void:
	if _syncing:
		return
	if _on:
		var gate_mode: int = 1
		if rb_col_gate_off.button_pressed:
			gate_mode = 0
		elif rb_col_gate_min_income.button_pressed:
			gate_mode = 2
		else:
			gate_mode = 1
		if "col_tax_gate_mode" in RandAI_Config:
			RandAI_Config.col_tax_gate_mode = gate_mode
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

func _on_col_method_changed(_on: bool) -> void:
	if _syncing:
		return

	var method: int = 0
	if rb_col_method_growth_plus.button_pressed:
		method = 1

	if "col_tax_method" in RandAI_Config:
		RandAI_Config.col_tax_method = method
		RandAI_Config.mark_dirty()

func _on_col_cap_mode_toggled(on: bool) -> void:
	if _syncing:
		return

	if on:
		# Default Ziel: 40
		if RandAI_Config.col_tax_happy_target != 40 and RandAI_Config.col_tax_happy_target != 70:
			RandAI_Config.col_tax_happy_target = 40

		rb_col_cap_40.button_pressed = (RandAI_Config.col_tax_happy_target == 40)
		rb_col_cap_70.button_pressed = (RandAI_Config.col_tax_happy_target == 70)

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

	# immer neutral anzeigen
	_add_race_color_row(0, "Neutral / Unknown")

	var race_ids: Array[int] = []

	if GameState.config != null and GameState.config.races_by_id != null and not GameState.config.races_by_id.is_empty():
		for k in GameState.config.races_by_id.keys():
			var rid: int = -1
			if typeof(k) == TYPE_INT:
				rid = int(k)
			elif typeof(k) == TYPE_FLOAT:
				rid = int(float(k))
			elif typeof(k) == TYPE_STRING:
				var s: String = String(k)
				if s.is_valid_int():
					rid = s.to_int()

			if rid > 0:
				race_ids.append(rid)

		race_ids.sort()
		
	else:
		# Fallback: klassische 13 Slots
		for rid in range(1, 14):
			race_ids.append(rid)

	for rid in race_ids:
		var race_name: String = _race_display_name(rid)
		_add_race_color_row(rid, race_name)
	
func _race_display_name(race_id: int) -> String:
	if GameState.config != null:
		var abbr: String = GameState.config.get_owner_abbrev(race_id)
		if not abbr.is_empty() and abbr != "—":
			return "%d - %s" % [race_id, abbr]

	return "%d - Race %d" % [race_id, race_id]
	
func _add_race_color_row(race_id: int, label_text: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 30)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var lbl: Label = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(160, 24)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var preview: ColorRect = ColorRect.new()
	preview.custom_minimum_size = Vector2(28, 20)

	var picker: ColorPickerButton = ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(60, 24)
	picker.text = ""
	picker.set_meta("race_id", race_id)
	picker.set_meta("preview", preview)

	if race_id == 0:
		picker.color = Color.from_string(RandAI_Config.neutral_color, Color.WHITE)
	else:
		picker.color = RandAI_Config.get_race_color(race_id)

	preview.color = picker.color

	picker.color_changed.connect(_on_race_color_changed.bind(picker))

	row.add_child(lbl)
	row.add_child(preview)
	row.add_child(picker)

	race_colors_vbox.add_child(row)
	
func _on_race_color_changed(_color: Color, picker: ColorPickerButton) -> void:
	if _syncing:
		return

	var race_id: int = int(picker.get_meta("race_id"))
	var preview: ColorRect = picker.get_meta("preview") as ColorRect

	if preview != null:
		preview.color = picker.color

	if race_id == 0:
		RandAI_Config.neutral_color = picker.color.to_html()
		RandAI_Config.mark_dirty()
	else:
		RandAI_Config.set_race_color(race_id, picker.color)
