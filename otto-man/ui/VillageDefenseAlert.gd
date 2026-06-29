class_name VillageDefenseAlert
extends CanvasLayer
## Köyde bekleyen saldırıları üst banner'da gösterir; oynanabilir savunma butonu.

var _panel: PanelContainer
var _label: RichTextLabel
var _fight_button: Button


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	var wm: Node = get_node_or_null("/root/WorldManager")
	var tm: Node = get_node_or_null("/root/TimeManager")
	if wm and wm.has_signal("pending_attacks_changed"):
		if not wm.pending_attacks_changed.is_connected(refresh):
			wm.pending_attacks_changed.connect(refresh)
	if tm and tm.has_signal("minute_changed"):
		if not tm.minute_changed.is_connected(_on_minute_changed):
			tm.minute_changed.connect(_on_minute_changed)
	refresh()


func _on_minute_changed(_new_minute: int) -> void:
	refresh()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "DefenseAlertPanel"
	_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_panel.offset_left = 80.0
	_panel.offset_top = 8.0
	_panel.offset_right = -80.0
	_panel.offset_bottom = 110.0
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	margin.add_child(vbox)

	_label = RichTextLabel.new()
	_label.name = "DefenseAlertLabel"
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("normal_font_size", 14)
	_label.add_theme_color_override("default_color", Color(1.0, 0.92, 0.82))
	vbox.add_child(_label)

	_fight_button = Button.new()
	_fight_button.name = "FightButton"
	_fight_button.text = tr("defense.alert.fight_button")
	_fight_button.visible = false
	_fight_button.pressed.connect(_on_fight_pressed)
	vbox.add_child(_fight_button)

	visible = false


func _on_fight_pressed() -> void:
	var vm: Node = get_node_or_null("/root/VillageManager")
	if vm and vm.has_method("try_start_playable_village_defense"):
		vm.call("try_start_playable_village_defense")


func refresh() -> void:
	var wm: Node = get_node_or_null("/root/WorldManager")
	if wm == null or not wm.has_method("get_pending_attacks_ui_summaries"):
		visible = false
		return
	var summaries: Array = wm.call("get_pending_attacks_ui_summaries")
	if summaries.is_empty():
		visible = false
		return
	var lines: PackedStringArray = PackedStringArray()
	lines.append("[b]⚔ Bekleyen Saldırı[/b]")
	var any_playable: bool = false
	for summary in summaries:
		if not (summary is Dictionary):
			continue
		var s: Dictionary = summary
		var attacker: String = String(s.get("attacker", "?"))
		var time_text: String = String(s.get("hours_left_text", "?"))
		var win_pct: int = int(round(float(s.get("win_chance", 0.5)) * 100.0))
		var soldiers: int = int(s.get("soldier_count", 0))
		var deployed: bool = bool(s.get("deployed", false))
		var playable: bool = bool(s.get("playable_ready", false))
		if playable:
			any_playable = true
		var status: String = "Askerler sahada" if deployed else "Hazırlık"
		if playable:
			status = "SAVAŞ ZAMANI"
		var ally_line: String = ""
		if bool(s.get("alliance_defender", false)):
			var ally_name: String = String(s.get("defender_name", ""))
			if not ally_name.is_empty():
				ally_line = " · Muttefik: %s" % ally_name
		lines.append(
			"• [color=#ffb4b4]%s[/color] — %s · %d asker · Tahmini başarı: [b]%%%d[/b] · %s%s"
			% [attacker, time_text, soldiers, win_pct, status, ally_line]
		)
	if any_playable:
		lines.append("[color=#ffe08a]%s[/color]" % tr("defense.alert.playable_hint"))
	else:
		lines.append("[color=#aaaaaa]%s[/color]" % tr("defense.alert.auto_hint"))
	_label.text = "\n".join(lines)
	var can_fight: bool = any_playable and wm.has_method("can_start_playable_defense") and bool(wm.call("can_start_playable_defense"))
	_fight_button.visible = can_fight
	visible = true
