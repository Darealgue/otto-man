extends Control
## Yeni oyunda profil seçildikten sonra: Tutorial / Geç / Geri.

signal tutorial_chosen
signal skip_tutorial_chosen
signal back_requested

@onready var _btn_tutorial: Button = %BtnTutorial
@onready var _btn_skip: Button = %BtnSkip
@onready var _btn_back: Button = %BtnBack
@onready var _title: Label = $Center/Panel/VBox/Title
@onready var _body: Label = $Center/Panel/VBox/Body


func _ready() -> void:
	var panel := get_node_or_null("Center/Panel") as PanelContainer
	if panel:
		ParchmentTextures.apply_large_panel_style(panel, 14)
	TextOutline.apply_to_tree(self)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	if is_instance_valid(_btn_tutorial):
		_btn_tutorial.pressed.connect(func(): tutorial_chosen.emit())
	if is_instance_valid(_btn_skip):
		_btn_skip.pressed.connect(func(): skip_tutorial_chosen.emit())
	if is_instance_valid(_btn_back):
		_btn_back.pressed.connect(func(): back_requested.emit())
	if LocaleManager.has_signal("locale_changed"):
		LocaleManager.locale_changed.connect(_refresh_locale)
	_refresh_locale()


func _refresh_locale(_locale: String = "") -> void:
	if _title:
		_title.text = tr("tutorial.prompt.title")
	if _body:
		_body.text = tr("tutorial.prompt.body")
	if _btn_tutorial:
		_btn_tutorial.text = tr("tutorial.prompt.play")
	if _btn_skip:
		_btn_skip.text = tr("tutorial.prompt.skip")
	if _btn_back:
		_btn_back.text = tr("tutorial.prompt.back")


func show_prompt() -> void:
	_refresh_locale()
	visible = true
	if is_instance_valid(_btn_tutorial):
		_btn_tutorial.grab_focus()


func hide_prompt() -> void:
	visible = false
