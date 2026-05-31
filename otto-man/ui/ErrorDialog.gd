extends CanvasLayer

## ErrorDialog - Kullanıcı dostu hata mesajları gösterir
## Beta Yol Haritası FAZ 5.2: Hata Kontrolü ve Debug

signal dialog_closed

@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var message_label: RichTextLabel = $Panel/VBoxContainer/MessageLabel
@onready var ok_button: Button = $Panel/VBoxContainer/ButtonContainer/OKButton

func _ready() -> void:
	layer = 1000
	visible = false
	ok_button.pressed.connect(_on_ok_pressed)

	if message_label:
		message_label.bbcode_enabled = true
		message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if LocaleManager.has_signal("locale_changed"):
		LocaleManager.locale_changed.connect(_refresh_locale)
	_refresh_locale()


func _refresh_locale(_locale: String = "") -> void:
	if ok_button:
		ok_button.text = tr("dialog.ok")

func show_error(title: String, message: String) -> void:
	"""Hata mesajı göster"""
	if title_label:
		title_label.text = title
	if message_label:
		message_label.text = "[center]%s[/center]" % message
	
	visible = true
	# Pause game while showing error (but allow UI to process)
	var current_pause = get_tree().paused
	if not current_pause:
		get_tree().paused = true
	# Focus OK button
	ok_button.grab_focus()

func _on_ok_pressed() -> void:
	visible = false
	get_tree().paused = false
	dialog_closed.emit()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_accept"):
		_on_ok_pressed()

