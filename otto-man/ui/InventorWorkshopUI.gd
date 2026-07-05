extends Control
## Mucit Odası upgrade paneli (placeholder UI).

const _MetaUpgradeConfig = preload("res://village/scripts/MetaUpgradeConfig.gd")
const _ExpeditionLootType = preload("res://resources/expedition_loot_types.gd")

var _panel: PanelContainer
var _loot_label: Label
var _track_list: VBoxContainer
var _close_btn: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
	var mum := get_node_or_null("/root/MetaUpgradeManager")
	if mum and mum.has_signal("meta_data_changed") and not mum.meta_data_changed.is_connected(_refresh):
		mum.meta_data_changed.connect(_refresh)


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(520, 420)
	_panel.offset_left = -260
	_panel.offset_top = -210
	_panel.offset_right = 260
	_panel.offset_bottom = 210
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(root_vbox)

	var title := Label.new()
	title.text = "Mucit Odası"
	title.add_theme_font_size_override("font_size", 22)
	root_vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Sefer ganimetlerini kalıcı geliştirmelere dönüştür."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_vbox.add_child(subtitle)

	_loot_label = Label.new()
	_loot_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_vbox.add_child(_loot_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 220)
	root_vbox.add_child(scroll)

	_track_list = VBoxContainer.new()
	_track_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_track_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_track_list)

	_close_btn = Button.new()
	_close_btn.text = "Kapat (Esc)"
	_close_btn.pressed.connect(hide_panel)
	root_vbox.add_child(_close_btn)


func show_panel() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_refresh()
	if _close_btn:
		_close_btn.grab_focus()


func hide_panel() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if get_tree().paused:
		get_tree().paused = false
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		hide_panel()


func _refresh() -> void:
	if not is_instance_valid(_loot_label) or not is_instance_valid(_track_list):
		return
	var mum := get_node_or_null("/root/MetaUpgradeManager")
	if mum == null:
		_loot_label.text = "MetaUpgradeManager bulunamadı."
		return
	var loot_parts: PackedStringArray = PackedStringArray()
	for lid in _ExpeditionLootType.all():
		var n := int(mum.get_village_loot(lid))
		if n > 0:
			loot_parts.append("%s: %d" % [_ExpeditionLootType.display_name(lid), n])
	_loot_label.text = "Köy stoku: " + (", ".join(loot_parts) if not loot_parts.is_empty() else "(boş)")

	for child in _track_list.get_children():
		child.queue_free()

	for track_id in _MetaUpgradeConfig.get_track_ids():
		_track_list.add_child(_make_track_row(String(track_id), mum))


func _make_track_row(track_id: String, mum: Node) -> Control:
	var track: Dictionary = _MetaUpgradeConfig.TRACKS.get(track_id, {})
	var box := PanelContainer.new()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	box.add_child(vbox)

	var title := Label.new()
	var lvl := int(mum.get_track_level(track_id))
	var max_lvl := int(track.get("max_level", 0))
	title.text = "%s  (%d / %d)" % [String(track.get("title", track_id)), lvl, max_lvl]
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = String(track.get("description", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	if lvl >= max_lvl:
		var done := Label.new()
		done.text = "Maksimum seviye."
		done.modulate = Color(0.7, 1.0, 0.7)
		vbox.add_child(done)
	else:
		var cost := mum.get_next_cost(track_id)
		var cost_lbl := Label.new()
		cost_lbl.text = "Maliyet: " + _MetaUpgradeConfig.format_cost(cost)
		vbox.add_child(cost_lbl)

		var buy := Button.new()
		buy.text = "Geliştir"
		buy.disabled = not mum.can_purchase_next(track_id)
		buy.pressed.connect(_on_buy_pressed.bind(track_id))
		vbox.add_child(buy)

	return box


func _on_buy_pressed(track_id: String) -> void:
	var mum := get_node_or_null("/root/MetaUpgradeManager")
	if mum and mum.try_purchase_upgrade(track_id):
		_refresh()
