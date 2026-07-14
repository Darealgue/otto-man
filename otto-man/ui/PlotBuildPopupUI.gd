extends Control
class_name PlotBuildPopupUI
## Boş parselde kategori bazlı inşa popup'ı — parşömen temalı, oyunu durdurmaz.

signal build_selected(scene_path: String)
signal closed

const _Categories = preload("res://village/scripts/VillageBuildingCategories.gd")
const _MEDIEVAL_THEME := preload("res://resources/medieval_theme.tres")

const _CATEGORY_ACCENT := {
	0: Color(0.45, 0.75, 0.35, 1.0),  # RESOURCE - yeşil
	1: Color(0.55, 0.65, 0.85, 1.0),  # UTILITY - mavi
	2: Color(0.8, 0.35, 0.3, 1.0),    # MILITARY - kırmızı
	3: Color(0.85, 0.65, 0.85, 1.0),  # DECORATION - pembe
}

var _panel: PanelContainer
var _category_tabs: HBoxContainer
var _building_list: VBoxContainer
var _building_scroll: ScrollContainer
var _info_label: Label
var _plot_position: Vector2 = Vector2.ZERO
var _active_category: int = _Categories.Category.RESOURCE
var _is_open := false
var _category_buttons: Dictionary = {}
var _build_buttons: Array[Button] = []
var _build_button_paths: Array[String] = []
var _focused_row: int = 0
var _focus_generation: int = 0
var _suppress_nav_until_msec: int = 0


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


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.03, 0.02, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_gui_input)
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -320
	_panel.offset_top = -540
	_panel.offset_right = 320
	_panel.offset_bottom = 540
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	ParchmentTextures.apply_large_panel_style(_panel, 22)
	add_child(_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	_panel.add_child(root)

	var title := Label.new()
	title.text = "İnşa Et"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Yapmak istediğin binayı seç"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.modulate = Color(1, 1, 1, 0.75)
	root.add_child(subtitle)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color(0.6, 0.47, 0.28, 0.85)
	root.add_child(divider)

	var category_row := HBoxContainer.new()
	category_row.add_theme_constant_override("separation", 10)
	category_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(category_row)

	category_row.add_child(_make_key_chip("Q", "L2"))

	var arrow_left := Label.new()
	arrow_left.text = "◄"
	arrow_left.add_theme_font_size_override("font_size", 18)
	arrow_left.modulate = Color(0.85, 0.72, 0.4)
	category_row.add_child(arrow_left)

	_category_tabs = HBoxContainer.new()
	_category_tabs.add_theme_constant_override("separation", 8)
	_category_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	category_row.add_child(_category_tabs)

	var arrow_right := Label.new()
	arrow_right.text = "►"
	arrow_right.add_theme_font_size_override("font_size", 18)
	arrow_right.modulate = Color(0.85, 0.72, 0.4)
	category_row.add_child(arrow_right)

	category_row.add_child(_make_key_chip("E", "R2"))

	_building_scroll = ScrollContainer.new()
	_building_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_building_scroll.custom_minimum_size = Vector2(0, 600)
	_building_scroll.follow_focus = true
	root.add_child(_building_scroll)

	_building_list = VBoxContainer.new()
	_building_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_building_list.add_theme_constant_override("separation", 6)
	_building_scroll.add_child(_building_list)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	root.add_child(bottom)

	_info_label = Label.new()
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.add_theme_font_size_override("font_size", 12)
	_info_label.modulate = Color(1, 0.55, 0.5, 1)
	bottom.add_child(_info_label)

	root.add_child(_make_close_hint_bar())

	for cat in _Categories.CATEGORY_ORDER:
		var btn := Button.new()
		btn.text = _Categories.get_category_label(cat)
		btn.toggle_mode = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(120, 38)
		btn.set_meta("category", int(cat))
		btn.pressed.connect(_on_category_pressed.bind(int(cat)))
		_category_tabs.add_child(btn)
		_category_buttons[int(cat)] = btn

	TextOutline.apply_to_tree(self)


func _make_close_hint_bar() -> Control:
	var im := get_node_or_null("/root/InputManager")
	var is_pad := im != null and bool(im.get("last_input_from_joypad"))
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.add_theme_constant_override("separation", 4)
	var chip := PanelContainer.new()
	var sb_c := StyleBoxFlat.new()
	sb_c.bg_color = Color(0.22, 0.16, 0.08, 0.9)
	sb_c.border_width_left = 2; sb_c.border_width_top = 2
	sb_c.border_width_right = 2; sb_c.border_width_bottom = 2
	sb_c.border_color = Color(0.78, 0.64, 0.32, 1.0)
	sb_c.corner_radius_top_left = 5; sb_c.corner_radius_top_right = 5
	sb_c.corner_radius_bottom_left = 5; sb_c.corner_radius_bottom_right = 5
	sb_c.content_margin_left = 5; sb_c.content_margin_right = 5
	sb_c.content_margin_top = 1; sb_c.content_margin_bottom = 1
	chip.add_theme_stylebox_override("panel", sb_c)
	var chip_lbl := Label.new()
	chip_lbl.text = "Ⓑ" if is_pad else "ESC"
	chip_lbl.add_theme_font_size_override("font_size", 11)
	chip.add_child(chip_lbl)
	bar.add_child(chip)
	var close_lbl := Label.new()
	close_lbl.text = "Kapat"
	close_lbl.add_theme_font_size_override("font_size", 10)
	close_lbl.modulate = Color(1, 1, 1, 0.45)
	close_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(close_lbl)
	return bar


## Klavye tuşu + gamepad tetikleyicisini birlikte gösteren küçük "tuş" rozeti.
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
	col.alignment = BoxContainer.ALIGNMENT_CENTER
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


func show_for_plot(plot_position: Vector2) -> void:
	_reapply_full_rect()
	_plot_position = plot_position
	_is_open = true
	_focused_row = 0
	_focus_generation += 1
	_suppress_nav_until_msec = Time.get_ticks_msec() + 250
	get_viewport().gui_release_focus()
	_info_label.text = ""
	if get_parent():
		get_parent().move_child(self, -1)
	visible = true
	_select_category(int(_Categories.Category.RESOURCE))


func hide_popup() -> void:
	_is_open = false
	_focus_generation += 1
	visible = false
	get_viewport().gui_release_focus()
	_clear_building_list()
	closed.emit()


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
			_move_build_focus(1)
			return
		if event.is_action_pressed("ui_up"):
			get_viewport().set_input_as_handled()
			_move_build_focus(-1)
			return
		if event.is_action_pressed("ui_accept"):
			var owner := get_viewport().gui_get_focus_owner()
			if owner is Button and _build_buttons.find(owner) >= 0:
				get_viewport().set_input_as_handled()
				(owner as Button).pressed.emit()
				return
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_page_left") or InputManager.is_ui_page_left_just_pressed():
		get_viewport().set_input_as_handled()
		_suppress_nav_until_msec = Time.get_ticks_msec() + 120
		_cycle_category(-1)
		return
	if event.is_action_pressed("ui_page_right") or InputManager.is_ui_page_right_just_pressed():
		get_viewport().set_input_as_handled()
		_suppress_nav_until_msec = Time.get_ticks_msec() + 120
		_cycle_category(1)
		return


func _cycle_category(direction: int) -> void:
	var order: Array = _Categories.CATEGORY_ORDER
	var idx := order.find(_active_category)
	if idx < 0:
		idx = 0
	idx = wrapi(idx + direction, 0, order.size())
	_select_category(int(order[idx]))


func _select_category(cat: int) -> void:
	_active_category = cat
	_focused_row = 0
	for key in _category_buttons.keys():
		var btn: Button = _category_buttons[key]
		var is_active := int(key) == cat
		btn.button_pressed = is_active
		if is_active:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.32, 0.24, 0.12, 1.0)
			sb.border_width_left = 3
			sb.border_width_top = 3
			sb.border_width_right = 3
			sb.border_width_bottom = 3
			sb.border_color = _CATEGORY_ACCENT.get(cat, Color(0.9, 0.78, 0.35))
			sb.corner_radius_top_left = 6
			sb.corner_radius_top_right = 6
			sb.corner_radius_bottom_left = 6
			sb.corner_radius_bottom_right = 6
			btn.add_theme_stylebox_override("normal", sb)
			btn.add_theme_stylebox_override("pressed", sb)
		else:
			btn.remove_theme_stylebox_override("normal")
			btn.remove_theme_stylebox_override("pressed")
	_refresh_building_list()
	if visible and _is_open:
		_schedule_focus(_focus_generation)


func _on_category_pressed(cat: int) -> void:
	_select_category(cat)


func _schedule_focus(generation: int) -> void:
	_apply_focus_when_ready(generation)


func _apply_focus_when_ready(generation: int) -> void:
	await get_tree().process_frame
	if generation != _focus_generation or not _is_open or not visible:
		return
	await get_tree().process_frame
	if generation != _focus_generation or not _is_open or not visible:
		return
	await get_tree().process_frame
	if generation != _focus_generation or not _is_open or not visible:
		return
	_focus_nearest_enabled(_focused_row)


func _focus_nearest_enabled(preferred_index: int) -> bool:
	if _build_buttons.is_empty():
		return false
	var count := _build_buttons.size()
	for offset in range(count):
		var idx := (preferred_index + offset) % count
		var btn: Button = _build_buttons[idx]
		if not is_instance_valid(btn) or btn.disabled:
			continue
		_focused_row = idx
		get_viewport().gui_release_focus()
		btn.call_deferred("grab_focus")
		if is_instance_valid(_building_scroll):
			_building_scroll.ensure_control_visible(btn)
		return true
	return false


func _on_gui_focus_changed(control: Control) -> void:
	if not visible or not _is_open:
		return
	if control != null and control is Button and _build_buttons.find(control) >= 0:
		return
	call_deferred("_reclaim_build_focus")


func _reclaim_build_focus() -> void:
	if not visible or not _is_open:
		return
	var owner := get_viewport().gui_get_focus_owner()
	if owner is Button and _build_buttons.find(owner) >= 0:
		return
	_focus_nearest_enabled(_focused_row)


func _move_build_focus(direction: int) -> void:
	if _build_buttons.is_empty():
		return
	var count := _build_buttons.size()
	for step in range(count):
		var idx := wrapi(_focused_row + direction * (step + 1), 0, count)
		var btn: Button = _build_buttons[idx]
		if not is_instance_valid(btn) or btn.disabled:
			continue
		_focused_row = idx
		get_viewport().gui_release_focus()
		btn.grab_focus()
		if is_instance_valid(_building_scroll):
			_building_scroll.ensure_control_visible(btn)
		return


func _clear_building_list() -> void:
	_build_buttons.clear()
	_build_button_paths.clear()
	if _building_list == null:
		return
	for child in _building_list.get_children():
		_building_list.remove_child(child)
		child.free()


func _refresh_building_list() -> void:
	if _building_list == null:
		return
	_clear_building_list()

	var scenes := _Categories.get_scenes_for_category(_active_category as _Categories.Category)
	if scenes.is_empty():
		var empty := Label.new()
		empty.text = "Bu kategoride henüz bina yok."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.modulate = Color(1, 1, 1, 0.6)
		_building_list.add_child(empty)
		return

	for scene_path in scenes:
		_building_list.add_child(_make_building_row(scene_path))
	_trap_build_button_focus()


func _trap_build_button_focus() -> void:
	var count := _build_buttons.size()
	if count == 0:
		return
	for i in range(count):
		var btn: Button = _build_buttons[i]
		if not is_instance_valid(btn):
			continue
		var self_path := btn.get_path()
		btn.focus_neighbor_top = self_path
		btn.focus_neighbor_bottom = self_path
		btn.focus_neighbor_left = self_path
		btn.focus_neighbor_right = self_path


func _make_building_row(scene_path: String) -> Control:
	var accent: Color = _CATEGORY_ACCENT.get(_active_category, Color(0.7, 0.6, 0.4))
	var can_build := _can_build_scene(scene_path)

	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.16, 0.12, 0.08, 0.55) if can_build else Color(0.1, 0.08, 0.06, 0.4)
	card_style.corner_radius_top_left = 6
	card_style.corner_radius_top_right = 6
	card_style.corner_radius_bottom_left = 6
	card_style.corner_radius_bottom_right = 6
	card_style.border_width_left = 3
	card_style.set_content_margin_all(8)
	card_style.border_color = accent if can_build else Color(0.35, 0.32, 0.3, 0.6)
	card.add_theme_stylebox_override("panel", card_style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 2)
	row.add_child(text_col)

	var name_lbl := Label.new()
	name_lbl.text = LocaleManager.get_building_name(scene_path)
	name_lbl.add_theme_font_size_override("font_size", 16)
	if not can_build:
		name_lbl.modulate = Color(1, 1, 1, 0.55)
	text_col.add_child(name_lbl)

	var cost_row := HBoxContainer.new()
	cost_row.add_theme_constant_override("separation", 8)
	text_col.add_child(cost_row)
	_populate_cost_row(cost_row, scene_path, can_build)

	if not can_build:
		var reason := Label.new()
		reason.text = _format_lock_reason(scene_path)
		reason.add_theme_font_size_override("font_size", 11)
		reason.modulate = Color(1, 0.55, 0.5, 0.9)
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_col.add_child(reason)

	var build_btn := Button.new()
	build_btn.text = "İnşa Et" if can_build else "Kilitli"
	build_btn.disabled = not can_build
	build_btn.focus_mode = Control.FOCUS_ALL
	build_btn.custom_minimum_size = Vector2(96, 40)
	build_btn.pressed.connect(_on_build_pressed.bind(scene_path))
	build_btn.focus_entered.connect(_on_build_button_focus_entered.bind(_build_buttons.size()))
	_style_focus(build_btn)
	row.add_child(build_btn)
	_build_buttons.append(build_btn)
	_build_button_paths.append(scene_path)

	return card


func _on_build_button_focus_entered(index: int) -> void:
	_focused_row = index


func _populate_cost_row(cost_row: HBoxContainer, scene_path: String, can_build: bool) -> void:
	# Gösterilen fiyat, aktif VillageCardEffects kartlarını (altın çarpanı, kaynak
	# muafiyeti, bedava inşa) da yansıtır ki gerçekte ödenenle her zaman eşleşsin.
	var cost: Dictionary = VillageManager.get_effective_build_cost(scene_path)
	var ordered_keys: Array = []
	if cost.has("gold"):
		ordered_keys.append("gold")
	for key in cost.keys():
		if key != "gold":
			ordered_keys.append(key)

	var has_any_positive_amount := false
	for key in ordered_keys:
		if int(cost[key]) > 0:
			has_any_positive_amount = true
			break

	if not has_any_positive_amount:
		var free_lbl := Label.new()
		free_lbl.text = "Bedava"
		free_lbl.add_theme_font_size_override("font_size", 12)
		free_lbl.modulate = Color(0.6, 1.0, 0.6, 1.0) if can_build else Color(1, 1, 1, 0.5)
		cost_row.add_child(free_lbl)
		return

	for key in ordered_keys:
		var amount := int(cost[key])
		if amount <= 0:
			continue
		var key_str := String(key)
		var icon_path := _resource_icon_path(key_str)
		if not icon_path.is_empty():
			var icon := TextureRect.new()
			icon.custom_minimum_size = Vector2(16, 16)
			icon.texture = load(icon_path)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			cost_row.add_child(icon)
		var amt_lbl := Label.new()
		amt_lbl.text = str(amount)
		amt_lbl.add_theme_font_size_override("font_size", 12)
		if not can_build:
			amt_lbl.modulate = Color(1, 1, 1, 0.5)
		cost_row.add_child(amt_lbl)


func _resource_icon_path(resource_key: String) -> String:
	var candidates: Array[String] = []
	if resource_key == "tea":
		candidates = ["res://assets/Icons/coffee_icon.png", "res://assets/Icons/tea_icon.png"]
	elif resource_key == "soap":
		candidates = ["res://assets/Icons/perfume_icon.png", "res://assets/Icons/soap_icon.png"]
	else:
		candidates = ["res://assets/Icons/%s_icon.png" % resource_key]
	for path in candidates:
		if ResourceLoader.exists(path):
			return path
	return ""


func _format_lock_reason(scene_path: String) -> String:
	if not is_instance_valid(VillageManager):
		return "Gereksinimler karşılanmıyor."
	if scene_path != VillageManager.HOUSE_SCENE_PATH and VillageManager.does_building_exist(scene_path):
		return "Bu bina zaten mevcut."
	var reqs := VillageManager.get_building_requirements(scene_path)
	var cost: Dictionary = VillageManager.get_effective_build_cost(scene_path)
	var missing: PackedStringArray = PackedStringArray()
	for key in cost.keys():
		var key_str := String(key)
		var required := int(cost[key])
		if required <= 0:
			continue
		var current := int(GlobalPlayerData.gold) if key_str == "gold" else int(VillageManager.get_resource_level(key_str))
		if current < required:
			missing.append("%s %d/%d" % [LocaleManager.get_resource_name(key_str), current, required])
	if not missing.is_empty():
		return "Yetersiz: " + ", ".join(missing)
	var levels: Dictionary = reqs.get("requires_level", {})
	for key in levels.keys():
		var key_str := String(key)
		var required_level := int(levels[key])
		var current_level := int(VillageManager.get_available_resource_level(key_str))
		if current_level < required_level:
			return "Gerekli: %s Lv.%d" % [LocaleManager.get_resource_name(key_str), required_level]
	return "Gereksinimler karşılanmıyor."


func _can_build_scene(scene_path: String) -> bool:
	if not is_instance_valid(VillageManager):
		return false
	if scene_path != VillageManager.HOUSE_SCENE_PATH and VillageManager.does_building_exist(scene_path):
		return false
	if scene_path == VillageManager.HOUSE_SCENE_PATH and VillageManager.has_method("can_build_house_now"):
		if not VillageManager.can_build_house_now():
			return false
	return VillageManager.can_meet_requirements(scene_path)


func _on_build_pressed(scene_path: String) -> void:
	if not _can_build_scene(scene_path):
		_info_label.text = "Gereksinimler karşılanmıyor veya bina zaten var."
		return
	build_selected.emit(scene_path)
	hide_popup()
