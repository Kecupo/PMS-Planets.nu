extends HBoxContainer

@onready var turn_label: Label = %TurnLabel
@onready var race_label: Label = %RaceLabel
@onready var vcr_button: Button = %VcrButton
@onready var game_state: Node = get_node("/root/GameState")

const VCR_SIM_PROJECT_PATH: String = "C:/Users/Windows/Documents/planets-vcr-sim"
const GODOT_EXE_FALLBACK: String = "C:/Tools/godot.exe"

func _ready() -> void:
	# sofort einmal setzen (falls schon Turn geladen)
	_update_status()
	vcr_button.pressed.connect(_on_vcr_button_pressed)

	# und danach immer, wenn ein neuer Turn geladen wurde
	if game_state.has_signal("turn_loaded"):
		game_state.connect("turn_loaded", Callable(self, "_update_status"))

func _update_status() -> void:
	# Turn
	turn_label.text = str(game_state.get_current_turn())

	# eigene Rasse (nicht Planetowner!)
	var my_race_id: int = game_state.get_my_race_id()

	race_label.text = _owner_abbrev(my_race_id)

func _owner_abbrev(race_id: int) -> String:
	if game_state.config == null:
		return "—" if race_id <= 0 else str(race_id)
	return game_state.config.get_owner_abbrev(race_id)

func _on_vcr_button_pressed() -> void:
	var game_id: int = game_state.get_game_id()
	if game_id <= 0:
		push_warning("VCR: no game selected")
		return

	var turn_path: String = ProjectSettings.globalize_path(GameStorage.latest_turn_path(game_id))
	if not FileAccess.file_exists(turn_path):
		push_warning("VCR: latest_turn.json not found: " + turn_path)
		return

	var godot_exe: String = GODOT_EXE_FALLBACK if FileAccess.file_exists(GODOT_EXE_FALLBACK) else OS.get_executable_path()

	var args: PackedStringArray = PackedStringArray([
		"--path",
		VCR_SIM_PROJECT_PATH,
		"--",
		"--turn-file=" + turn_path
	])
	var pid: int = OS.create_process(godot_exe, args, false)
	if pid < 0:
		push_warning("VCR: failed to start simulator with " + godot_exe)
