extends HBoxContainer

@onready var turn_label: Label = %TurnLabel
@onready var race_label: Label = %RaceLabel
@onready var game_state: Node = get_node("/root/GameState")

func _ready() -> void:
	# sofort einmal setzen (falls schon Turn geladen)
	_update_status()

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
