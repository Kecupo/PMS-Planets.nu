extends Window

@onready var user_edit: LineEdit = %UsernameEdit
@onready var pass_edit: LineEdit = %PasswordEdit
@onready var login_btn: Button = %LoginButton
@onready var close_btn: Button = %CloseButton

func _ready() -> void:
	close_requested.connect(_on_close)
	close_btn.pressed.connect(_on_close)
	login_btn.pressed.connect(_on_login_pressed)

	PlanetsApi.login_success.connect(func() -> void:
		hide()
	, CONNECT_ONE_SHOT)

func open_popup() -> void:
	popup_centered(Vector2i(420, 260))
	user_edit.grab_focus()

func _on_close() -> void:
	hide()

func _on_login_pressed() -> void:
	var u: String = user_edit.text.strip_edges()
	var p: String = pass_edit.text
	PlanetsApi.login(u, p)
