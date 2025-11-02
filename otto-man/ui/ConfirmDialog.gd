extends Control

## ConfirmDialog - Oyun içi onay dialogu
## OS.alert yerine kullanılır

signal confirmed()
signal cancelled()

@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var message_label: Label = $Panel/VBoxContainer/MessageLabel
@onready var confirm_button: Button = $Panel/VBoxContainer/ButtonsContainer/ConfirmButton
@onready var cancel_button: Button = $Panel/VBoxContainer/ButtonsContainer/CancelButton

var _result: bool = false
var _waiting_for_result: bool = false

func _ready() -> void:
	_ensure_nodes()
	_connect_signals()
	visible = false
	set_as_top_level(true)
	global_position = Vector2.ZERO
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ensure_nodes() -> void:
	if not title_label:
		push_error("[ConfirmDialog] TitleLabel not found!")
	if not message_label:
		push_error("[ConfirmDialog] MessageLabel not found!")
	if not confirm_button:
		push_error("[ConfirmDialog] ConfirmButton not found!")
	if not cancel_button:
		push_error("[ConfirmDialog] CancelButton not found!")

func _connect_signals() -> void:
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)

func show_dialog(title: String, message: String, show_cancel: bool = true) -> void:
	if not title_label or not message_label:
		push_error("[ConfirmDialog] Nodes not ready!")
		return
	
	title_label.text = title
	message_label.text = message
	cancel_button.visible = show_cancel
	
	_result = false
	_waiting_for_result = true
	visible = true
	
	# Focus management
	if show_cancel:
		cancel_button.grab_focus()
	else:
		confirm_button.grab_focus()

func _on_confirm_pressed() -> void:
	_result = true
	_waiting_for_result = false
	visible = false
	confirmed.emit()

func _on_cancel_pressed() -> void:
	_result = false
	_waiting_for_result = false
	visible = false
	cancelled.emit()

func hide_dialog() -> void:
	visible = false
	_waiting_for_result = false

func _input(event: InputEvent) -> void:
	# ESC ile iptal et
	if visible and _waiting_for_result and event.is_action_pressed("ui_cancel"):
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()

