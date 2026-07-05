extends Control
class_name MentorBriefPopupUI
## Rehber: köy/dünya haberleri + diplomasi özeti — parşömen temalı, oyunu durdurmaz.

signal closed

const _MEDIEVAL_THEME := preload("res://resources/medieval_theme.tres")

enum Tab { NEWS, MISSIONS, DIPLOMACY }

var _panel: PanelContainer
var _title_label: Label
var _content_scroll: ScrollContainer
var _content_list: VBoxContainer
var _news_village_col: VBoxContainer
var _news_world_col: VBoxContainer
var _tab_news_btn: Button
var _tab_missions_btn: Button
var _tab_diplo_btn: Button
var _active_tab: Tab = Tab.NEWS
var _is_open := false
var _missions_refresh_timer: float = 0.0
const SCROLL_STEP_PX := 56.0
## Panel ~4 kat alan (her eksen 2x): 1360×1000 px
const PANEL_HALF_W := 680.0
const PANEL_HALF_H := 500.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = _MEDIEVAL_THEME
	_build_ui()
	visible = false
	call_deferred("_reapply_full_rect")


func _reapply_full_rect() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


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
	_panel.offset_left = -PANEL_HALF_W
	_panel.offset_top = -PANEL_HALF_H
	_panel.offset_right = PANEL_HALF_W
	_panel.offset_bottom = PANEL_HALF_H
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	ParchmentTextures.apply_large_panel_style(_panel, 22)
	add_child(_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	_panel.add_child(root)

	_title_label = Label.new()
	_title_label.text = "Rehber"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 28)
	root.add_child(_title_label)

	var tab_row := HBoxContainer.new()
	tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_row.add_theme_constant_override("separation", 8)
	root.add_child(tab_row)

	tab_row.add_child(_make_key_chip("Q", "L2"))

	_tab_news_btn = Button.new()
	_tab_news_btn.text = "Haberler"
	_tab_news_btn.toggle_mode = true
	_tab_news_btn.focus_mode = Control.FOCUS_NONE
	_tab_news_btn.custom_minimum_size = Vector2(120, 40)
	_tab_news_btn.pressed.connect(_select_tab.bind(Tab.NEWS))
	tab_row.add_child(_tab_news_btn)

	_tab_missions_btn = Button.new()
	_tab_missions_btn.text = "Görevler"
	_tab_missions_btn.toggle_mode = true
	_tab_missions_btn.focus_mode = Control.FOCUS_NONE
	_tab_missions_btn.custom_minimum_size = Vector2(120, 40)
	_tab_missions_btn.pressed.connect(_select_tab.bind(Tab.MISSIONS))
	tab_row.add_child(_tab_missions_btn)

	_tab_diplo_btn = Button.new()
	_tab_diplo_btn.text = "Diplomasi"
	_tab_diplo_btn.toggle_mode = true
	_tab_diplo_btn.focus_mode = Control.FOCUS_NONE
	_tab_diplo_btn.custom_minimum_size = Vector2(120, 40)
	_tab_diplo_btn.pressed.connect(_select_tab.bind(Tab.DIPLOMACY))
	tab_row.add_child(_tab_diplo_btn)

	tab_row.add_child(_make_key_chip("E", "R2"))

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color(0.6, 0.47, 0.28, 0.85)
	root.add_child(divider)

	_content_scroll = ScrollContainer.new()
	_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_scroll.custom_minimum_size = Vector2(0, 820)
	_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_content_scroll.follow_focus = true
	root.add_child(_content_scroll)

	var scroll_hint := Label.new()
	scroll_hint.text = "↑ ↓ kaydır  ·  Q/E sekme"
	scroll_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scroll_hint.add_theme_font_size_override("font_size", 11)
	scroll_hint.modulate = Color(1, 1, 1, 0.4)
	root.add_child(scroll_hint)

	root.add_child(_make_close_hint_bar())
	TextOutline.apply_to_tree(self)


func _make_close_hint_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.add_theme_constant_override("separation", 4)
	var chip := _make_escape_chip()
	bar.add_child(chip)
	var lbl := Label.new()
	lbl.text = "Kapat"
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.modulate = Color(1, 1, 1, 0.45)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(lbl)
	return bar


func _make_escape_chip() -> Control:
	var im := get_node_or_null("/root/InputManager")
	var is_pad := im != null and bool(im.get("last_input_from_joypad"))
	var chip := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.22, 0.16, 0.08, 0.9)
	sb.border_width_left = 2; sb.border_width_top = 2
	sb.border_width_right = 2; sb.border_width_bottom = 2
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


func _make_key_chip(key_top: String, key_bottom: String) -> Control:
	var chip := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.22, 0.16, 0.08, 0.95)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.78, 0.64, 0.32, 1.0)
	sb.corner_radius_top_left = 5
	sb.corner_radius_top_right = 5
	sb.corner_radius_bottom_left = 5
	sb.corner_radius_bottom_right = 5
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", sb)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -2)
	chip.add_child(col)

	var top_lbl := Label.new()
	top_lbl.text = key_top
	top_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_lbl.add_theme_font_size_override("font_size", 13)
	col.add_child(top_lbl)

	var bottom_lbl := Label.new()
	bottom_lbl.text = key_bottom
	bottom_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom_lbl.add_theme_font_size_override("font_size", 9)
	bottom_lbl.modulate = Color(1, 1, 1, 0.65)
	col.add_child(bottom_lbl)

	return chip


func show_popup() -> void:
	_reapply_full_rect()
	_is_open = true
	_missions_refresh_timer = 0.0
	var mm := get_node_or_null("/root/MissionManager")
	var has_active := false
	if mm and mm.has_method("get_active_missions"):
		has_active = not mm.get_active_missions().is_empty()
	_select_tab(Tab.MISSIONS if has_active else Tab.NEWS)
	visible = true


func hide_popup() -> void:
	_is_open = false
	visible = false
	closed.emit()


func _select_tab(tab: Tab) -> void:
	_active_tab = tab
	_tab_news_btn.button_pressed = tab == Tab.NEWS
	_tab_missions_btn.button_pressed = tab == Tab.MISSIONS
	_tab_diplo_btn.button_pressed = tab == Tab.DIPLOMACY
	_style_active_tab(_tab_news_btn, tab == Tab.NEWS)
	_style_active_tab(_tab_missions_btn, tab == Tab.MISSIONS)
	_style_active_tab(_tab_diplo_btn, tab == Tab.DIPLOMACY)
	_missions_refresh_timer = 0.0
	_refresh_content()
	if is_instance_valid(_content_scroll):
		_content_scroll.scroll_vertical = 0


func _style_active_tab(btn: Button, active: bool) -> void:
	if active:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.32, 0.24, 0.12, 1.0)
		sb.border_width_left = 3
		sb.border_width_top = 3
		sb.border_width_right = 3
		sb.border_width_bottom = 3
		sb.border_color = Color(0.9, 0.78, 0.35)
		sb.corner_radius_top_left = 6
		sb.corner_radius_top_right = 6
		sb.corner_radius_bottom_left = 6
		sb.corner_radius_bottom_right = 6
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("pressed", sb)
	else:
		btn.remove_theme_stylebox_override("normal")
		btn.remove_theme_stylebox_override("pressed")


func _refresh_content() -> void:
	_clear_scroll_host()
	match _active_tab:
		Tab.NEWS:
			_setup_news_columns_host()
			_populate_news()
		Tab.MISSIONS:
			_setup_single_column_host()
			_populate_active_missions()
		Tab.DIPLOMACY:
			_setup_single_column_host()
			_populate_diplomacy()
	if is_instance_valid(_content_scroll):
		_content_scroll.scroll_vertical = 0


func _clear_scroll_host() -> void:
	if not is_instance_valid(_content_scroll):
		return
	for child in _content_scroll.get_children():
		child.queue_free()
	_content_list = null
	_news_village_col = null
	_news_world_col = null


func _setup_single_column_host() -> void:
	_content_list = VBoxContainer.new()
	_content_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_list.add_theme_constant_override("separation", 8)
	_content_scroll.add_child(_content_list)


func _setup_news_columns_host() -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 20)
	_content_scroll.add_child(row)

	_news_village_col = VBoxContainer.new()
	_news_village_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_news_village_col.add_theme_constant_override("separation", 8)
	row.add_child(_news_village_col)

	var sep := VSeparator.new()
	sep.custom_minimum_size.x = 2
	row.add_child(sep)

	_news_world_col = VBoxContainer.new()
	_news_world_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_news_world_col.add_theme_constant_override("separation", 8)
	row.add_child(_news_world_col)


func _populate_news() -> void:
	var mm := get_node_or_null("/root/MissionManager")
	if mm == null:
		_add_empty("Haber kaynağı bulunamadı.", _news_village_col)
		return
	var village_news: Array = mm.get_village_news() if mm.has_method("get_village_news") else []
	var world_news: Array = mm.get_world_news() if mm.has_method("get_world_news") else []
	if village_news.is_empty() and world_news.is_empty():
		_add_empty("Henüz haber yok.", _news_village_col)
		_add_empty("Henüz haber yok.", _news_world_col)
		return
	_add_section_header("🏘 Köy Haberleri", _news_village_col)
	if village_news.is_empty():
		_add_empty("Köy haberi yok.", _news_village_col)
	else:
		for n in village_news:
			_add_news_card(n, _news_village_col)
	_add_section_header("🌍 Dünya Haberleri", _news_world_col)
	if world_news.is_empty():
		_add_empty("Dünya haberi yok.", _news_world_col)
	else:
		for n in world_news:
			_add_news_card(n, _news_world_col)
	if mm.has_method("mark_all_news_read"):
		mm.mark_all_news_read("all")


func _populate_active_missions() -> void:
	var mm := get_node_or_null("/root/MissionManager")
	if mm == null:
		_add_empty("Görev sistemi bulunamadı.", _content_list)
		return
	var active: Dictionary = mm.get_active_missions() if mm.has_method("get_active_missions") else {}
	if active.is_empty():
		_add_empty(tr("mc.mission.list.active_empty_short"), _content_list)
		return
	for cariye_key in active.keys():
		var cariye_id: int = int(cariye_key)
		var mission_id: String = String(active[cariye_key])
		var cariye: Concubine = null
		if "concubines" in mm and mm.concubines.has(cariye_id):
			cariye = mm.concubines[cariye_id] as Concubine
		var mission_data = mm.missions.get(mission_id) if "missions" in mm and mm.missions.has(mission_id) else null
		_add_active_mission_card(cariye, mission_data, mission_id, mm)


func _populate_diplomacy() -> void:
	var wm := get_node_or_null("/root/WorldManager")
	if wm == null:
		_add_empty("Dünya haritası bilgisi yok.", _content_list)
		return
	if not wm.has_method("get_discovered_settlements"):
		_add_empty("Henüz keşfedilen köy yok.", _content_list)
		return
	var discovered: Array = wm.get_discovered_settlements()
	if discovered.is_empty():
		_add_empty("Henüz keşfedilen köy yok.\nDünya haritasında komşu köyleri keşfet.", _content_list)
		return
	var rows: Array[Dictionary] = []
	for raw in discovered:
		if not raw is Dictionary:
			continue
		var info: Dictionary = raw as Dictionary
		var sid: String = String(info.get("id", ""))
		if sid.is_empty():
			continue
		var display_name: String = String(info.get("name", sid))
		if wm.has_method("_get_settlement_display_name"):
			display_name = String(wm.call("_get_settlement_display_name", sid))
		var rel: int = 0
		if wm.has_method("get_relation"):
			rel = int(wm.get_relation("Köy", display_name))
		rows.append({"name": display_name, "relation": rel, "id": sid})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("name", "")).nocasecmp_to(String(b.get("name", ""))) < 0
	)
	var dm := get_node_or_null("/root/DiplomacyManager")
	_add_section_header("Keşfedilen Köyler", _content_list)
	for row in rows:
		var rel_val: int = int(row.get("relation", 0))
		var stance: String = String(dm.get_stance(rel_val)) if dm and dm.has_method("get_stance") else "?"
		_add_diplomacy_row(String(row.get("name", "?")), rel_val, stance)


func _add_section_header(text: String, parent: VBoxContainer) -> void:
	if parent == null:
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.modulate = Color(0.95, 0.82, 0.45)
	parent.add_child(lbl)


func _add_empty(text: String, parent: VBoxContainer) -> void:
	if parent == null:
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.modulate = Color(1, 1, 1, 0.55)
	lbl.add_theme_font_size_override("font_size", 14)
	parent.add_child(lbl)


func _add_news_card(news: Dictionary, parent: VBoxContainer) -> void:
	if parent == null:
		return
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.11, 0.08, 0.7)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	if not bool(news.get("read", false)):
		sb.border_width_left = 2
		sb.border_color = Color(0.85, 0.72, 0.35)
	card.add_theme_stylebox_override("panel", sb)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	card.add_child(col)

	var title := Label.new()
	title.text = news.get("title", "Haber")
	title.add_theme_font_size_override("font_size", 16)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)

	var body := Label.new()
	body.text = news.get("content", "")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 14)
	body.modulate = Color(1, 1, 1, 0.75)
	col.add_child(body)

	parent.add_child(card)


func _add_active_mission_card(cariye: Concubine, mission_data, mission_id: String, mm: Node) -> void:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.11, 0.08, 0.75)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.set_content_margin_all(10)
	sb.border_width_left = 3
	sb.border_color = Color(0.45, 0.75, 0.35, 0.85)
	card.add_theme_stylebox_override("panel", sb)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)

	var cariye_name: String = cariye.name if cariye != null else tr("cariye.unknown")
	var mission_name: String = mission_id
	if mm.has_method("get_mission_display_name"):
		mission_name = String(mm.get_mission_display_name(mission_data if mission_data != null else mission_id))
	elif mission_data is Mission:
		mission_name = mission_data.name
	elif mission_data is Dictionary:
		mission_name = String(mission_data.get("name", mission_id))

	var title := Label.new()
	title.text = "%s → %s" % [cariye_name, mission_name]
	title.add_theme_font_size_override("font_size", 14)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)

	var remaining: float = _get_mission_remaining_minutes(mission_data)
	var duration: float = _get_mission_duration_minutes(mission_data)
	var progress_pct: float = 0.0
	if duration > 0.0:
		progress_pct = clampf((duration - remaining) / duration * 100.0, 0.0, 100.0)

	var badge_row := HBoxContainer.new()
	badge_row.add_theme_constant_override("separation", 8)
	col.add_child(badge_row)

	var status_lbl := Label.new()
	var status_text: String = tr("mc.mission.active.in_progress")
	if remaining <= 0.0:
		status_text = tr("mc.mission.active.completing")
	status_lbl.text = "🟢 %s" % status_text
	status_lbl.add_theme_font_size_override("font_size", 11)
	status_lbl.modulate = Color(0.55, 0.95, 0.5)
	badge_row.add_child(status_lbl)

	if mission_data is Mission:
		var type_lbl := Label.new()
		type_lbl.text = "🎯 %s" % mission_data.get_mission_type_name()
		type_lbl.add_theme_font_size_override("font_size", 11)
		type_lbl.modulate = Color(0.65, 0.78, 0.95)
		badge_row.add_child(type_lbl)

	var soldiers := _get_assigned_soldier_count(mission_data, mission_id, mm)
	if soldiers > 0:
		var soldier_lbl := Label.new()
		soldier_lbl.text = "⚔ %d" % soldiers
		soldier_lbl.add_theme_font_size_override("font_size", 11)
		soldier_lbl.modulate = Color(0.95, 0.75, 0.45)
		badge_row.add_child(soldier_lbl)

	var time_lbl := Label.new()
	time_lbl.text = tr("mc.mission.active.time_left") % _format_game_time_minutes(remaining)
	time_lbl.add_theme_font_size_override("font_size", 12)
	time_lbl.modulate = Color(1.0, 0.92, 0.45)
	col.add_child(time_lbl)

	var progress_row := HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 6)
	col.add_child(progress_row)

	var progress_lbl := Label.new()
	progress_lbl.text = tr("mc.mission.active.progress")
	progress_lbl.add_theme_font_size_override("font_size", 11)
	progress_lbl.modulate = Color(0.7, 0.85, 1.0)
	progress_row.add_child(progress_lbl)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = progress_pct
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, 16)
	bar.add_theme_color_override("fill", Color(0.25, 0.72, 0.28))
	progress_row.add_child(bar)

	var pct_lbl := Label.new()
	pct_lbl.text = "%d%%" % int(progress_pct)
	pct_lbl.add_theme_font_size_override("font_size", 11)
	progress_row.add_child(pct_lbl)

	_content_list.add_child(card)


func _get_mission_remaining_minutes(mission_data) -> float:
	if mission_data is Mission and mission_data.has_method("get_remaining_time"):
		return float(mission_data.get_remaining_time())
	if mission_data is Dictionary:
		var tm := get_node_or_null("/root/TimeManager")
		var duration: float = float(mission_data.get("duration", 120.0))
		if tm and tm.has_method("get_total_game_minutes"):
			var start_min: int = int(mission_data.get("started_total_minutes", tm.get_total_game_minutes()))
			var now_min: int = int(tm.get_total_game_minutes())
			return maxf(0.0, duration - float(now_min - start_min))
	return 0.0


func _get_mission_duration_minutes(mission_data) -> float:
	if mission_data is Mission:
		return maxf(1.0, float(mission_data.duration))
	if mission_data is Dictionary:
		return maxf(1.0, float(mission_data.get("duration", 120.0)))
	return 1.0


func _get_assigned_soldier_count(mission_data, mission_id: String, mm: Node) -> int:
	if mission_data is Dictionary:
		var n := int(mission_data.get("assigned_soldiers", 0))
		if n > 0:
			return n
	if mm.has_method("get_raid_mission_extra"):
		var extra: Dictionary = mm.get_raid_mission_extra(mission_id)
		var wids: Array = extra.get("assigned_soldier_worker_ids", [])
		if wids is Array and not wids.is_empty():
			return wids.size()
	return 0


func _format_game_time_minutes(minutes: float) -> String:
	var total_minutes := int(minutes)
	if total_minutes <= 0:
		return tr("mc.time.completed")
	var hours := total_minutes / 60
	var remaining_minutes := total_minutes % 60
	if hours > 0 and remaining_minutes > 0:
		return tr("mc.time.hours_minutes") % [hours, remaining_minutes]
	if hours > 0:
		return tr("mc.time.hours") % hours
	return tr("mc.time.minutes_only") % remaining_minutes


func _add_diplomacy_row(faction_name: String, relation: int, stance: String) -> void:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.11, 0.08, 0.7)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)

	var name_lbl := Label.new()
	name_lbl.text = faction_name
	name_lbl.custom_minimum_size.x = 120
	name_lbl.add_theme_font_size_override("font_size", 14)
	row.add_child(name_lbl)

	var bar := ProgressBar.new()
	bar.min_value = -100
	bar.max_value = 100
	bar.value = relation
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size.y = 18
	row.add_child(bar)

	var stance_lbl := Label.new()
	stance_lbl.text = stance
	stance_lbl.add_theme_font_size_override("font_size", 12)
	stance_lbl.modulate = Color(0.7, 0.85, 1.0)
	row.add_child(stance_lbl)

	_content_list.add_child(card)


func _cycle_tab(direction: int) -> void:
	var tabs := [Tab.NEWS, Tab.MISSIONS, Tab.DIPLOMACY]
	var idx := tabs.find(_active_tab)
	idx = wrapi(idx + direction, 0, tabs.size())
	_select_tab(tabs[idx])


func _process(delta: float) -> void:
	if not visible or _active_tab != Tab.MISSIONS:
		return
	_missions_refresh_timer += delta
	if _missions_refresh_timer >= 2.0:
		_missions_refresh_timer = 0.0
		_refresh_content()


func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		hide_popup()


func _scroll_content(delta_px: float) -> void:
	if not is_instance_valid(_content_scroll):
		return
	var vbar := _content_scroll.get_v_scroll_bar()
	var max_v := vbar.max_value if vbar != null else 0.0
	var next := clampf(float(_content_scroll.scroll_vertical) + delta_px, 0.0, max_v)
	_content_scroll.scroll_vertical = int(next)


func _input(event: InputEvent) -> void:
	if not visible or not _is_open:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		hide_popup()
		return
	if event.is_action_pressed("ui_down") or InputManager.is_ui_down_just_pressed():
		get_viewport().set_input_as_handled()
		_scroll_content(SCROLL_STEP_PX)
		return
	if event.is_action_pressed("ui_up") or InputManager.is_ui_up_just_pressed():
		get_viewport().set_input_as_handled()
		_scroll_content(-SCROLL_STEP_PX)
		return
	if event.is_action_pressed("ui_page_left") or InputManager.is_ui_page_left_just_pressed():
		get_viewport().set_input_as_handled()
		_cycle_tab(-1)
		return
	if event.is_action_pressed("ui_page_right") or InputManager.is_ui_page_right_just_pressed():
		get_viewport().set_input_as_handled()
		_cycle_tab(1)
		return


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# _input'ta işlendi; burada yalnızca yedek
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		hide_popup()
