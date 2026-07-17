extends Control
class_name CampfireRestPopupUI
## Kamp ateşi: dinlen / geceyi geçir — ekran karartma + tam dünya simülasyonu.

signal closed

const _MEDIEVAL_THEME := preload("res://resources/medieval_theme.tres")
const FADE_DURATION := 0.55
const MESSAGE_HOLD_SEC := 2.0

var _panel: PanelContainer
var _time_label: Label
var _info_label: Label
var _is_open := false
var _rest_sequence_active := false
var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _message_label: Label
var _action_buttons: Array[Button] = []
var _fade_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = _MEDIEVAL_THEME
	_build_ui()
	_build_rest_sequence_overlay()
	visible = false
	call_deferred("_reapply_full_rect")


func _reapply_full_rect() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_rest_sequence_overlay() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.name = "RestSequenceLayer"
	_fade_layer.layer = 120
	_fade_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_fade_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeRect"
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.color = Color(0.02, 0.02, 0.03, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade_layer.add_child(_fade_rect)

	_message_label = Label.new()
	_message_label.name = "RestMessage"
	_message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_message_label.offset_left = -260
	_message_label.offset_top = -80
	_message_label.offset_right = 260
	_message_label.offset_bottom = 80
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.add_theme_font_size_override("font_size", 26)
	_message_label.modulate = Color(1, 1, 1, 0)
	_fade_layer.add_child(_message_label)
	_fade_layer.visible = false


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.03, 0.02, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_gui_input)
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -210
	_panel.offset_top = -170
	_panel.offset_right = 210
	_panel.offset_bottom = 170
	ParchmentTextures.apply_large_panel_style(_panel, 20)
	add_child(_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	_panel.add_child(root)

	var title := Label.new()
	title.text = "Kamp Ateşi"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Dinlen ve zamanı ilerlet"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.modulate = Color(1, 1, 1, 0.75)
	root.add_child(subtitle)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color(0.6, 0.47, 0.28, 0.85)
	root.add_child(divider)

	_time_label = Label.new()
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.add_theme_font_size_override("font_size", 15)
	root.add_child(_time_label)

	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	root.add_child(actions)

	_add_rest_button(actions, "1 Saat Dinlen", 60, "🔥")
	_add_rest_button(actions, "4 Saat Dinlen", 240, "🔥🔥")
	_add_rest_button(actions, "Sabaha Kadar Uyu", -1, "🌙")

	_info_label = Label.new()
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.add_theme_font_size_override("font_size", 11)
	_info_label.modulate = Color(1, 0.55, 0.5, 1)
	root.add_child(_info_label)

	root.add_child(_make_close_hint_bar())
	TextOutline.apply_to_tree(self)


func _make_close_hint_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.add_theme_constant_override("separation", 4)
	var chip := _make_key_chip()
	bar.add_child(chip)
	var lbl := Label.new()
	lbl.text = "Kapat"
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.modulate = Color(1, 1, 1, 0.45)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(lbl)
	return bar


func _make_key_chip() -> Control:
	var im := get_node_or_null("/root/InputManager")
	var is_pad := im != null and bool(im.get("last_input_from_joypad"))
	var chip := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.22, 0.16, 0.08, 0.9)
	sb.border_width_left   = 2; sb.border_width_top    = 2
	sb.border_width_right  = 2; sb.border_width_bottom = 2
	sb.border_color = Color(0.78, 0.64, 0.32, 1.0)
	sb.corner_radius_top_left = 5; sb.corner_radius_top_right = 5
	sb.corner_radius_bottom_left = 5; sb.corner_radius_bottom_right = 5
	sb.content_margin_left = 5; sb.content_margin_right = 5
	sb.content_margin_top = 1; sb.content_margin_bottom = 1
	chip.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.text = "Ⓑ" if is_pad else "ESC"
	lbl.add_theme_font_size_override("font_size", 11)
	chip.add_child(lbl)
	return chip


func _add_rest_button(parent: VBoxContainer, label: String, minutes: int, icon: String) -> void:
	var btn := Button.new()
	btn.text = "%s  %s" % [icon, label]
	btn.custom_minimum_size = Vector2(0, 40)
	btn.pressed.connect(_on_rest_pressed.bind(minutes))
	_style_focus(btn)
	parent.add_child(btn)
	_action_buttons.append(btn)


func _style_focus(button: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.3, 0.22, 0.1, 0.9)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(1.0, 0.85, 0.35, 1.0)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	button.add_theme_stylebox_override("focus", sb)


func is_rest_sequence_active() -> bool:
	return _rest_sequence_active


func show_popup() -> void:
	_reapply_full_rect()
	_is_open = true
	_info_label.text = ""
	_refresh_time_label()
	_set_buttons_enabled(true)
	visible = true
	call_deferred("_grab_initial_focus")


func hide_popup() -> void:
	if _rest_sequence_active:
		return
	_is_open = false
	visible = false
	closed.emit()


func _refresh_time_label() -> void:
	var tm := get_node_or_null("/root/TimeManager")
	if tm:
		_time_label.text = tm.get_time_string()
	else:
		_time_label.text = ""


func _grab_initial_focus() -> void:
	for child in _panel.get_children():
		var btn := _find_first_button(child)
		if btn:
			btn.grab_focus()
			return


func _find_first_button(node: Node) -> Button:
	if node is Button:
		return node as Button
	for child in node.get_children():
		var found := _find_first_button(child)
		if found:
			return found
	return null


func _minutes_until_morning() -> int:
	var tm := get_node_or_null("/root/TimeManager")
	if tm == null:
		return 480
	var h: int = int(tm.hours)
	var m: int = int(tm.minutes)
	if h < TimeManager.WAKE_UP_HOUR:
		return (TimeManager.WAKE_UP_HOUR - h) * 60 - m
	var until_midnight := (24 - h) * 60 - m
	return until_midnight + TimeManager.WAKE_UP_HOUR * 60


func _on_rest_pressed(minutes: int) -> void:
	if _rest_sequence_active:
		return
	var advance := minutes if minutes > 0 else _minutes_until_morning()
	if advance <= 0:
		_info_label.text = "Zaten sabah."
		return
	_run_rest_sequence(advance, minutes)


func _run_rest_sequence(advance_minutes: int, option_minutes: int) -> void:
	_rest_sequence_active = true
	_set_buttons_enabled(false)
	_fade_layer.visible = true
	_fade_rect.color = Color(0.02, 0.02, 0.03, 0.0)
	_message_label.modulate = Color(1, 1, 1, 0)
	_panel.visible = false

	await _tween_fade_alpha(1.0, FADE_DURATION)

	var result: Dictionary = {}
	var vm := get_node_or_null("/root/VillageManager")
	if vm != null and vm.has_method("perform_campfire_rest"):
		result = vm.perform_campfire_rest(advance_minutes)
	else:
		var tm := get_node_or_null("/root/TimeManager")
		if tm != null and tm.has_method("advance_minutes"):
			tm.advance_minutes(advance_minutes)
			result = {"ok": true, "total_minutes": advance_minutes}

	var msg := _build_rest_message(advance_minutes, option_minutes, result)
	_message_label.text = msg
	await _tween_message_alpha(1.0, 0.35)
	await get_tree().create_timer(MESSAGE_HOLD_SEC).timeout
	await _tween_message_alpha(0.0, 0.35)
	await _tween_fade_alpha(0.0, FADE_DURATION)

	_fade_layer.visible = false
	_panel.visible = true
	_refresh_time_label()
	_rest_sequence_active = false
	_is_open = false
	visible = false
	closed.emit()


func _build_rest_message(advance_minutes: int, option_minutes: int, _result: Dictionary) -> String:
	var tm := get_node_or_null("/root/TimeManager")
	var time_line: String = ""
	if tm != null and tm.has_method("get_time_string"):
		time_line = tm.get_time_string()
	var heal_line := ""
	var ps := get_node_or_null("/root/PlayerStats")
	if ps != null and ps.has_method("get_max_health"):
		var max_hp: float = ps.get_max_health()
		var cur_hp: float = float(ps.get("current_health")) if "current_health" in ps else max_hp
		if cur_hp >= max_hp - 0.01:
			heal_line = "\n\n💚 Canın doldu"
		elif cur_hp > 0.01:
			heal_line = "\n\n💚 Can: %d / %d" % [int(roundf(cur_hp)), int(roundf(max_hp))]
	var body: String
	if option_minutes < 0:
		body = "🌙 Sabah oldu\n\n%s" % time_line
	elif advance_minutes == 60:
		body = "🔥 1 saat geçti\n\n%s" % time_line
	elif advance_minutes == 240:
		body = "🔥 4 saat geçti\n\n%s" % time_line
	else:
		var hours: float = float(advance_minutes) / 60.0
		if absf(hours - roundf(hours)) < 0.01:
			body = "🔥 %d saat geçti\n\n%s" % [int(roundf(hours)), time_line]
		else:
			body = "🔥 %.1f saat geçti\n\n%s" % [hours, time_line]
	return body + heal_line


func _tween_fade_alpha(target: float, duration: float) -> void:
	_kill_fade_tween()
	_fade_tween = create_tween()
	_fade_tween.set_ease(Tween.EASE_IN_OUT)
	_fade_tween.set_trans(Tween.TRANS_CUBIC)
	var col := _fade_rect.color
	col.a = target
	_fade_tween.tween_property(_fade_rect, "color", col, duration)
	await _fade_tween.finished


func _tween_message_alpha(target: float, duration: float) -> void:
	_kill_fade_tween()
	_fade_tween = create_tween()
	_fade_tween.set_ease(Tween.EASE_IN_OUT)
	_fade_tween.set_trans(Tween.TRANS_CUBIC)
	_fade_tween.tween_property(_message_label, "modulate:a", target, duration)
	await _fade_tween.finished


func _kill_fade_tween() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null


func _set_buttons_enabled(enabled: bool) -> void:
	for btn in _action_buttons:
		if is_instance_valid(btn):
			btn.disabled = not enabled


func _on_dim_gui_input(event: InputEvent) -> void:
	if _rest_sequence_active:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		hide_popup()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _rest_sequence_active:
		return
	# ui_back = ESC'nin bağlı olduğu ayrı aksiyon (ui_cancel sadece META/gamepad B içeriyor).
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_back"):
		get_viewport().set_input_as_handled()
		hide_popup()
