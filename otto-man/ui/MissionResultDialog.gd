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

func show_result(result_type: String, mission_name: String = "", rewards: Dictionary = {}, penalties: Dictionary = {}, lost_items_count: int = 0) -> void:
	_result_data = {
		"type": result_type,
		"mission_name": mission_name,
		"rewards": rewards,
		"penalties": penalties
	}
	
	visible = true
	
	# Set title based on type
	var title_text: String = ""
	var message_text: String = ""
	
	match result_type:
		"completed":
			title_text = "✅ Görev Tamamlandı"
			message_text = "'%s' görevi başarıyla tamamlandı!" % mission_name
		"cancelled":
			title_text = "⚠️ Görev İptal Edildi"
			message_text = "'%s' görevi iptal edildi." % mission_name
		"failed":
			title_text = "❌ Görev Başarısız"
			message_text = "'%s' görevi başarısız oldu." % mission_name
		"death":
			title_text = "💀 Kayboldunuz"
			if lost_items_count > 0:
				message_text = "Zindanda/ormanda kayboldunuz ve köye dönmek zorunda kaldınız.\n\nTopladığınız %d eşya kayboldu." % lost_items_count
			else:
				message_text = "Zindanda/ormanda kayboldunuz ve köye dönmek zorunda kaldınız."
		_:
			title_text = "Görev Sonucu"
			message_text = mission_name
	
	if title_label:
		title_label.text = title_text
	if message_label:
		message_label.text = message_text
	
	# Clear rewards container
	if rewards_container:
		for child in rewards_container.get_children():
			child.queue_free()
		
		# Show rewards if completed
		if result_type == "completed" and not rewards.is_empty():
			var rewards_label = Label.new()
			rewards_label.text = "\nÖdüller:"
			rewards_label.add_theme_font_size_override("font_size", 18)
			rewards_container.add_child(rewards_label)
			
			for key in rewards.keys():
				var reward_item = Label.new()
				var value = rewards[key]
				reward_item.text = "  • %s: +%s" % [key.capitalize(), str(value)]
				rewards_container.add_child(reward_item)
		
		# Show penalties if failed/cancelled
		if (result_type == "failed" or result_type == "cancelled") and not penalties.is_empty():
			var penalties_label = Label.new()
			penalties_label.text = "\nCeza/Cezalar:"
			penalties_label.add_theme_font_size_override("font_size", 18)
			penalties_label.modulate = Color(1.0, 0.5, 0.5)
			rewards_container.add_child(penalties_label)
			
			for key in penalties.keys():
				var penalty_item = Label.new()
				var value = penalties[key]
				penalty_item.text = "  • %s: %s" % [key.capitalize(), str(value)]
				penalty_item.modulate = Color(1.0, 0.5, 0.5)
				rewards_container.add_child(penalty_item)
	
	# Focus confirm button
	if confirm_button:
		confirm_button.grab_focus()

func _on_confirm_pressed() -> void:
	visible = false
	confirmed.emit()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	# Block all input except UI
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_on_confirm_pressed()
		get_viewport().set_input_as_handled()

