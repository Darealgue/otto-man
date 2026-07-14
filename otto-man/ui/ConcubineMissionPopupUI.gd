extends Control
class_name ConcubineMissionPopupUI
## Cariye üzerinden görev atama — portre + görev kartları, parşömen temalı.

signal mission_assigned(concubine_id: int, mission_id: String)
signal closed

const _MEDIEVAL_THEME := preload("res://resources/medieval_theme.tres")
const _PortraitRenderer := preload("res://ui/ConcubinePortraitRenderer.gd")

# Layout
var _panel: PanelContainer
var _portrait_rect: TextureRect
var _portrait_color: ColorRect
var _portrait_initial: Label
var _name_label: Label
var _status_chip: Label
var _stats_label: Label
var _mission_list: VBoxContainer
var _mission_scroll: ScrollContainer
var _info_label: Label
var _nav_hint_label: Label

# Controller / keyboard navigation
var _assign_buttons: Array[Button] = []
var _focused_mission_row: int = 0
var _focus_generation: int = 0
var _suppress_nav_until_msec: int = 0
var _portrait_generation: int = 0

# State
var _concubine: Concubine = null
var _is_open := false
## mission_id → selected soldier count (only relevant if required_army_size > 0)
var _soldier_counts: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = _MEDIEVAL_THEME
	_build_ui()
	visible = false
	var viewport := get_viewport()
	if viewport and not viewport.gui_focus_changed.is_connected(_on_gui_focus_changed):
		viewport.gui_focus_changed.connect(_on_gui_focus_changed)
	call_deferred("_reapply_full_rect")


func _reapply_full_rect() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# ─── UI construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.02, 0.01, 0.52)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_gui_input)
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.anchor_left   = 0.5; _panel.anchor_right  = 0.5
	_panel.anchor_top    = 0.5; _panel.anchor_bottom = 0.5
	_panel.offset_left   = -380
	_panel.offset_top    = -300
	_panel.offset_right  = 380
	_panel.offset_bottom = 300
	ParchmentTextures.apply_large_panel_style(_panel, 22)
	add_child(_panel)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	_panel.add_child(root)

	# ── Left column ──────────────────────────────────────────────────────────
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(190, 0)
	left.add_theme_constant_override("separation", 8)
	root.add_child(left)

	# Portrait box
	var portrait_wrapper := PanelContainer.new()
	portrait_wrapper.custom_minimum_size = Vector2(170, 170)
	portrait_wrapper.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var portrait_sb := StyleBoxFlat.new()
	portrait_sb.bg_color = Color(0.12, 0.09, 0.06, 0.7)
	portrait_sb.border_width_left   = 2
	portrait_sb.border_width_top    = 2
	portrait_sb.border_width_right  = 2
	portrait_sb.border_width_bottom = 2
	portrait_sb.border_color = Color(0.6, 0.45, 0.25, 0.9)
	portrait_sb.corner_radius_top_left     = 8
	portrait_sb.corner_radius_top_right    = 8
	portrait_sb.corner_radius_bottom_left  = 8
	portrait_sb.corner_radius_bottom_right = 8
	portrait_sb.set_content_margin_all(0)
	portrait_wrapper.add_theme_stylebox_override("panel", portrait_sb)
	left.add_child(portrait_wrapper)

	_portrait_color = ColorRect.new()
	_portrait_color.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait_color.color = Color(0.18, 0.13, 0.08, 1.0)
	portrait_wrapper.add_child(_portrait_color)

	_portrait_rect = TextureRect.new()
	_portrait_rect.name = "Portrait"
	_portrait_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_rect.visible = false
	portrait_wrapper.add_child(_portrait_rect)

	_portrait_initial = Label.new()
	_portrait_initial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait_initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portrait_initial.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_portrait_initial.add_theme_font_size_override("font_size", 64)
	_portrait_initial.modulate = Color(0.85, 0.68, 0.38, 0.7)
	portrait_wrapper.add_child(_portrait_initial)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 20)
	left.add_child(_name_label)

	_status_chip = Label.new()
	_status_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_chip.add_theme_font_size_override("font_size", 12)
	left.add_child(_status_chip)

	var stats_sep := ColorRect.new()
	stats_sep.custom_minimum_size = Vector2(0, 1)
	stats_sep.color = Color(0.6, 0.47, 0.28, 0.5)
	left.add_child(stats_sep)

	_stats_label = Label.new()
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats_label.add_theme_font_size_override("font_size", 12)
	left.add_child(_stats_label)

	# ── Divider ──────────────────────────────────────────────────────────────
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(2, 0)
	divider.size_flags_vertical = Control.SIZE_EXPAND_FILL
	divider.color = Color(0.6, 0.47, 0.28, 0.85)
	root.add_child(divider)

	# ── Right column ─────────────────────────────────────────────────────────
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	root.add_child(right)

	var missions_title := Label.new()
	missions_title.text = "Atanabilir Görevler"
	missions_title.add_theme_font_size_override("font_size", 16)
	right.add_child(missions_title)

	_mission_scroll = ScrollContainer.new()
	_mission_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_mission_scroll.custom_minimum_size = Vector2(0, 360)
	_mission_scroll.follow_focus = true
	_mission_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_mission_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	right.add_child(_mission_scroll)

	_mission_list = VBoxContainer.new()
	_mission_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mission_list.add_theme_constant_override("separation", 6)
	_mission_scroll.add_child(_mission_list)

	_info_label = Label.new()
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.add_theme_font_size_override("font_size", 11)
	_info_label.modulate = Color(1, 0.55, 0.5, 1)
	right.add_child(_info_label)

	var hint_lbl := Label.new()
	hint_lbl.name = "NavHint"
	_nav_hint_label = hint_lbl
	_update_nav_hint()
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_lbl.add_theme_font_size_override("font_size", 10)
	hint_lbl.modulate = Color(1, 1, 1, 0.45)
	right.add_child(hint_lbl)

	TextOutline.apply_to_tree(self)


# ─── Public API ───────────────────────────────────────────────────────────────

func show_for_concubine(concubine: Concubine) -> void:
	_concubine = concubine
	_soldier_counts.clear()
	_reapply_full_rect()
	_is_open = true
	_focus_generation += 1
	_focused_mission_row = 0
	_suppress_nav_until_msec = Time.get_ticks_msec() + 250
	_info_label.text = ""
	_update_nav_hint()
	get_viewport().gui_release_focus()
	_refresh_concubine_info()
	_refresh_missions()
	visible = true
	call_deferred("_focus_first_assign_button")


func hide_popup() -> void:
	_is_open = false
	_focus_generation += 1
	_portrait_generation += 1
	if is_instance_valid(_portrait_rect):
		_PortraitRenderer.clear(_portrait_rect)
	visible = false
	_concubine = null
	_assign_buttons.clear()
	get_viewport().gui_release_focus()
	closed.emit()


func hide_if_for_concubine(concubine_id: int) -> void:
	if not _is_open or _concubine == null:
		return
	if _concubine.id == concubine_id:
		hide_popup()


# ─── Info panel ───────────────────────────────────────────────────────────────

func _refresh_concubine_info() -> void:
	if _concubine == null:
		return

	var first_char: String = _concubine.name.substr(0, 1).to_upper() if not _concubine.name.is_empty() else "?"
	_portrait_initial.text = first_char
	_portrait_color.color = _role_color(_concubine.role)
	_portrait_generation += 1
	var portrait_gen: int = _portrait_generation
	if _concubine.appearance != null:
		_portrait_initial.visible = false
		_portrait_rect.visible = true
		_render_concubine_portrait(portrait_gen)
	else:
		_PortraitRenderer.clear(_portrait_rect)
		_portrait_rect.visible = false
		_portrait_initial.visible = true

	_name_label.text = _concubine.name

	var status_text: String
	var status_color: Color
	match _concubine.status:
		Concubine.Status.BOŞTA:
			status_text = "● Müsait"
			status_color = Color(0.45, 0.85, 0.4)
		Concubine.Status.GÖREVDE:
			status_text = "⚑ Görevde"
			status_color = Color(0.95, 0.72, 0.25)
		Concubine.Status.YARALI:
			status_text = "✚ Yaralı"
			status_color = Color(0.9, 0.3, 0.3)
		Concubine.Status.DİNLENİYOR:
			status_text = "♥ Dinleniyor"
			status_color = Color(0.55, 0.72, 0.95)
		_:
			status_text = "?"
			status_color = Color(1, 1, 1, 0.6)
	_status_chip.text = status_text
	_status_chip.modulate = status_color

	var lines: PackedStringArray = []
	lines.append("Seviye %d   HP %d/%d" % [_concubine.level, _concubine.health, _concubine.max_health])
	lines.append("Moral %d/%d" % [_concubine.moral, _concubine.max_moral])
	lines.append("")
	for skill in _concubine.skills.keys():
		var val := int(_concubine.skills[skill])
		var emoji := _concubine.get_skill_emoji(int(skill))
		var sname := _concubine.get_skill_name(int(skill))
		lines.append("%s %s  %d" % [emoji, sname, val])
	_stats_label.text = "\n".join(lines)


func _role_color(role: int) -> Color:
	match role:
		Concubine.Role.KOMUTAN:    return Color(0.35, 0.12, 0.12, 1.0)
		Concubine.Role.AJAN:       return Color(0.1, 0.22, 0.18, 1.0)
		Concubine.Role.DİPLOMAT:  return Color(0.15, 0.18, 0.35, 1.0)
		Concubine.Role.TÜCCAR:    return Color(0.28, 0.22, 0.08, 1.0)
		Concubine.Role.ALIM:      return Color(0.18, 0.22, 0.28, 1.0)
		Concubine.Role.TIBBIYECI: return Color(0.1, 0.28, 0.18, 1.0)
	return Color(0.14, 0.10, 0.07, 1.0)


# ─── Mission list ─────────────────────────────────────────────────────────────

func _render_concubine_portrait(portrait_gen: int) -> void:
	if _concubine == null:
		return
	await _PortraitRenderer.render(
		_portrait_rect,
		_concubine,
		self,
		func() -> bool:
			return portrait_gen != _portrait_generation or not _is_open
	)


func _refresh_missions() -> void:
	_assign_buttons.clear()
	for child in _mission_list.get_children():
		child.queue_free()
	if _concubine == null:
		return
	var mm := get_node_or_null("/root/MissionManager")
	if mm == null:
		_add_mission_empty("Görev sistemi bulunamadı.")
		return
	var missions: Array = mm.get_available_missions() if mm.has_method("get_available_missions") else []
	if missions.is_empty():
		_add_mission_empty("Şu an mevcut görev yok.")
		return
	var available_soldiers := _get_available_soldiers(mm)
	for mission in missions:
		_mission_list.add_child(_make_mission_row(mission, available_soldiers))


func _add_mission_empty(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.modulate = Color(1, 1, 1, 0.55)
	_mission_list.add_child(lbl)


func _make_mission_row(mission, available_soldiers: int) -> Control:
	var can_assign := _can_assign_mission(mission)
	var mid := _mission_id(mission)
	var req_army := _mission_required_army(mission)
	var needs_soldiers := req_army > 0

	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	if can_assign:
		sb.bg_color = Color(0.16, 0.12, 0.08, 0.6)
		sb.border_color = Color(0.45, 0.75, 0.35)
	else:
		sb.bg_color = Color(0.08, 0.07, 0.06, 0.45)
		sb.border_color = Color(0.3, 0.28, 0.26, 0.5)
	sb.corner_radius_top_left     = 6
	sb.corner_radius_top_right    = 6
	sb.corner_radius_bottom_left  = 6
	sb.corner_radius_bottom_right = 6
	sb.set_content_margin_all(8)
	sb.border_width_left = 3
	card.add_theme_stylebox_override("panel", sb)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)

	# Row 1: type badge + name
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 6)
	col.add_child(header_row)

	var type_badge := Label.new()
	type_badge.text = _mission_type_label(mission)
	type_badge.add_theme_font_size_override("font_size", 10)
	type_badge.modulate = _mission_type_color(mission) if can_assign else Color(1, 1, 1, 0.35)
	header_row.add_child(type_badge)

	var name_lbl := Label.new()
	name_lbl.text = _mission_name(mission)
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.modulate = Color(1, 1, 1, 1.0) if can_assign else Color(1, 1, 1, 0.45)
	header_row.add_child(name_lbl)

	# Row 2: details (duration / difficulty / required army)
	var detail_lbl := Label.new()
	detail_lbl.text = _mission_detail_line(mission, available_soldiers)
	detail_lbl.add_theme_font_size_override("font_size", 10)
	detail_lbl.modulate = Color(0.85, 0.78, 0.6, 0.85) if can_assign else Color(1, 1, 1, 0.3)
	col.add_child(detail_lbl)

	# Row 3: lock reason OR soldier stepper + assign button
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 6)
	col.add_child(action_row)

	if not can_assign:
		var reason := Label.new()
		reason.text = "⛔ " + _lock_reason(mission, available_soldiers)
		reason.add_theme_font_size_override("font_size", 10)
		reason.modulate = Color(1, 0.5, 0.45, 0.9)
		reason.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_row.add_child(reason)
	else:
		if needs_soldiers and not mid.is_empty():
			if not _soldier_counts.has(mid):
				_soldier_counts[mid] = req_army
			var cur_soldiers: int = _soldier_counts[mid]

			var minus_btn := Button.new()
			minus_btn.text = "−"
			minus_btn.custom_minimum_size = Vector2(30, 30)
			minus_btn.focus_mode = Control.FOCUS_NONE
			minus_btn.pressed.connect(_adjust_soldiers.bind(mid, -1, req_army, available_soldiers))
			_style_focus(minus_btn)
			action_row.add_child(minus_btn)

			var soldier_lbl := Label.new()
			soldier_lbl.text = "⚔ %d / %d" % [cur_soldiers, available_soldiers]
			soldier_lbl.add_theme_font_size_override("font_size", 12)
			soldier_lbl.custom_minimum_size = Vector2(80, 0)
			soldier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			soldier_lbl.name = "SoldierLabel_" + mid
			action_row.add_child(soldier_lbl)

			var plus_btn := Button.new()
			plus_btn.text = "+"
			plus_btn.custom_minimum_size = Vector2(30, 30)
			plus_btn.focus_mode = Control.FOCUS_NONE
			plus_btn.pressed.connect(_adjust_soldiers.bind(mid, 1, req_army, available_soldiers))
			_style_focus(plus_btn)
			action_row.add_child(plus_btn)

		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_row.add_child(spacer)

		var assign_btn := Button.new()
		assign_btn.text = "Ata"
		assign_btn.custom_minimum_size = Vector2(72, 34)
		assign_btn.focus_mode = Control.FOCUS_ALL
		assign_btn.pressed.connect(_on_assign_pressed.bind(mission))
		_style_focus(assign_btn)
		# Sol/Sağ ile asker sayısını ayarlayabilmek için (bkz. _input), gerekli veriyi
		# butonun meta'sında taşıyoruz — mouse'suz stepper kontrolü için.
		if needs_soldiers and not mid.is_empty():
			assign_btn.set_meta("mission_id", mid)
			assign_btn.set_meta("req_army", req_army)
			assign_btn.set_meta("available_soldiers", available_soldiers)
		action_row.add_child(assign_btn)
		_assign_buttons.append(assign_btn)

	return card


# ─── Soldier stepper ──────────────────────────────────────────────────────────

func _adjust_soldiers(mission_id: String, delta: int, req_min: int, available: int) -> void:
	if not _soldier_counts.has(mission_id):
		_soldier_counts[mission_id] = req_min
	var cur: int = _soldier_counts[mission_id]
	cur = clampi(cur + delta, req_min, available)
	_soldier_counts[mission_id] = cur
	_update_soldier_label(mission_id, available)


func _update_soldier_label(mission_id: String, available: int) -> void:
	var cur: int = _soldier_counts.get(mission_id, 0)
	# Find the label by name across the mission list
	var lbl := _find_named_node(_mission_list, "SoldierLabel_" + mission_id)
	if lbl is Label:
		(lbl as Label).text = "⚔ %d / %d" % [cur, available]


func _find_named_node(root: Node, target_name: String) -> Node:
	if root.name == target_name:
		return root
	for child in root.get_children():
		var found := _find_named_node(child, target_name)
		if found:
			return found
	return null


# ─── Helpers ──────────────────────────────────────────────────────────────────

func _get_available_soldiers(mm: Node) -> int:
	if not mm.has_method("_find_barracks"):
		return 0
	var barracks = mm._find_barracks()
	if barracks == null:
		return 0
	if "assigned_workers" in barracks:
		return int(barracks.assigned_workers)
	if "assigned_worker_ids" in barracks:
		return (barracks.assigned_worker_ids as Array).size()
	return 0


func _can_assign_mission(mission) -> bool:
	if _concubine == null:
		return false
	if _concubine.status != Concubine.Status.BOŞTA:
		return false
	if mission is Mission:
		if mission.required_concubine_id >= 0 and _concubine.id != mission.required_concubine_id:
			return false
		if mission.required_concubine_role >= 0 and int(_concubine.role) != mission.required_concubine_role:
			return false
		if not mission.is_unlocked_for_concubine(_concubine):
			return false
		return _concubine.can_handle_mission(mission)
	return true


func _lock_reason(mission, available_soldiers: int = 0) -> String:
	if _concubine == null:
		return "Uygun değil"
	match _concubine.status:
		Concubine.Status.GÖREVDE:
			return "Cariye zaten görevde"
		Concubine.Status.YARALI:
			return "Cariye yaralı — önce dinlenmeli"
		Concubine.Status.DİNLENİYOR:
			return "Cariye dinleniyor"
	if not (mission is Mission):
		return "Uygun değil"
	if mission.required_concubine_id >= 0 and _concubine.id != mission.required_concubine_id:
		return "Bu görev başka bir cariyeye özel"
	if mission.required_concubine_role >= 0 and int(_concubine.role) != mission.required_concubine_role:
		var role_name := _role_name(mission.required_concubine_role)
		return "Rol gereksinimi: %s" % role_name
	if not mission.is_unlocked_for_concubine(_concubine):
		if mission.unlock_leverage_min > 0:
			return "Kilitli — güven puanı yetersiz (min %d)" % mission.unlock_leverage_min
		if mission.unlock_level_min > 0:
			return "Kilitli — seviye %d gerekli" % mission.unlock_level_min
		return "Kilitli — hikâye koşulu"
	if _concubine.level < mission.required_cariye_level:
		return "Seviye %d gerekli (mevcut: %d)" % [mission.required_cariye_level, _concubine.level]
	if mission.required_army_size > 0 and available_soldiers < mission.required_army_size:
		return "Yetersiz asker — kışlada %d, görev min %d ister" % [available_soldiers, mission.required_army_size]
	if _concubine.health < 30:
		return "Sağlık çok düşük"
	if _concubine.moral < 20:
		return "Moral çok düşük"
	return "Uygun değil"


func _mission_name(mission) -> String:
	if mission is Mission:
		return mission.name
	if mission is Dictionary:
		return String(mission.get("name", "Görev"))
	return "Görev"


func _mission_id(mission) -> String:
	if mission is Mission:
		return mission.id
	if mission is Dictionary:
		return String(mission.get("id", ""))
	return ""


func _mission_required_army(mission) -> int:
	if mission is Mission:
		return mission.required_army_size
	if mission is Dictionary:
		return int(mission.get("required_army_size", 0))
	return 0


func _mission_detail_line(mission, available_soldiers: int) -> String:
	var parts: PackedStringArray = []
	if mission is Mission:
		var dur: float = mission.duration
		if dur > 0:
			parts.append(_format_duration(dur))
		var diff: String = _difficulty_label(mission.difficulty)
		if not diff.is_empty():
			parts.append(diff)
		if mission.required_cariye_level > 1:
			parts.append("Lv.%d+" % mission.required_cariye_level)
		if mission.required_army_size > 0:
			parts.append("⚔ min %d asker (mevcut: %d)" % [mission.required_army_size, available_soldiers])
	elif mission is Dictionary:
		var army := int(mission.get("required_army_size", 0))
		if army > 0:
			parts.append("⚔ min %d asker (mevcut: %d)" % [army, available_soldiers])
	return "  •  ".join(parts)


func _format_duration(minutes: float) -> String:
	if minutes <= 0:
		return ""
	var h := int(minutes) / 60
	var m := int(minutes) % 60
	if h > 0 and m > 0:
		return "%dsa %ddak" % [h, m]
	elif h > 0:
		return "%d saat" % h
	return "%d dak" % m


func _difficulty_label(difficulty: int) -> String:
	match difficulty:
		Mission.Difficulty.KOLAY:     return "Kolay"
		Mission.Difficulty.ORTA:      return "Orta"
		Mission.Difficulty.ZOR:       return "Zor"
		Mission.Difficulty.EFSANEVİ: return "Efsanevi"
	return ""


func _mission_type_label(mission) -> String:
	if not (mission is Mission):
		return "[Görev]"
	match mission.mission_type:
		Mission.MissionType.SAVAŞ:       return "[Savaş]"
		Mission.MissionType.KEŞİF:       return "[Keşif]"
		Mission.MissionType.DİPLOMASİ:   return "[Diplomasi]"
		Mission.MissionType.TİCARET:     return "[Ticaret]"
		Mission.MissionType.İSTİHBARAT:  return "[İstihbarat]"
		Mission.MissionType.BÜROKRASİ:   return "[Bürokrasi]"
	return "[Görev]"


func _mission_type_color(mission) -> Color:
	if not (mission is Mission):
		return Color(1, 1, 1, 0.7)
	match mission.mission_type:
		Mission.MissionType.SAVAŞ:       return Color(0.95, 0.4, 0.35)
		Mission.MissionType.KEŞİF:       return Color(0.45, 0.82, 0.48)
		Mission.MissionType.DİPLOMASİ:   return Color(0.45, 0.65, 0.95)
		Mission.MissionType.TİCARET:     return Color(0.95, 0.82, 0.3)
		Mission.MissionType.İSTİHBARAT:  return Color(0.75, 0.48, 0.9)
		Mission.MissionType.BÜROKRASİ:   return Color(0.78, 0.78, 0.78)
	return Color(1, 1, 1, 0.7)


func _role_name(role: int) -> String:
	match role:
		Concubine.Role.KOMUTAN:   return "Komutan"
		Concubine.Role.AJAN:      return "Ajan"
		Concubine.Role.DİPLOMAT: return "Diplomat"
		Concubine.Role.TÜCCAR:   return "Tüccar"
		Concubine.Role.ALIM:     return "Alim"
		Concubine.Role.TIBBIYECI: return "Tıbbiyeci"
	return "Belirtilmemiş"


# ─── Assign ───────────────────────────────────────────────────────────────────

func _on_assign_pressed(mission) -> void:
	if _concubine == null:
		return
	var mid := _mission_id(mission)
	if mid.is_empty():
		return
	var mm := get_node_or_null("/root/MissionManager")
	if mm == null or not mm.has_method("assign_mission_to_concubine"):
		_info_label.text = "Atama başarısız."
		return
	var soldiers := _soldier_counts.get(mid, 0) as int
	if mm.assign_mission_to_concubine(_concubine.id, mid, soldiers):
		mission_assigned.emit(_concubine.id, mid)
		hide_popup()
	else:
		_info_label.text = "Görev atanamadı."


# ─── Styling ──────────────────────────────────────────────────────────────────

func _style_focus(button: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.3, 0.22, 0.1, 0.9)
	sb.border_width_left   = 2
	sb.border_width_top    = 2
	sb.border_width_right  = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(1.0, 0.85, 0.35, 1.0)
	sb.corner_radius_top_left     = 6
	sb.corner_radius_top_right    = 6
	sb.corner_radius_bottom_left  = 6
	sb.corner_radius_bottom_right = 6
	button.add_theme_stylebox_override("focus", sb)


func _focus_first_assign_button() -> void:
	_focus_nearest_assign_button(_focused_mission_row)


func _focus_nearest_assign_button(preferred_index: int) -> bool:
	if _assign_buttons.is_empty():
		return false
	var count := _assign_buttons.size()
	for offset in range(count):
		var idx := (preferred_index + offset) % count
		var btn: Button = _assign_buttons[idx]
		if not is_instance_valid(btn) or btn.disabled:
			continue
		_focused_mission_row = idx
		get_viewport().gui_release_focus()
		btn.grab_focus()
		if is_instance_valid(_mission_scroll):
			_mission_scroll.ensure_control_visible(btn)
		return true
	return false


func _move_mission_focus(direction: int) -> void:
	if _assign_buttons.is_empty():
		return
	var count := _assign_buttons.size()
	for step in range(count):
		var idx := wrapi(_focused_mission_row + direction * (step + 1), 0, count)
		var btn: Button = _assign_buttons[idx]
		if not is_instance_valid(btn) or btn.disabled:
			continue
		_focused_mission_row = idx
		get_viewport().gui_release_focus()
		btn.grab_focus()
		if is_instance_valid(_mission_scroll):
			_mission_scroll.ensure_control_visible(btn)
		return


func _on_gui_focus_changed(control: Control) -> void:
	if not visible or not _is_open:
		return
	if control != null and control is Button and _assign_buttons.find(control) >= 0:
		_focused_mission_row = _assign_buttons.find(control)
		return
	call_deferred("_reclaim_mission_focus")


func _reclaim_mission_focus() -> void:
	if not visible or not _is_open:
		return
	var owner := get_viewport().gui_get_focus_owner()
	if owner is Button and _assign_buttons.find(owner) >= 0:
		return
	_focus_nearest_assign_button(_focused_mission_row)


func _update_nav_hint() -> void:
	if _nav_hint_label == null:
		return
	var im := get_node_or_null("/root/InputManager")
	var is_pad := im != null and bool(im.get("last_input_from_joypad"))
	if is_pad:
		_nav_hint_label.text = "[↑↓] Görev   [◄►] Asker   [A] Ata   [B] Kapat"
	else:
		_nav_hint_label.text = "[↑↓] Görev   [◄►] Asker   [Enter] Ata   [Esc] Kapat"


func _find_first_button(node: Node) -> Button:
	if node is Button:
		return node as Button
	for child in node.get_children():
		var found := _find_first_button(child)
		if found:
			return found
	return null


func _grab_initial_focus() -> void:
	_focus_first_assign_button()


# ─── Input ────────────────────────────────────────────────────────────────────

func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		hide_popup()


func _input(event: InputEvent) -> void:
	if not visible or not _is_open:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		hide_popup()
		return
	var nav_blocked := Time.get_ticks_msec() < _suppress_nav_until_msec
	if not nav_blocked:
		if event.is_action_pressed("ui_down"):
			get_viewport().set_input_as_handled()
			_move_mission_focus(1)
			return
		if event.is_action_pressed("ui_up"):
			get_viewport().set_input_as_handled()
			_move_mission_focus(-1)
			return
		if event.is_action_pressed("ui_accept"):
			var owner := get_viewport().gui_get_focus_owner()
			if owner is Button and _assign_buttons.find(owner) >= 0:
				get_viewport().set_input_as_handled()
				(owner as Button).pressed.emit()
				return
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			var owner := get_viewport().gui_get_focus_owner()
			if owner is Button and _assign_buttons.find(owner) >= 0 and owner.has_meta("req_army"):
				get_viewport().set_input_as_handled()
				var delta := -1 if event.is_action_pressed("ui_left") else 1
				_adjust_soldiers(
					String(owner.get_meta("mission_id")),
					delta,
					int(owner.get_meta("req_army")),
					int(owner.get_meta("available_soldiers"))
				)
				return
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		get_viewport().set_input_as_handled()
