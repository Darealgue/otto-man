extends Control
## Mucit Odası upgrade paneli — her geliştirme (seviyeleri değil, geliştirmenin kendisi)
## TEK bir kare; kareler yan yana dizilip sıra dolunca alt satıra geçiyor (GridContainer).
## Üstte odaklanılan/üzerine gelinen karenin açıklaması gösteriliyor. Yeni bir geliştirme
## eklendiğinde (MetaUpgradeConfig.TRACKS'e yeni bir track eklenerek) otomatik olarak
## grid'e bir kare daha eklenir — bu dosyada değişiklik gerekmez.

const _MetaUpgradeConfig = preload("res://village/scripts/MetaUpgradeConfig.gd")
const _ExpeditionLootType = preload("res://resources/expedition_loot_types.gd")

const _SQUARE_SIZE := Vector2(72, 72)
const _GRID_COLUMNS := 6
const _COLOR_MAXED_BG := Color(0.18, 0.32, 0.18, 0.9)
const _COLOR_MAXED_BORDER := Color(0.45, 0.85, 0.4, 1.0)
const _COLOR_NORMAL_BG := Color(0.3, 0.22, 0.1, 0.9)
const _COLOR_NORMAL_BORDER := Color(0.78, 0.64, 0.32, 0.9)

var _panel: PanelContainer
var _loot_label: Label
var _desc_title_label: Label
var _desc_body_label: Label
var _desc_status_label: Label
var _tracks_grid: GridContainer
var _close_btn: Button
var _nav_hint_label: Label

# Controller / keyboard navigation — düz liste, GridContainer'ın sütun sayısına göre
# satır/sütun hesabı yapılır (bkz. _move_focus).
var _track_ids: Array[String] = []
var _nav_buttons: Array[Button] = []
var _focused_index: int = 0
var _suppress_nav_until_msec: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
	var viewport := get_viewport()
	if viewport and not viewport.gui_focus_changed.is_connected(_on_gui_focus_changed):
		viewport.gui_focus_changed.connect(_on_gui_focus_changed)
	var mum := get_node_or_null("/root/MetaUpgradeManager")
	if mum and mum.has_signal("meta_data_changed") and not mum.meta_data_changed.is_connected(_refresh):
		mum.meta_data_changed.connect(_refresh)
	# <<< DÜZELTME: Parent bir Control değil CanvasLayer olduğu için anchor'lar _ready()
	# anında hesaplanınca (viewport boyutu henüz oturmadan) yanlış çıkabiliyor. >>>
	call_deferred("_reapply_full_rect")


func _reapply_full_rect() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_gui_input)
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(700, 560)
	_panel.offset_left = -350
	_panel.offset_top = -280
	_panel.offset_right = 350
	_panel.offset_bottom = 280
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(root_vbox)

	var title := Label.new()
	title.text = "Mucit Odası"
	title.add_theme_font_size_override("font_size", 24)
	root_vbox.add_child(title)

	_loot_label = Label.new()
	_loot_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_loot_label.add_theme_font_size_override("font_size", 12)
	_loot_label.modulate = Color(0.85, 0.78, 0.6, 0.9)
	root_vbox.add_child(_loot_label)

	root_vbox.add_child(_make_divider())

	# ── Üst bölüm: odaklanılan/üzerine gelinen karenin açıklaması ──────────
	var desc_panel := PanelContainer.new()
	var desc_sb := StyleBoxFlat.new()
	desc_sb.bg_color = Color(0.1, 0.08, 0.06, 0.6)
	desc_sb.border_color = Color(0.6, 0.47, 0.28, 0.6)
	desc_sb.border_width_left = 2; desc_sb.border_width_top = 2
	desc_sb.border_width_right = 2; desc_sb.border_width_bottom = 2
	desc_sb.corner_radius_top_left = 8; desc_sb.corner_radius_top_right = 8
	desc_sb.corner_radius_bottom_left = 8; desc_sb.corner_radius_bottom_right = 8
	desc_sb.set_content_margin_all(12)
	desc_panel.add_theme_stylebox_override("panel", desc_sb)
	desc_panel.custom_minimum_size = Vector2(0, 110)
	root_vbox.add_child(desc_panel)

	var desc_vbox := VBoxContainer.new()
	desc_vbox.add_theme_constant_override("separation", 4)
	desc_panel.add_child(desc_vbox)

	_desc_title_label = Label.new()
	_desc_title_label.add_theme_font_size_override("font_size", 16)
	desc_vbox.add_child(_desc_title_label)

	_desc_body_label = Label.new()
	_desc_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_body_label.add_theme_font_size_override("font_size", 12)
	_desc_body_label.modulate = Color(0.85, 0.78, 0.6, 0.9)
	desc_vbox.add_child(_desc_body_label)

	_desc_status_label = Label.new()
	_desc_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_status_label.add_theme_font_size_override("font_size", 13)
	desc_vbox.add_child(_desc_status_label)

	root_vbox.add_child(_make_divider())

	# ── Alt bölüm: her geliştirme TEK bir kare, yan yana / alt alta ────────
	var grid_scroll := ScrollContainer.new()
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_scroll.custom_minimum_size = Vector2(0, 220)
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	grid_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	root_vbox.add_child(grid_scroll)

	_tracks_grid = GridContainer.new()
	_tracks_grid.columns = _GRID_COLUMNS
	_tracks_grid.add_theme_constant_override("h_separation", 10)
	_tracks_grid.add_theme_constant_override("v_separation", 10)
	grid_scroll.add_child(_tracks_grid)

	var hint_lbl := Label.new()
	_nav_hint_label = hint_lbl
	_update_nav_hint()
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.add_theme_font_size_override("font_size", 10)
	hint_lbl.modulate = Color(1, 1, 1, 0.45)
	root_vbox.add_child(hint_lbl)

	_close_btn = Button.new()
	_close_btn.text = "Kapat (Esc)"
	_close_btn.custom_minimum_size = Vector2(0, 36)
	_close_btn.pressed.connect(hide_panel)
	_style_focus(_close_btn)
	root_vbox.add_child(_close_btn)


func _make_divider() -> Control:
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color(0.6, 0.47, 0.28, 0.6)
	return divider


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


func show_panel() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_focused_index = 0
	_suppress_nav_until_msec = Time.get_ticks_msec() + 250
	get_viewport().gui_release_focus()
	_refresh()
	call_deferred("_grab_initial_focus")


func hide_panel() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if get_tree().paused:
		get_tree().paused = false
	_nav_buttons.clear()
	queue_free()


func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		hide_panel()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	# ui_back = ESC'nin bağlı olduğu ayrı aksiyon (ui_cancel sadece META/gamepad B içeriyor).
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_back"):
		get_viewport().set_input_as_handled()
		hide_panel()
		return
	var nav_blocked := Time.get_ticks_msec() < _suppress_nav_until_msec
	if not nav_blocked:
		if event.is_action_pressed("ui_down"):
			get_viewport().set_input_as_handled()
			_move_focus(1, 0)
			return
		if event.is_action_pressed("ui_up"):
			get_viewport().set_input_as_handled()
			_move_focus(-1, 0)
			return
		if event.is_action_pressed("ui_right"):
			get_viewport().set_input_as_handled()
			_move_focus(0, 1)
			return
		if event.is_action_pressed("ui_left"):
			get_viewport().set_input_as_handled()
			_move_focus(0, -1)
			return
		if event.is_action_pressed("ui_accept"):
			var owner := get_viewport().gui_get_focus_owner()
			if owner is Button and (owner == _close_btn or owner.has_meta("track_id")):
				get_viewport().set_input_as_handled()
				(owner as Button).pressed.emit()
				return
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") \
			or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	if not is_instance_valid(_loot_label) or not is_instance_valid(_tracks_grid):
		return
	var mum := get_node_or_null("/root/MetaUpgradeManager")
	if mum == null:
		_loot_label.text = "MetaUpgradeManager bulunamadı."
		return
	# Her zaman üçünü de göster (0 olsa bile) — oyuncu neyi toplaması gerektiğini görsün.
	var loot_parts: PackedStringArray = PackedStringArray()
	for lid in _ExpeditionLootType.all():
		var n := int(mum.get_village_loot(lid))
		loot_parts.append("%s: %d" % [_ExpeditionLootType.display_name(lid), n])
	_loot_label.text = "Köy stoku: " + ", ".join(loot_parts)

	_nav_buttons.clear()
	_track_ids.clear()
	for child in _tracks_grid.get_children():
		child.queue_free()

	for track_id in _MetaUpgradeConfig.get_track_ids():
		var tid := String(track_id)
		_track_ids.append(tid)
		var square := _make_track_square(tid, mum)
		_tracks_grid.add_child(square)
		_nav_buttons.append(square)

	_show_description(_focused_index, mum)


## Her geliştirme yolu için TEK kare — seviyesi ne olursa olsun aynı kare, sadece
## rengi/metni günceleniyor (maks. seviyeye ulaşınca yeşil, aksi halde altın).
func _make_track_square(track_id: String, mum: Node) -> Button:
	var track: Dictionary = _MetaUpgradeConfig.TRACKS.get(track_id, {})
	var max_lvl := int(track.get("max_level", 0))
	var cur_lvl := int(mum.get_track_level(track_id))
	var maxed := cur_lvl >= max_lvl

	var btn := Button.new()
	btn.custom_minimum_size = _SQUARE_SIZE
	btn.text = "MAKS" if maxed else "%d/%d" % [cur_lvl, max_lvl]
	btn.add_theme_font_size_override("font_size", 13)
	btn.focus_mode = Control.FOCUS_ALL
	btn.set_meta("track_id", track_id)
	btn.tooltip_text = String(track.get("title", track_id))

	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 8; sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8; sb.corner_radius_bottom_right = 8
	sb.border_width_left = 3; sb.border_width_top = 3
	sb.border_width_right = 3; sb.border_width_bottom = 3
	if maxed:
		sb.bg_color = _COLOR_MAXED_BG
		sb.border_color = _COLOR_MAXED_BORDER
	else:
		sb.bg_color = _COLOR_NORMAL_BG
		sb.border_color = _COLOR_NORMAL_BORDER
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	_style_focus(btn)

	btn.pressed.connect(_on_square_pressed.bind(track_id))
	btn.mouse_entered.connect(_on_square_hovered.bind(track_id))
	btn.focus_entered.connect(_on_square_hovered.bind(track_id))

	return btn


func _on_square_hovered(track_id: String) -> void:
	var idx := _track_ids.find(track_id)
	if idx < 0:
		return
	_focused_index = idx
	var mum := get_node_or_null("/root/MetaUpgradeManager")
	_show_description(idx, mum)


func _show_description(track_idx: int, mum: Node) -> void:
	if track_idx < 0 or track_idx >= _track_ids.size() or mum == null:
		return
	var track_id: String = _track_ids[track_idx]
	var track: Dictionary = _MetaUpgradeConfig.TRACKS.get(track_id, {})
	var max_lvl := int(track.get("max_level", 0))
	var cur_lvl := int(mum.get_track_level(track_id))

	_desc_title_label.text = "%s — Seviye %d / %d" % [String(track.get("title", track_id)), cur_lvl, max_lvl]
	_desc_body_label.text = String(track.get("description", ""))

	if cur_lvl >= max_lvl:
		_desc_status_label.text = "✓ Maksimum seviyeye ulaştın."
		_desc_status_label.modulate = Color(0.6, 1.0, 0.55)
	else:
		var cost: Dictionary = _MetaUpgradeConfig.get_level_cost(track_id, cur_lvl + 1)
		_desc_status_label.text = "Sıradaki seviye maliyeti: %s   [Satın almak için seç]" % _MetaUpgradeConfig.format_cost(cost)
		_desc_status_label.modulate = Color(1.0, 0.9, 0.5)


func _on_square_pressed(track_id: String) -> void:
	var mum := get_node_or_null("/root/MetaUpgradeManager")
	if mum == null:
		return
	if mum.try_purchase_upgrade(track_id):
		_refresh()
		_focus_index(_focused_index)
	else:
		_show_description(_track_ids.find(track_id), mum)


# ─── Controller / keyboard navigation (GridContainer'a göre satır/sütun) ──────

func _grab_initial_focus() -> void:
	if not _focus_index(0) and is_instance_valid(_close_btn):
		_close_btn.grab_focus()


func _focus_index(index: int) -> bool:
	if _nav_buttons.is_empty():
		return false
	index = clampi(index, 0, _nav_buttons.size() - 1)
	var btn: Button = _nav_buttons[index]
	if not is_instance_valid(btn):
		return false
	_focused_index = index
	get_viewport().gui_release_focus()
	btn.grab_focus()
	return true


func _move_focus(d_row: int, d_col: int) -> void:
	if _nav_buttons.is_empty():
		return
	var count := _nav_buttons.size()
	var columns := maxi(1, _tracks_grid.columns)
	if d_col != 0:
		var idx := wrapi(_focused_index + d_col, 0, count)
		_focus_index(idx)
		return
	if d_row != 0:
		var col := _focused_index % columns
		var row := _focused_index / columns
		var total_rows := (count + columns - 1) / columns
		var new_row := wrapi(row + d_row, 0, total_rows)
		var candidate := new_row * columns + col
		if candidate >= count:
			candidate = count - 1
		_focus_index(candidate)


func _on_gui_focus_changed(control: Control) -> void:
	if not visible:
		return
	if control != null and control is Button and (control as Button).has_meta("track_id"):
		return
	if control == _close_btn:
		return
	call_deferred("_reclaim_focus")


func _reclaim_focus() -> void:
	if not visible:
		return
	var owner := get_viewport().gui_get_focus_owner()
	if owner is Button and (owner == _close_btn or (owner as Button).has_meta("track_id")):
		return
	_focus_index(_focused_index)


func _update_nav_hint() -> void:
	if _nav_hint_label == null:
		return
	var im := get_node_or_null("/root/InputManager")
	var is_pad := im != null and bool(im.get("last_input_from_joypad"))
	if is_pad:
		_nav_hint_label.text = "[↑↓◄►] Geliştirme seç   [A] Satın al   [B] Kapat"
	else:
		_nav_hint_label.text = "[↑↓◄►] Geliştirme seç   [Enter] Satın al   [Esc] Kapat"
