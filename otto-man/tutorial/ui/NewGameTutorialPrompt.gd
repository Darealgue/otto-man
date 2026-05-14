extends Control
## Yeni oyunda profil seçildikten sonra: Tutorial / Geç / Geri.

signal tutorial_chosen
signal skip_tutorial_chosen
signal back_requested

@onready var _btn_tutorial: Button = %BtnTutorial
@onready var _btn_skip: Button = %BtnSkip
@onready var _btn_back: Button = %BtnBack


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	if is_instance_valid(_btn_tutorial):
		_btn_tutorial.pressed.connect(func(): tutorial_chosen.emit())
	if is_instance_valid(_btn_skip):
		_btn_skip.pressed.connect(func(): skip_tutorial_chosen.emit())
	if is_instance_valid(_btn_back):
		_btn_back.pressed.connect(func(): back_requested.emit())


func show_prompt() -> void:
	visible = true
	if is_instance_valid(_btn_tutorial):
		_btn_tutorial.grab_focus()


func hide_prompt() -> void:
	visible = false
