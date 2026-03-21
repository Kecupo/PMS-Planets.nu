extends HBoxContainer

@onready var login_btn: Button = $LoginButton
@onready var upload_button: Button = $UploadButton
@onready var quit_button: Button = $QuitButton
@onready var manage_button: Button = $ManageButton
@onready var select_button: Button = $SelectButton
@onready var config_button: Button = $ConfigButton
@onready var help_button: Button = $HelpButton

const LoginDialogScene := preload("res://Scenes/LoginDialog.tscn")
var _login_dialog: Window = null

@onready var _game_select_popup: Window = preload("res://Scenes/GameSelectPopup.tscn").instantiate()
const HelpScene := preload("res://Scenes/HelpWindow.tscn")
const ConfigPopupScene := preload("res://Scenes/ConfigPopup.tscn")
var _popup: ConfigPopup = null
var _help: HelpPanel = null

func _ready() -> void:
	# Buttons
	login_btn.pressed.connect(_on_login_or_logout_pressed)
	upload_button.pressed.connect(_on_upload_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	manage_button.pressed.connect(_on_manage_button_pressed)
	select_button.pressed.connect(_on_select_button_pressed)
	config_button.pressed.connect(_on_config_button_pressed)
	help_button.pressed.connect(_on_help_button_pressed)
	# Game select popup must be in tree
	add_child(_game_select_popup)
	_game_select_popup.hide()

	# Signals (nur EINMAL verbinden!)
	if PlanetsApi.has_signal("login_success"):
		PlanetsApi.login_success.connect(_on_login_success)

	# UI refresh on game change (nur EINMAL verbinden!)
	if GameState.has_signal("game_changed"):
		GameState.game_changed.connect(_on_game_changed)

	# Initial UI state
	_refresh_login_button()
	_refresh_ui_state()


func _on_game_changed(_gid: int) -> void:
	_refresh_ui_state()


func _show_login_dialog() -> void:
	if _login_dialog == null:
		_login_dialog = LoginDialogScene.instantiate() as Window
		get_tree().root.add_child(_login_dialog)  # Window am besten unter root
		_login_dialog.hide()
		_login_dialog.tree_exited.connect(func() -> void:
			_login_dialog = null
		)

	_login_dialog.open_popup()

func _refresh_ui_state() -> void:
	var logged_in: bool = GameState.has_api_credentials()
	var game_selected: bool = GameState.current_game_id > 0

	# Select Game nur bei Login
	select_button.disabled = not logged_in

	# Features brauchen Login + Game
	var enable_game_features: bool = logged_in and game_selected
	config_button.disabled = not enable_game_features
	upload_button.disabled = not enable_game_features
	manage_button.disabled = not enable_game_features


func _on_login_or_logout_pressed() -> void:
	if GameState.has_api_credentials():
		GameState.clear_api_credentials()
		PlanetsApi.logout()
		_refresh_login_button()
		_refresh_ui_state()
		return

	_show_login_dialog()


func _on_login_success() -> void:
	# Nach erfolgreichem Login Button/UI updaten und Dialog schließen
	_refresh_login_button()
	_refresh_ui_state()

	if _login_dialog != null:
		_login_dialog.visible = false
		# optional statt hide: _login_dialog.queue_free()


func _on_upload_pressed() -> void:
	PlanetsApi.save_turn(
		GameState.last_turn_json,
		GameState.current_game_id,
		GameState.my_player_id
	)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_manage_button_pressed() -> void:
	var game_id: int = GameState.get_game_id()
	var cur_turn: int = GameState.get_current_turn()
	var owner_race_id: int = GameState.get_owner_race_id()
	var my_planets: Array[PlanetData] = GameState.get_my_planets()

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()

	RandAI_Config.set_current_game(GameState.current_game_id)

	for p in my_planets:
		Orders_Store.set_auto_managed(game_id, int(p.planet_id), true)

	RandAIPlanner.apply_to_planets(
		game_id,
		cur_turn,
		owner_race_id,
		my_planets,
		RandAI_Config,
		Orders_Store,
		Planet_Math,
		rng
	)

	get_viewport().gui_release_focus()

	var pid: int = GameState.selected_planet_id
	if pid >= 0:
		GameState.select_planet(pid)

	GameState.emit_signal("orders_changed")


func _on_select_button_pressed() -> void:
	_game_select_popup.open_and_load()


func _on_config_button_pressed() -> void:
	if _popup == null:
		_popup = ConfigPopupScene.instantiate() as ConfigPopup
		get_tree().root.add_child(_popup)
	_popup.open_popup()

func _on_help_button_pressed() -> void:
	if _help == null:
		_help = HelpScene.instantiate() as HelpPanel
		get_node("/root/MainUI/UILayer").add_child(_help)
	_help.open_panel()
	
func _refresh_login_button() -> void:
	login_btn.text = "Logout" if GameState.has_api_credentials() else "Login"
