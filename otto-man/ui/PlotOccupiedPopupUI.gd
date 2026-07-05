extends Control
class_name PlotOccupiedPopupUI
## Dolu parsel / bina: yükselt, yık, bilgi — parşömen temalı, oyunu durdurmaz.

signal upgrade_requested
signal build_house_requested
signal demolish_requested
signal info_requested
signal closed

const _MEDIEVAL_THEME := preload("res://resources/medieval_theme.tres")
const _WORKERS_ICON := "res://assets/Icons/workers_icon.png"

var _panel: PanelContainer
var _title_label: Label
var _level_label: Label
var _worker_row: HBoxContainer
var _worker_label: Label
var _upgrade_btn: Button
var _upgrade_cost_label: Label
var _build_house_btn: Button
var _build_house_cost_label: Label
var _demolish_btn: Button
var _building: Node2D = null
var _is_open := false


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
	_panel.offset_left = -200
	_panel.offset_top = -195
	_panel.offset_right = 200
	_panel.offset_bottom = 195
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	ParchmentTextures.apply_large_panel_style(_panel, 20)
	add_child(_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	_panel.add_child(root)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 22)
	root.add_child(_title_label)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color(0.6, 0.47, 0.28, 0.85)
	root.add_child(divider)

	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 6)
	root.add_child(stats)

	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", 14)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_child(_level_label)

	_worker_row = HBoxContainer.new()
	_worker_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_worker_row.add_theme_constant_override("separation", 6)
	stats.add_child(_worker_row)

	if ResourceLoader.exists(_WORKERS_ICON):
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(18, 18)
		icon.texture = load(_WORKERS_ICON)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_worker_row.add_child(icon)

	_worker_label = Label.new()
	_worker_label.add_theme_font_size_override("font_size", 14)
	_worker_row.add_child(_worker_label)

	stats.add_child(_make_worker_key_bar())

	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	root.add_child(actions)

	_upgrade_btn = Button.new()
	_upgrade_btn.text = "Yükselt"
	_upgrade_btn.custom_minimum_size = Vector2(0, 38)
	_upgrade_btn.pressed.connect(_on_upgrade_pressed)
	_style_focus(_upgrade_btn)
	actions.add_child(_upgrade_btn)

	_upgrade_cost_label = Label.new()
	_upgrade_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_upgrade_cost_label.add_theme_font_size_override("font_size", 11)
	_upgrade_cost_label.modulate = Color(1, 1, 1, 0.75)
	actions.add_child(_upgrade_cost_label)

	_build_house_btn = Button.new()
	_build_house_btn.text = "Ev İnşa Et"
	_build_house_btn.custom_minimum_size = Vector2(0, 38)
	_build_house_btn.pressed.connect(_on_build_house_pressed)
	_style_focus(_build_house_btn)
	actions.add_child(_build_house_btn)

	_build_house_cost_label = Label.new()
	_build_house_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_house_cost_label.add_theme_font_size_override("font_size", 11)
	_build_house_cost_label.modulate = Color(1, 1, 1, 0.75)
	actions.add_child(_build_house_cost_label)

	_demolish_btn = Button.new()
	_demolish_btn.text = "Yık"
	_demolish_btn.custom_minimum_size = Vector2(0, 34)
	_demolish_btn.pressed.connect(_on_demolish_pressed)
	_style_focus(_demolish_btn)
	actions.add_child(_demolish_btn)

	root.add_child(_make_close_hint_bar())
	TextOutline.apply_to_tree(self)


func _make_worker_key_bar() -> Control:
	var im := get_node_or_null("/root/InputManager")
	var is_pad := im != null and bool(im.get("last_input_from_joypad"))
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 4)
	if is_pad:
		bar.add_child(_make_chip("L2")); _add_bar_label(bar, "çıkar")
		bar.add_child(_make_chip("R2")); _add_bar_label(bar, "ekle")
	else:
		var rem: String = InputManager.get_action_key_name(&"village_worker_remove")
		var add_: String = InputManager.get_action_key_name(&"village_worker_add")
		bar.add_child(_make_chip(rem)); _add_bar_label(bar, "çıkar")
		bar.add_child(_make_chip(add_)); _add_bar_label(bar, "ekle")
	return bar


func _make_close_hint_bar() -> Control:
	var im := get_node_or_null("/root/InputManager")
	var is_pad := im != null and bool(im.get("last_input_from_joypad"))
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.add_theme_constant_override("separation", 4)
	bar.add_child(_make_chip("Ⓑ" if is_pad else "ESC"))
	_add_bar_label(bar, "Kapat", Color(1, 1, 1, 0.45))
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


func _add_bar_label(bar: HBoxContainer, text: String, color: Color = Color(1, 1, 1, 0.6)) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.modulate = color
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(lbl)


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


func show_for_building(building: Node2D) -> void:
	_reapply_full_rect()
	_building = building
	_is_open = true
	_refresh()
	visible = true
	call_deferred("_grab_initial_focus")


func _grab_initial_focus() -> void:
	if not visible:
		return
	if is_instance_valid(_upgrade_btn) and _upgrade_btn.visible and not _upgrade_btn.disabled:
		_upgrade_btn.grab_focus()
	elif is_instance_valid(_build_house_btn) and _build_house_btn.visible and not _build_house_btn.disabled:
		_build_house_btn.grab_focus()
	elif is_instance_valid(_demolish_btn):
		_demolish_btn.grab_focus()


func hide_popup() -> void:
	_is_open = false
	visible = false
	_building = null
	closed.emit()


func _refresh() -> void:
	if not is_instance_valid(_building) or _title_label == null:
		return
	var scene_path := String(_building.scene_file_path)
	_title_label.text = LocaleManager.get_building_name(scene_path) if not scene_path.is_empty() else _building.name
	var lvl := int(_building.level) if "level" in _building else 1
	var max_lvl := int(_building.max_level) if "max_level" in _building else 1
	var workers := int(_building.assigned_workers) if "assigned_workers" in _building else 0
	var max_w := int(_building.max_workers) if "max_workers" in _building else 0

	_level_label.text = "Seviye %d / %d" % [lvl, max_lvl]

	if max_w > 0:
		_worker_row.visible = true
		_worker_label.text = "%d / %d" % [workers, max_w]
		_worker_label.modulate = Color(0.55, 1.0, 0.55) if workers >= max_w else Color(1, 1, 1)
	else:
		_worker_row.visible = false

	var upgrading: bool = "is_upgrading" in _building and bool(_building.is_upgrading)
	var supports_upgrade := _building.has_method("start_upgrade")
	_upgrade_btn.visible = supports_upgrade
	_upgrade_cost_label.visible = supports_upgrade
	if supports_upgrade:
		if upgrading:
			_upgrade_btn.text = "Yükseltiliyor..."
			_upgrade_btn.disabled = true
			_upgrade_cost_label.text = ""
		elif lvl >= max_lvl:
			_upgrade_btn.text = "Maksimum Seviye"
			_upgrade_btn.disabled = true
			_upgrade_cost_label.text = ""
		else:
			_upgrade_btn.text = "Yükselt (Lv.%d)" % (lvl + 1)
			_upgrade_btn.disabled = false
			_upgrade_cost_label.text = _format_upgrade_cost(scene_path, lvl + 1)

	var supports_house_floor := false
	if is_instance_valid(VillageManager) and _building is Node2D:
		supports_house_floor = VillageManager.can_build_residential_floor_on(_building as Node2D)
		if not supports_house_floor and VillageManager.has_pending_house_floor_on(_building as Node2D):
			supports_house_floor = true
	_build_house_btn.visible = supports_house_floor
	_build_house_cost_label.visible = supports_house_floor
	if supports_house_floor:
		var pending_min := 0
		if is_instance_valid(VillageManager):
			pending_min = VillageManager.get_pending_house_floor_minutes_on(_building as Node2D)
		if pending_min > 0:
			_build_house_btn.text = "İnşa ediliyor..."
			_build_house_btn.disabled = true
			_build_house_cost_label.text = "Kalan: %.1f saat" % (float(pending_min) / 60.0)
		else:
			var has_floors := scene_path == VillageManager.HOUSE_SCENE_PATH
			if not has_floors:
				var ext := _building.get_node_or_null("ResidentialHousingExtension")
				if ext != null and "current_floors" in ext:
					has_floors = int(ext.current_floors) > 0
			_build_house_btn.text = "Kat Ekle" if has_floors else "Ev İnşa Et"
			_build_house_btn.disabled = not VillageManager.can_build_residential_floor_on(_building as Node2D)
			_build_house_cost_label.text = _format_house_build_cost()


func _format_house_build_cost() -> String:
	if not is_instance_valid(VillageManager):
		return ""
	var cost: Dictionary = VillageManager.get_building_requirements(VillageManager.HOUSE_SCENE_PATH).get("cost", {})
	if cost.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for key in cost.keys():
		var amount := int(cost[key])
		if amount <= 0:
			continue
		parts.append("%d %s" % [amount, LocaleManager.get_resource_name(String(key))])
	if parts.is_empty():
		return ""
	return "Maliyet: " + ", ".join(parts)


func _format_upgrade_cost(scene_path: String, target_level: int) -> String:
	var cost: Dictionary = BuildingUpgradeConfig.get_cost(scene_path, target_level)
	if cost.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for key in cost.keys():
		var amount := int(cost[key])
		if amount <= 0:
			continue
		parts.append("%d %s" % [amount, LocaleManager.get_resource_name(String(key))])
	if parts.is_empty():
		return ""
	return "Maliyet: " + ", ".join(parts)


func _on_upgrade_pressed() -> void:
	upgrade_requested.emit()
	hide_popup()


func _on_build_house_pressed() -> void:
	build_house_requested.emit()
	hide_popup()


func _on_demolish_pressed() -> void:
	demolish_requested.emit()
	hide_popup()


func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		hide_popup()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		hide_popup()
