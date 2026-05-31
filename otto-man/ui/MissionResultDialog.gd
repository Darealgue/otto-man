extends CanvasLayer

signal confirmed

@onready var panel: Panel = $Root/Panel
@onready var title_label: Label = $Root/Panel/VBoxContainer/TitleLabel
@onready var message_label: Label = $Root/Panel/VBoxContainer/MessageLabel
@onready var rewards_container: VBoxContainer = $Root/Panel/VBoxContainer/RewardsContainer
@onready var confirm_button: Button = $Root/Panel/VBoxContainer/ConfirmButton

var _result_data: Dictionary = {}


func _ready() -> void:
	visible = false
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)
	if LocaleManager.has_signal("locale_changed"):
		LocaleManager.locale_changed.connect(_on_locale_changed)
	_refresh_static_labels()


func _on_locale_changed(_locale: String = "") -> void:
	_refresh_static_labels()
	if visible and not _result_data.is_empty():
		show_result(
			str(_result_data.get("type", "")),
			str(_result_data.get("mission_name", "")),
			_result_data.get("rewards", {}) if _result_data.get("rewards") is Dictionary else {},
			_result_data.get("penalties", {}) if _result_data.get("penalties") is Dictionary else {},
			int(_result_data.get("lost_items_count", 0))
		)


func _refresh_static_labels() -> void:
	if confirm_button:
		confirm_button.text = tr("mission.result.confirm")


func show_result(result_type: String, mission_name: String = "", rewards: Dictionary = {}, penalties: Dictionary = {}, lost_items_count: int = 0) -> void:
	_result_data = {
		"type": result_type,
		"mission_name": mission_name,
		"rewards": rewards,
		"penalties": penalties,
		"lost_items_count": lost_items_count,
	}

	visible = true

	var title_text: String = ""
	var message_text: String = ""

	match result_type:
		"completed":
			title_text = tr("mission.result.completed_title")
			message_text = tr("mission.result.completed_message") % mission_name
		"cancelled":
			title_text = tr("mission.result.cancelled_title")
			message_text = tr("mission.result.cancelled_message") % mission_name
		"failed":
			title_text = tr("mission.result.failed_title")
			message_text = tr("mission.result.failed_message") % mission_name
		"death":
			title_text = tr("mission.result.death_title")
			if lost_items_count > 0:
				message_text = tr("mission.result.death_message_items") % lost_items_count
			else:
				message_text = tr("mission.result.death_message")
		_:
			title_text = tr("mission.result.default_title")
			message_text = mission_name

	if title_label:
		title_label.text = title_text
	if message_label:
		message_label.text = message_text

	if rewards_container:
		for child in rewards_container.get_children():
			child.queue_free()

		if result_type == "completed" and not rewards.is_empty():
			var rewards_label = Label.new()
			rewards_label.text = tr("mission.result.rewards")
			rewards_label.add_theme_font_size_override("font_size", 18)
			rewards_container.add_child(rewards_label)

			for key in rewards.keys():
				var reward_item = Label.new()
				var value = rewards[key]
				reward_item.text = tr("mission.result.reward_line") % [String(key).capitalize(), str(value)]
				rewards_container.add_child(reward_item)

		if (result_type == "failed" or result_type == "cancelled") and not penalties.is_empty():
			var penalties_label = Label.new()
			penalties_label.text = tr("mission.result.penalties")
			penalties_label.add_theme_font_size_override("font_size", 18)
			penalties_label.modulate = Color(1.0, 0.5, 0.5)
			rewards_container.add_child(penalties_label)

			for key in penalties.keys():
				var penalty_item = Label.new()
				var value = penalties[key]
				penalty_item.text = tr("mission.result.penalty_line") % [String(key).capitalize(), str(value)]
				penalty_item.modulate = Color(1.0, 0.5, 0.5)
				rewards_container.add_child(penalty_item)

	_refresh_static_labels()
	if confirm_button:
		confirm_button.grab_focus()


func _on_confirm_pressed() -> void:
	if not visible:
		return
	visible = false
	confirmed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_confirm_pressed()
