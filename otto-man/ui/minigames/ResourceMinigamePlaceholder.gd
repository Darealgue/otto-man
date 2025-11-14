extends "res://ui/minigames/MinigameBase.gd"

@export var resource_type: String = "wood"
@export var base_amount: int = 3
@export var bonus_amount: int = 0
@export var title_text: String = "Placeholder Minigame"
@export var description_text: String = "Press attack to succeed."
@export var failure_text: String = "Press jump to fail."
@export var auto_complete_time: float = 0.0

var _elapsed := 0.0

@onready var _title_label: Label = $Panel/VBoxContainer/Title
@onready var _description_label: Label = $Panel/VBoxContainer/Description
@onready var _hint_label: Label = $Panel/VBoxContainer/Hint

func _on_minigame_ready() -> void:
	if _title_label:
		_title_label.text = title_text
	if _description_label:
		_description_label.text = description_text
	if _hint_label:
		_hint_label.text = failure_text
	set_process(true)
	set_process_input(true)
	set_process_unhandled_input(true)

var _attack_pressed_last_frame := false
var _jump_pressed_last_frame := false

func _process(delta: float) -> void:
	if is_finished():
		return
	# Auto-complete after time if set
	if auto_complete_time > 0.0:
		_elapsed += delta
		if _elapsed >= auto_complete_time:
			finish(true, {"resource_type": resource_type, "amount": base_amount})
			return

func _unhandled_input(event: InputEvent) -> void:
	if is_finished():
		return
	# Handle input events directly (works when paused)
	if InputManager.is_event_action(event, &"attack"):
		if event.is_pressed() and not _attack_pressed_last_frame:
			_attack_pressed_last_frame = true
			get_viewport().set_input_as_handled()
			var total := base_amount + bonus_amount
			finish(true, {"resource_type": resource_type, "amount": total})
		elif not event.is_pressed():
			_attack_pressed_last_frame = false
	elif InputManager.is_event_action(event, &"jump"):
		if event.is_pressed() and not _jump_pressed_last_frame:
			_jump_pressed_last_frame = true
			get_viewport().set_input_as_handled()
			finish(false, {"resource_type": resource_type, "amount": 0})
		elif not event.is_pressed():
			_jump_pressed_last_frame = false
