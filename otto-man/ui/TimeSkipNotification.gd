extends Control

@onready var notification_label: RichTextLabel = $BackgroundPanel/NotificationLabel
@onready var fade_timer: Timer = $FadeTimer
@onready var background_panel: Panel = $BackgroundPanel

var display_duration: float = 5.0

func _ready() -> void:
	if not fade_timer:
		# Fallback: create timer if missing
		fade_timer = Timer.new()
		fade_timer.name = "FadeTimer"
		fade_timer.wait_time = display_duration
		fade_timer.one_shot = true
		add_child(fade_timer)
		fade_timer.timeout.connect(_on_fade_timer_timeout)
	
	if not notification_label:
		# Fallback: create label if missing
		notification_label = RichTextLabel.new()
		notification_label.name = "NotificationLabel"
		notification_label.bbcode_enabled = true
		notification_label.fit_content = true
		notification_label.scroll_active = false
		if background_panel:
			background_panel.add_child(notification_label)
		else:
			add_child(notification_label)
		notification_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		notification_label.add_theme_constant_override("margin_left", 20)
		notification_label.add_theme_constant_override("margin_right", 20)
		notification_label.add_theme_constant_override("margin_top", 20)
		notification_label.add_theme_constant_override("margin_bottom", 20)
	
	if fade_timer:
		fade_timer.timeout.connect(_on_fade_timer_timeout)
	
	visible = false
	modulate.a = 0.0

func show_time_skip_notification(total_hours: float, produced_resources: Dictionary) -> void:
	print("[TimeSkipNotification] show_time_skip_notification called: %.1f hours, resources: %s" % [total_hours, produced_resources])
	print("[TimeSkipNotification] Node state - visible: %s, modulate.a: %.2f" % [visible, modulate.a])
	
	if not notification_label:
		print("[TimeSkipNotification] ⚠️ notification_label is null!")
		return
	
	# Set font size and color for readability
	notification_label.add_theme_font_size_override("font_size", 16)
	notification_label.add_theme_color_override("default_color", Color.WHITE)
	notification_label.text_direction = Control.TEXT_DIRECTION_AUTO
	
	var resource_names: Dictionary = {
		"wood": "Odun",
		"stone": "Taş",
		"food": "Yiyecek",
		"water": "Su",
		"lumber": "Kereste",
		"brick": "Tuğla",
		"metal": "Metal",
		"cloth": "Kumaş",
		"garment": "Giyim",
		"bread": "Ekmek",
		"tea": "Çay",
		"medicine": "İlaç",
		"soap": "Sabun",
		"weapon": "Silah",
		"armor": "Zırh"
	}
	
	# Build text with proper formatting
	var text_parts: Array[String] = []
	text_parts.append("Zaman Atlama Tamamlandı")
	text_parts.append("")
	text_parts.append("%.1f saat geçti" % total_hours)
	text_parts.append("")
	
	if produced_resources.is_empty():
		text_parts.append("Bu sürede kaynak üretilmedi")
	else:
		text_parts.append("Üretilen Kaynaklar:")
		for res in produced_resources.keys():
			var res_name = resource_names.get(res, res)
			var amount = produced_resources[res]
			text_parts.append("%s: +%d" % [res_name, amount])
	
	var text: String = ""
	for i in range(text_parts.size()):
		text += text_parts[i]
		if i < text_parts.size() - 1:
			text += "\n"
	
	# Set text and formatting
	# RichTextLabel doesn't have horizontal_alignment property
	# Use BBCode for centering instead
	notification_label.bbcode_enabled = true
	# Wrap text in center tags for alignment
	var centered_text: String = "[center]" + text + "[/center]"
	notification_label.text = centered_text
	notification_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Ensure proper size constraints
	notification_label.custom_minimum_size = Vector2(400, 200)
	
	print("[TimeSkipNotification] Text set: ", text.substr(0, min(100, text.length())))
	
	# Show with fade-in animation
	visible = true
	modulate.a = 1.0
	# Control nodes don't use z_index, ensure we're processable and visible
	set_process_mode(Node.PROCESS_MODE_ALWAYS)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Bring to front
	if get_parent():
		move_to_front()
	print("[TimeSkipNotification] ✅ Set visible=true, modulate.a=1.0, process_mode=ALWAYS")
	
	# Start fade-out timer
	if fade_timer:
		fade_timer.start(display_duration)
		print("[TimeSkipNotification] ✅ Fade timer started (%.1f seconds)" % display_duration)
	else:
		print("[TimeSkipNotification] ⚠️ Fade timer is null!")

func _on_fade_timer_timeout() -> void:
	# Fade out animation
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): visible = false)
