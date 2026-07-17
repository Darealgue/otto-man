extends Control
class_name BarracksWeaponPopupUI
## Kışla — askerlere silah verme/alma. Parşömen temalı, controller/klavye odaklı
## tek-sütun liste (bkz. ConcubineMissionPopupUI.gd ile aynı navigasyon deseni).

signal closed

const _MEDIEVAL_THEME := preload("res://resources/medieval_theme.tres")

var _panel: PanelContainer
var _title_label: Label
var _stock_label: Label
var _equip_all_btn: Button
var _soldier_list: VBoxContainer
var _soldier_scroll: ScrollContainer
var _info_label: Label
var _nav_hint_label: Label

# Controller / keyboard navigation — tek düz liste: [0]=Tümünü Silahlandır, sonra her asker
var _nav_buttons: Array[Button] = []
var _focused_row: int = 0
var _suppress_nav_until_msec: int = 0

var _building: Node2D = null
var _is_open := false


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
	dim.color = Color(0.05, 0.03, 0.02, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_gui_input)
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5; _panel.anchor_right = 0.5
	_panel.anchor_top = 0.5; _panel.anchor_bottom = 0.5
	_panel.offset_left = -230
	_panel.offset_top = -260
	_panel.offset_right = 230
	_panel.offset_bottom = 260
	ParchmentTextures.apply_large_panel_style(_panel, 20)
	add_child(_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	_panel.add_child(root)

	_title_label = Label.new()
	_title_label.text = "Kışla — Silahlandırma"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 20)
	root.add_child(_title_label)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color(0.6, 0.47, 0.28, 0.85)
	root.add_child(divider)

	_stock_label = Label.new()
	_stock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stock_label.add_theme_font_size_override("font_size", 12)
	_stock_label.modulate = Color(0.85, 0.78, 0.6, 0.9)
	root.add_child(_stock_label)

	_equip_all_btn = Button.new()
	_equip_all_btn.text = "Tümünü Silahlandır"
	_equip_all_btn.custom_minimum_size = Vector2(0, 34)
	_equip_all_btn.pressed.connect(_on_equip_all_pressed)
	_style_focus(_equip_all_btn)
	root.add_child(_equip_all_btn)

	_soldier_scroll = ScrollContainer.new()
	_soldier_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_soldier_scroll.custom_minimum_size = Vector2(0, 260)
	_soldier_scroll.follow_focus = true
	_soldier_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_soldier_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	root.add_child(_soldier_scroll)

	_soldier_list = VBoxContainer.new()
	_soldier_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_soldier_list.add_theme_constant_override("separation", 6)
	_soldier_scroll.add_child(_soldier_list)

	_info_label = Label.new()
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.add_theme_font_size_override("font_size", 11)
	_info_label.modulate = Color(1, 0.8, 0.5, 1)
	root.add_child(_info_label)

	var hint_lbl := Label.new()
	_nav_hint_label = hint_lbl
	_update_nav_hint()
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.add_theme_font_size_override("font_size", 10)
	hint_lbl.modulate = Color(1, 1, 1, 0.45)
	root.add_child(hint_lbl)

	root.add_child(_make_close_hint_bar())
	TextOutline.apply_to_tree(self)


func _make_close_hint_bar() -> Control:
	var im := get_node_or_null("/root/InputManager")
	var is_pad := im != null and bool(im.get("last_input_from_joypad"))
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 4)
	bar.add_child(_make_chip("Ⓑ" if is_pad else "ESC"))
	var lbl := Label.new()
	lbl.text = "Kapat"
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.modulate = Color(1, 1, 1, 0.45)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(lbl)
	return bar


func _make_chip(key_text: String) -> Control:
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
	lbl.text = key_text
	lbl.add_theme_font_size_override("font_size", 11)
	chip.add_child(lbl)
	return chip


## Klavye/gamepad odak halkası: parşömen üzerinde farkedilir altın parlama.
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
	sb.expand_margin_left = 2
	sb.expand_margin_top = 2
	sb.expand_margin_right = 2
	sb.expand_margin_bottom = 2
	button.add_theme_stylebox_override("focus", sb)


# ─── Public API ───────────────────────────────────────────────────────────────

func show_for_barracks(building: Node2D) -> void:
	if not is_instance_valid(building) or not building.has_method("equip_soldier"):
		return
	_reapply_full_rect()
	_building = building
	_is_open = true
	_focused_row = 0
	_suppress_nav_until_msec = Time.get_ticks_msec() + 250
	_info_label.text = ""
	_update_nav_hint()
	get_viewport().gui_release_focus()
	_refresh()
	visible = true
	call_deferred("_grab_initial_focus")


func hide_popup() -> void:
	_is_open = false
	visible = false
	_building = null
	_nav_buttons.clear()
	get_viewport().gui_release_focus()
	closed.emit()


# ─── Soldier list ─────────────────────────────────────────────────────────────

func _refresh() -> void:
	_nav_buttons.clear()
	for child in _soldier_list.get_children():
		child.queue_free()
	if not is_instance_valid(_building):
		return

	var vm := get_node_or_null("/root/VillageManager")
	var stock := _get_stock(vm)
	_stock_label.text = "Stokta: %s %d   %s %d   %s %d" % [
		LocaleManager.get_resource_name("weapon_t1"), stock[1],
		LocaleManager.get_resource_name("weapon_t2"), stock[2],
		LocaleManager.get_resource_name("weapon_t3"), stock[3],
	]

	_nav_buttons.append(_equip_all_btn)
	_equip_all_btn.disabled = stock[1] + stock[2] + stock[3] <= 0

	var soldier_ids: Array = _building.assigned_worker_ids if "assigned_worker_ids" in _building else []
	if soldier_ids.is_empty():
		_add_empty_message("Kışlada asker yok. Önce köylü ata.")
		return

	for worker_id in soldier_ids:
		_soldier_list.add_child(_make_soldier_row(vm, int(worker_id)))


func _add_empty_message(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.modulate = Color(1, 1, 1, 0.55)
	_soldier_list.add_child(lbl)


func _make_soldier_row(vm: Node, worker_id: int) -> Control:
	var tier := _get_soldier_tier(worker_id)

	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	if tier > 0:
		sb.bg_color = Color(0.16, 0.12, 0.08, 0.6)
		sb.border_color = Color(0.45, 0.75, 0.35)
	else:
		sb.bg_color = Color(0.08, 0.07, 0.06, 0.45)
		sb.border_color = Color(0.5, 0.45, 0.3, 0.6)
	sb.corner_radius_top_left = 6; sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6; sb.corner_radius_bottom_right = 6
	sb.set_content_margin_all(8)
	sb.border_width_left = 3
	card.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	card.add_child(row)

	var name_lbl := Label.new()
	name_lbl.text = _get_worker_name(vm, worker_id)
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var tier_btn := Button.new()
	tier_btn.text = _tier_button_text(tier)
	tier_btn.custom_minimum_size = Vector2(150, 34)
	tier_btn.pressed.connect(_on_tier_button_pressed.bind(worker_id))
	_style_focus(tier_btn)
	row.add_child(tier_btn)
	_nav_buttons.append(tier_btn)

	return card


func _tier_button_text(tier: int) -> String:
	match tier:
		1: return "⚔ 1. Seviye Silah"
		2: return "⚔ 2. Seviye Silah"
		3: return "⚔ 3. Seviye Silah"
		_: return "Silahsız"


func _get_soldier_tier(worker_id: int) -> int:
	if not is_instance_valid(_building) or not ("soldier_equipment" in _building):
		return 0
	var equipment: Dictionary = _building.soldier_equipment
	if not equipment.has(worker_id):
		return 0
	return int(equipment[worker_id].get("weapon_tier", 0))


func _get_stock(vm: Node) -> Dictionary:
	if not is_instance_valid(vm):
		return {1: 0, 2: 0, 3: 0}
	return {
		1: int(vm.resource_levels.get("weapon_t1", 0)),
		2: int(vm.resource_levels.get("weapon_t2", 0)),
		3: int(vm.resource_levels.get("weapon_t3", 0)),
	}


func _get_worker_name(vm: Node, worker_id: int) -> String:
	if is_instance_valid(vm) and "all_workers" in vm:
		var all_workers: Dictionary = vm.all_workers
		if all_workers.has(worker_id):
			var instance = all_workers[worker_id].get("instance")
			if is_instance_valid(instance) and "NPC_Info" in instance:
				var info: Dictionary = instance.NPC_Info
				if info.has("Info") and info["Info"].has("Name"):
					var soldier_name := String(info["Info"]["Name"])
					if not soldier_name.is_empty():
						return soldier_name
	return "Asker #%d" % worker_id


# ─── Actions ──────────────────────────────────────────────────────────────────

func _on_tier_button_pressed(worker_id: int) -> void:
	if not is_instance_valid(_building):
		return
	var vm := get_node_or_null("/root/VillageManager")
	var stock := _get_stock(vm)
	var current := _get_soldier_tier(worker_id)
	var next := current
	# 0 -> 1 -> 2 -> 3 -> 0 döngüsü, stokta olmayan seviyeler atlanır.
	for step in range(1, 4):
		var candidate := (current + step) % 4
		if candidate == 0 or stock.get(candidate, 0) > 0:
			next = candidate
			break
	if next == current:
		_info_label.text = "Depoda hiç silah yok."
		return
	var ok: bool
	if next == 0:
		ok = _building.unequip_soldier(worker_id)
	else:
		ok = _building.equip_soldier(worker_id, next)
	_info_label.text = "" if ok else "İşlem başarısız."
	_refresh()
	_focus_nearest_nav_button(_focused_row)


func _on_equip_all_pressed() -> void:
	if not is_instance_valid(_building):
		return
	_building.equip_all_soldiers_with_available()
	_info_label.text = ""
	_refresh()
	_focus_nearest_nav_button(_focused_row)


# ─── Controller / keyboard navigation ─────────────────────────────────────────

func _grab_initial_focus() -> void:
	_focus_nearest_nav_button(0)


func _focus_nearest_nav_button(preferred_index: int) -> bool:
	if _nav_buttons.is_empty():
		return false
	var count := _nav_buttons.size()
	var start := clampi(preferred_index, 0, count - 1)
	for offset in range(count):
		var idx := (start + offset) % count
		var btn: Button = _nav_buttons[idx]
		if not is_instance_valid(btn) or btn.disabled:
			continue
		_focused_row = idx
		get_viewport().gui_release_focus()
		btn.grab_focus()
		if is_instance_valid(_soldier_scroll):
			_soldier_scroll.ensure_control_visible(btn)
		return true
	return false


func _move_focus(direction: int) -> void:
	if _nav_buttons.is_empty():
		return
	var count := _nav_buttons.size()
	for step in range(count):
		var idx := wrapi(_focused_row + direction * (step + 1), 0, count)
		var btn: Button = _nav_buttons[idx]
		if not is_instance_valid(btn) or btn.disabled:
			continue
		_focused_row = idx
		get_viewport().gui_release_focus()
		btn.grab_focus()
		if is_instance_valid(_soldier_scroll):
			_soldier_scroll.ensure_control_visible(btn)
		return


func _on_gui_focus_changed(control: Control) -> void:
	if not visible or not _is_open:
		return
	if control != null and control is Button and _nav_buttons.find(control) >= 0:
		_focused_row = _nav_buttons.find(control)
		return
	call_deferred("_reclaim_focus")


func _reclaim_focus() -> void:
	if not visible or not _is_open:
		return
	var owner := get_viewport().gui_get_focus_owner()
	if owner is Button and _nav_buttons.find(owner) >= 0:
		return
	_focus_nearest_nav_button(_focused_row)


func _update_nav_hint() -> void:
	if _nav_hint_label == null:
		return
	var im := get_node_or_null("/root/InputManager")
	var is_pad := im != null and bool(im.get("last_input_from_joypad"))
	if is_pad:
		_nav_hint_label.text = "[↑↓] Asker seç   [A] Silahı değiştir   [B] Kapat"
	else:
		_nav_hint_label.text = "[↑↓] Asker seç   [Enter] Silahı değiştir   [Esc] Kapat"


# ─── Input ────────────────────────────────────────────────────────────────────

func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		hide_popup()


func _input(event: InputEvent) -> void:
	if not visible or not _is_open:
		return
	# ui_back = ESC'nin bağlı olduğu ayrı aksiyon (ui_cancel sadece META/gamepad B içeriyor).
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_back"):
		get_viewport().set_input_as_handled()
		hide_popup()
		return
	var nav_blocked := Time.get_ticks_msec() < _suppress_nav_until_msec
	if not nav_blocked:
		if event.is_action_pressed("ui_down"):
			get_viewport().set_input_as_handled()
			_move_focus(1)
			return
		if event.is_action_pressed("ui_up"):
			get_viewport().set_input_as_handled()
			_move_focus(-1)
			return
		if event.is_action_pressed("ui_accept"):
			var owner := get_viewport().gui_get_focus_owner()
			if owner is Button and _nav_buttons.find(owner) >= 0:
				get_viewport().set_input_as_handled()
				(owner as Button).pressed.emit()
				return
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		get_viewport().set_input_as_handled()
