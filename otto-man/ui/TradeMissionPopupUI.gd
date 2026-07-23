extends Control
class_name TradeMissionPopupUI
## Tüccar cariye üzerinden ticaret/kervan görevi başlatma — rota + mal + eskort seçimi.

signal closed

const _MEDIEVAL_THEME := preload("res://resources/medieval_theme.tres")

var _panel: PanelContainer
var _title_label: Label
var _content_scroll: ScrollContainer
var _route_list: VBoxContainer
var _details_box: VBoxContainer
var _info_label: Label

var _concubine: Concubine = null
var _is_open := false
var _selected_route: Dictionary = {}
var _selected_route_button: Button
var _selected_products: Dictionary = {}
var _soldier_count: int = 0


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


# ─── UI construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.02, 0.01, 0.52)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_gui_input)
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5; _panel.anchor_right = 0.5
	_panel.anchor_top = 0.5; _panel.anchor_bottom = 0.5
	_panel.offset_left = -320
	_panel.offset_top = -280
	_panel.offset_right = 320
	_panel.offset_bottom = 280
	ParchmentTextures.apply_large_panel_style(_panel, 22)
	add_child(_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	_panel.add_child(root)

	_title_label = Label.new()
	_title_label.text = "Ticaret Görevi"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 20)
	root.add_child(_title_label)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color(0.6, 0.47, 0.28, 0.85)
	root.add_child(divider)

	_content_scroll = ScrollContainer.new()
	_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_scroll.custom_minimum_size = Vector2(0, 420)
	_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_content_scroll)

	var content_col := VBoxContainer.new()
	content_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_col.add_theme_constant_override("separation", 10)
	_content_scroll.add_child(content_col)

	var route_title := Label.new()
	route_title.text = "Rota Seç"
	route_title.add_theme_font_size_override("font_size", 14)
	content_col.add_child(route_title)

	_route_list = VBoxContainer.new()
	_route_list.add_theme_constant_override("separation", 6)
	content_col.add_child(_route_list)

	_details_box = VBoxContainer.new()
	_details_box.add_theme_constant_override("separation", 6)
	content_col.add_child(_details_box)

	_info_label = Label.new()
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.add_theme_font_size_override("font_size", 11)
	_info_label.modulate = Color(1, 0.55, 0.5, 1)
	root.add_child(_info_label)

	var close_row := HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_END
	var close_btn := Button.new()
	close_btn.text = "Kapat"
	close_btn.focus_mode = Control.FOCUS_ALL
	close_btn.pressed.connect(hide_popup)
	_style_focus(close_btn)
	close_row.add_child(close_btn)
	root.add_child(close_row)

	TextOutline.apply_to_tree(self)


# ─── Public API ───────────────────────────────────────────────────────────────

func show_for_concubine(concubine: Concubine) -> void:
	_concubine = concubine
	_selected_route = {}
	_selected_products.clear()
	_soldier_count = 0
	_reapply_full_rect()
	_is_open = true
	_info_label.text = ""
	_refresh_routes()
	_refresh_details()
	visible = true
	call_deferred("_grab_initial_focus")
	_set_player_ui_locked(true)
	VillageManager.register_npc_dialogue_window_shown()


func hide_popup() -> void:
	_is_open = false
	visible = false
	_concubine = null
	closed.emit()
	_set_player_ui_locked(false)
	VillageManager.register_npc_dialogue_window_hidden()


func _set_player_ui_locked(locked: bool) -> void:
	var vm := get_node_or_null("/root/VillageManager")
	if vm and vm.get("Village_Player"):
		vm.Village_Player.set_ui_locked(locked)


# ─── Route list ───────────────────────────────────────────────────────────────

func _refresh_routes() -> void:
	for child in _route_list.get_children():
		child.queue_free()
	_selected_route_button = null
	var mm := get_node_or_null("/root/MissionManager")
	var routes: Array = mm.get_active_trade_routes() if mm and mm.has_method("get_active_trade_routes") else []
	if routes.is_empty():
		var lbl := Label.new()
		lbl.text = "Şu an aktif ticaret rotası yok."
		lbl.modulate = Color(1, 1, 1, 0.55)
		_route_list.add_child(lbl)
		return
	for route in routes:
		if route is Dictionary:
			var btn := _make_route_button(route as Dictionary)
			_route_list.add_child(btn)
			var is_selected: bool = not _selected_route.is_empty() and String(_selected_route.get("id", "")) == String((route as Dictionary).get("id", ""))
			if is_selected:
				_selected_route_button = btn


func _make_route_button(route: Dictionary) -> Button:
	var btn := Button.new()
	btn.text = "→ %s  (mesafe %.1f gün, risk %s)" % [
		String(route.get("to_name", "?")),
		float(route.get("distance", 0.0)),
		String(route.get("risk", "?")),
	]
	btn.focus_mode = Control.FOCUS_ALL
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var is_selected: bool = String(_selected_route.get("id", "")) == String(route.get("id", "")) and not _selected_route.is_empty()
	if is_selected:
		btn.modulate = Color(1.15, 1.05, 0.7)
	btn.pressed.connect(_on_route_selected.bind(route))
	_style_focus(btn)
	return btn


func _on_route_selected(route: Dictionary) -> void:
	_selected_route = route
	_selected_products.clear()
	_soldier_count = 0
	_info_label.text = ""
	_refresh_routes()
	_refresh_details()
	call_deferred("_grab_initial_focus")


# ─── Details (mal + eskort + başlat) ────────────────────────────────────────────

func _refresh_details() -> void:
	for child in _details_box.get_children():
		child.queue_free()
	if _selected_route.is_empty():
		return
	var mm := get_node_or_null("/root/MissionManager")

	var summary := Label.new()
	summary.text = "%s → %s  •  risk %s  •  mesafe %.1f gün" % [
		String(_selected_route.get("from_name", "?")),
		String(_selected_route.get("to_name", "?")),
		String(_selected_route.get("risk", "?")),
		float(_selected_route.get("distance", 0.0)),
	]
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_font_size_override("font_size", 12)
	summary.modulate = Color(0.85, 0.78, 0.6, 0.9)
	_details_box.add_child(summary)

	var goods_title := Label.new()
	goods_title.text = "Satılacak Mallar"
	goods_title.add_theme_font_size_override("font_size", 13)
	_details_box.add_child(goods_title)

	var products: Array = _selected_route.get("products", [])
	var any_available := false
	for resource in products:
		var available: int = VillageManager.get_resource_level(String(resource))
		if available <= 0:
			continue
		any_available = true
		_details_box.add_child(_make_product_stepper_row(String(resource), available))
	if not any_available:
		var none_lbl := Label.new()
		none_lbl.text = "Bu rotada satılabilecek stoklu bir mal yok."
		none_lbl.modulate = Color(1, 1, 1, 0.55)
		none_lbl.add_theme_font_size_override("font_size", 11)
		_details_box.add_child(none_lbl)

	var escort_title := Label.new()
	escort_title.text = "Eskort Asker"
	escort_title.add_theme_font_size_override("font_size", 13)
	_details_box.add_child(escort_title)
	_details_box.add_child(_make_soldier_stepper_row(mm))

	var start_btn := Button.new()
	start_btn.text = "Ticaret Görevini Başlat"
	start_btn.custom_minimum_size = Vector2(0, 36)
	start_btn.focus_mode = Control.FOCUS_ALL
	start_btn.pressed.connect(_on_execute_pressed)
	_style_focus(start_btn)
	_details_box.add_child(start_btn)


func _make_product_stepper_row(resource: String, available: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var name_lbl := Label.new()
	name_lbl.text = LocaleManager.get_resource_name(resource)
	name_lbl.custom_minimum_size.x = 90
	row.add_child(name_lbl)

	var minus_btn := Button.new()
	minus_btn.text = "−"
	minus_btn.custom_minimum_size = Vector2(28, 28)
	minus_btn.focus_mode = Control.FOCUS_ALL
	_style_focus(minus_btn)
	row.add_child(minus_btn)

	var qty_lbl := Label.new()
	qty_lbl.text = "0 / %d" % available
	qty_lbl.custom_minimum_size = Vector2(70, 0)
	qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(qty_lbl)

	var plus_btn := Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(28, 28)
	plus_btn.focus_mode = Control.FOCUS_ALL
	_style_focus(plus_btn)
	row.add_child(plus_btn)

	var step: int = maxi(1, available / 10)
	minus_btn.pressed.connect(_on_product_qty_changed.bind(resource, -step, available, qty_lbl))
	plus_btn.pressed.connect(_on_product_qty_changed.bind(resource, step, available, qty_lbl))

	return row


func _on_product_qty_changed(resource: String, delta: int, available: int, qty_lbl: Label) -> void:
	var cur: int = int(_selected_products.get(resource, 0))
	cur = clampi(cur + delta, 0, available)
	if cur <= 0:
		_selected_products.erase(resource)
	else:
		_selected_products[resource] = cur
	qty_lbl.text = "%d / %d" % [cur, available]


func _make_soldier_stepper_row(mm: Node) -> Control:
	var available: int = _get_available_soldiers(mm)
	_soldier_count = clampi(_soldier_count, 0, available)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var minus_btn := Button.new()
	minus_btn.text = "−"
	minus_btn.custom_minimum_size = Vector2(28, 28)
	minus_btn.focus_mode = Control.FOCUS_ALL
	_style_focus(minus_btn)
	row.add_child(minus_btn)

	var qty_lbl := Label.new()
	qty_lbl.text = "⚔ %d / %d" % [_soldier_count, available]
	qty_lbl.custom_minimum_size = Vector2(90, 0)
	qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(qty_lbl)

	var plus_btn := Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(28, 28)
	plus_btn.focus_mode = Control.FOCUS_ALL
	_style_focus(plus_btn)
	row.add_child(plus_btn)

	minus_btn.pressed.connect(_on_soldier_qty_changed.bind(-1, available, qty_lbl))
	plus_btn.pressed.connect(_on_soldier_qty_changed.bind(1, available, qty_lbl))

	return row


func _on_soldier_qty_changed(delta: int, available: int, qty_lbl: Label) -> void:
	_soldier_count = clampi(_soldier_count + delta, 0, available)
	qty_lbl.text = "⚔ %d / %d" % [_soldier_count, available]


func _get_available_soldiers(mm: Node) -> int:
	if mm == null or not mm.has_method("_find_barracks"):
		return 0
	var barracks = mm._find_barracks()
	if barracks == null:
		return 0
	var total := 0
	if "assigned_workers" in barracks:
		total = int(barracks.assigned_workers)
	elif "assigned_worker_ids" in barracks:
		total = (barracks.assigned_worker_ids as Array).size()
	else:
		return 0
	var on_mission := 0
	if mm.has_method("get_total_soldiers_on_mission"):
		on_mission = int(mm.get_total_soldiers_on_mission())
	return maxi(0, total - on_mission)


# ─── Başlat ────────────────────────────────────────────────────────────────────

func _on_execute_pressed() -> void:
	if _concubine == null or _selected_route.is_empty():
		return
	if _selected_products.is_empty():
		_info_label.text = "En az bir mal seçmelisiniz."
		return
	var mm := get_node_or_null("/root/MissionManager")
	if mm == null or not mm.has_method("create_trade_mission_for_route"):
		_info_label.text = "Görev sistemi bulunamadı."
		return
	for resource in _selected_products.keys():
		var qty: int = int(_selected_products[resource])
		var available: int = VillageManager.get_resource_level(String(resource))
		if qty > available:
			_info_label.text = "Yetersiz kaynak: %s" % LocaleManager.get_resource_name(String(resource))
			return
	var route_id: String = String(_selected_route.get("id", ""))
	var mission = mm.create_trade_mission_for_route(_concubine.id, route_id, _selected_products, _soldier_count)
	if mission == null:
		_info_label.text = "Görev oluşturulamadı."
		return
	mm.missions[mission.id] = mission
	var ok: bool = mm.assign_mission_to_concubine(_concubine.id, mission.id, _soldier_count)
	if not ok:
		_info_label.text = "Görev başlatılamadı."
		return
	for resource in _selected_products.keys():
		var qty: int = int(_selected_products[resource])
		var current: int = VillageManager.get_resource_level(String(resource))
		VillageManager.resource_levels[String(resource)] = maxi(0, current - qty)
	hide_popup()


# ─── Styling / odak ───────────────────────────────────────────────────────────

func _style_focus(button: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.3, 0.22, 0.1, 0.9)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(1.0, 0.85, 0.35, 1.0)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	button.add_theme_stylebox_override("focus", sb)


## Bu popup'ta mouse yok — klavye/gamepad'in ui_up/ui_down/ui_accept ile gezinebilmesi için
## Godot'un varsayılan Control odak sistemine (grab_focus + otomatik komşu hesabı) güveniyoruz,
## sadece açılışta/rota seçiminde odağı bilinçli bir butona veriyoruz.
func _grab_initial_focus() -> void:
	if is_instance_valid(_selected_route_button):
		_selected_route_button.grab_focus()
		return
	var btn := _find_first_button(_route_list)
	if btn:
		btn.grab_focus()


func _find_first_button(node: Node) -> Button:
	if node is Button:
		return node as Button
	for child in node.get_children():
		var found := _find_first_button(child)
		if found:
			return found
	return null


# ─── Input ────────────────────────────────────────────────────────────────────

func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		hide_popup()


func _input(event: InputEvent) -> void:
	if not visible or not _is_open:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_back"):
		get_viewport().set_input_as_handled()
		hide_popup()
