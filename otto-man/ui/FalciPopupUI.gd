extends Control
class_name FalciPopupUI
## Gezgin falcı — kalıcı item koleksiyonu üzerinde işlem yapar.
## Üç hizmet (bkz. docs/ITEM_UNLOCK_SISTEMI.md bölüm 9):
##   Sil     — item bir daha kart olarak teklif edilmez (en güçlü kaldıraç, en pahalı)
##   Takas   — item aynı rarity'den rastgele başkasıyla değişir
##   Kehanet — sonraki unlock teklifinde bir slot seçtiğin kategoriye yönlendirilir
## Tüccar penceresiyle aynı parşömen iskeleti; oyunu durdurmaz.

signal closed

const _MEDIEVAL_THEME := preload("res://resources/medieval_theme.tres")
const GOLD_ICON := preload("res://assets/Icons/gold_icon.png")

## Fiyatlar: silme en pahalı çünkü gelecekteki BÜTÜN run'ların kart kalitesini yükseltiyor.
const COST_BANISH: int = 120
const COST_SWAP: int = 80
const COST_ORACLE: int = 60

## Kehanette sunulan kategoriler (ItemEffect.ItemCategory değerleri).
const ORACLE_CATEGORIES: Array = [
	{"category": 3, "key": "falci.cat.light_attack"},
	{"category": 4, "key": "falci.cat.heavy_attack"},
	{"category": 1, "key": "falci.cat.block"},
	{"category": 2, "key": "falci.cat.parry"},
	{"category": 10, "key": "falci.cat.dodge"},
	{"category": 11, "key": "falci.cat.special"},
]

var _panel: PanelContainer
var _title_label: Label
var _gold_label: Label
var _oracle_row: HBoxContainer
var _oracle_state_label: Label
var _item_list: VBoxContainer
var _info_label: Label
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
	_panel.offset_left = -330
	_panel.offset_top = -280
	_panel.offset_right = 330
	_panel.offset_bottom = 280
	ParchmentTextures.apply_large_panel_style(_panel, 20)
	add_child(_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	_panel.add_child(root)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 26)
	_title_label.text = tr("falci.title")
	root.add_child(_title_label)

	var gold_row := HBoxContainer.new()
	gold_row.alignment = BoxContainer.ALIGNMENT_CENTER
	gold_row.add_theme_constant_override("separation", 8)
	root.add_child(gold_row)
	var gold_icon := TextureRect.new()
	gold_icon.texture = GOLD_ICON
	gold_icon.custom_minimum_size = Vector2(28, 28)
	gold_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gold_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gold_row.add_child(gold_icon)
	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 24)
	_gold_label.modulate = Color(1, 0.9, 0.45)
	_gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gold_row.add_child(_gold_label)

	root.add_child(_make_divider())

	# --- Kehanet ---
	var oracle_title := Label.new()
	oracle_title.text = tr("falci.oracle.title") % COST_ORACLE
	oracle_title.add_theme_font_size_override("font_size", 17)
	root.add_child(oracle_title)

	var oracle_desc := Label.new()
	oracle_desc.text = tr("falci.oracle.desc")
	oracle_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	oracle_desc.add_theme_font_size_override("font_size", 14)
	oracle_desc.modulate = Color(1, 1, 1, 0.7)
	root.add_child(oracle_desc)

	_oracle_row = HBoxContainer.new()
	_oracle_row.add_theme_constant_override("separation", 6)
	root.add_child(_oracle_row)

	_oracle_state_label = Label.new()
	_oracle_state_label.add_theme_font_size_override("font_size", 14)
	_oracle_state_label.modulate = Color(0.75, 0.65, 1.0)
	root.add_child(_oracle_state_label)

	root.add_child(_make_divider())

	# --- Koleksiyon (sil / takas) ---
	var coll_title := Label.new()
	coll_title.text = tr("falci.collection.title") % [COST_BANISH, COST_SWAP]
	coll_title.add_theme_font_size_override("font_size", 17)
	root.add_child(coll_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 240)
	scroll.follow_focus = true
	root.add_child(scroll)

	_item_list = VBoxContainer.new()
	_item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_list.add_theme_constant_override("separation", 5)
	scroll.add_child(_item_list)

	_info_label = Label.new()
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.add_theme_font_size_override("font_size", 14)
	root.add_child(_info_label)

	root.add_child(_make_close_hint_bar())
	TextOutline.apply_to_tree(self)


func _make_divider() -> Control:
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color(0.6, 0.47, 0.28, 0.85)
	return divider


func _make_close_hint_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.add_theme_constant_override("separation", 4)
	var lbl := Label.new()
	lbl.text = tr("falci.close")
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.modulate = Color(1, 1, 1, 0.5)
	bar.add_child(lbl)
	return bar


func show_popup() -> void:
	_reapply_full_rect()
	_is_open = true
	_info_label.text = ""
	_refresh()
	visible = true
	call_deferred("_grab_initial_focus")


func hide_popup() -> void:
	_is_open = false
	visible = false
	closed.emit()


func _current_gold() -> int:
	var gpd := get_node_or_null("/root/GlobalPlayerData")
	return int(gpd.gold) if gpd else 0


func _spend_gold(amount: int) -> bool:
	var gpd := get_node_or_null("/root/GlobalPlayerData")
	if gpd == null or int(gpd.gold) < amount:
		return false
	gpd.gold = int(gpd.gold) - amount
	return true


func _refresh() -> void:
	_gold_label.text = str(_current_gold())
	_refresh_oracle()
	_refresh_collection()


func _refresh_oracle() -> void:
	for child in _oracle_row.get_children():
		child.queue_free()
	var im := get_node_or_null("/root/ItemManager")
	if im == null:
		return
	var pending: int = int(im.get("oracle_category"))
	if pending != -1:
		_oracle_state_label.text = tr("falci.oracle.active") % _category_name(pending)
		return
	_oracle_state_label.text = ""
	for entry in ORACLE_CATEGORIES:
		var btn := Button.new()
		btn.text = tr(String(entry["key"]))
		btn.add_theme_font_size_override("font_size", 14)
		btn.custom_minimum_size = Vector2(0, 34)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.disabled = _current_gold() < COST_ORACLE
		btn.pressed.connect(_on_oracle_pressed.bind(int(entry["category"])))
		_style_focus(btn)
		_oracle_row.add_child(btn)


func _category_name(category: int) -> String:
	for entry in ORACLE_CATEGORIES:
		if int(entry["category"]) == category:
			return tr(String(entry["key"]))
	return "?"


func _refresh_collection() -> void:
	for child in _item_list.get_children():
		child.queue_free()
	var im := get_node_or_null("/root/ItemManager")
	if im == null:
		return
	var ids: Array = im.call("get_unlocked_item_ids")
	var shown := 0
	for raw_id in ids:
		var id: String = String(raw_id)
		# Başlangıç loadout'u temel araç; falcı ona dokunmaz
		if id in im.STARTER_ITEM_IDS:
			continue
		if bool(im.call("is_permanently_banished", id)):
			continue
		_item_list.add_child(_make_item_row(im, id))
		shown += 1
	if shown == 0:
		var empty := Label.new()
		empty.text = tr("falci.collection.empty")
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.modulate = Color(1, 1, 1, 0.55)
		_item_list.add_child(empty)


func _make_item_row(im: Node, item_id: String) -> Control:
	var meta: Dictionary = im.call("get_item_meta", item_id)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.12, 0.08, 0.55)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.set_content_margin_all(8)
	sb.border_width_left = 3
	sb.border_color = _rarity_color(int(meta.get("rarity", 0)))
	card.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)

	var name_lbl := Label.new()
	name_lbl.text = String(meta.get("name", item_id))
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_lbl)

	var gold: int = _current_gold()

	var banish_btn := Button.new()
	banish_btn.text = tr("falci.action.banish") % COST_BANISH
	banish_btn.add_theme_font_size_override("font_size", 14)
	banish_btn.custom_minimum_size = Vector2(0, 34)
	banish_btn.disabled = gold < COST_BANISH
	banish_btn.pressed.connect(_on_banish_pressed.bind(item_id))
	_style_focus(banish_btn)
	row.add_child(banish_btn)

	var swap_btn := Button.new()
	swap_btn.text = tr("falci.action.swap") % COST_SWAP
	swap_btn.add_theme_font_size_override("font_size", 14)
	swap_btn.custom_minimum_size = Vector2(0, 34)
	# Ön koşul ebeveyni takas edilemez: çıkarılırsa çocukları ölü ağırlık kalır
	swap_btn.disabled = gold < COST_SWAP or not bool(im.call("can_swap_unlocked_item", item_id))
	swap_btn.pressed.connect(_on_swap_pressed.bind(item_id))
	_style_focus(swap_btn)
	row.add_child(swap_btn)

	return card


func _rarity_color(rarity: int) -> Color:
	match rarity:
		0: return Color(0.7, 0.7, 0.7)
		1: return Color(0.0, 0.5, 1.0)
		2: return Color(0.6, 0.0, 1.0)
		_: return Color(1.0, 0.5, 0.0)


func _on_oracle_pressed(category: int) -> void:
	var im := get_node_or_null("/root/ItemManager")
	if im == null:
		return
	if not _spend_gold(COST_ORACLE):
		_show_info(tr("falci.info.no_gold"), false)
		return
	im.call("set_oracle_category", category)
	_show_info(tr("falci.info.oracle_set") % _category_name(category), true)
	_refresh()


func _on_banish_pressed(item_id: String) -> void:
	var im := get_node_or_null("/root/ItemManager")
	if im == null:
		return
	var meta: Dictionary = im.call("get_item_meta", item_id)
	if not _spend_gold(COST_BANISH):
		_show_info(tr("falci.info.no_gold"), false)
		return
	im.call("banish_item_permanently", item_id)
	_show_info(tr("falci.info.banished") % String(meta.get("name", item_id)), true)
	_refresh()


func _on_swap_pressed(item_id: String) -> void:
	var im := get_node_or_null("/root/ItemManager")
	if im == null:
		return
	var old_meta: Dictionary = im.call("get_item_meta", item_id)
	if not _spend_gold(COST_SWAP):
		_show_info(tr("falci.info.no_gold"), false)
		return
	var replacement: String = String(im.call("swap_unlocked_item", item_id))
	if replacement.is_empty():
		# Takas başarısız: parayı geri ver
		var gpd := get_node_or_null("/root/GlobalPlayerData")
		if gpd:
			gpd.gold = int(gpd.gold) + COST_SWAP
		_show_info(tr("falci.info.swap_failed"), false)
		return
	var new_meta: Dictionary = im.call("get_item_meta", replacement)
	_show_info(tr("falci.info.swapped") % [
		String(old_meta.get("name", item_id)), String(new_meta.get("name", replacement))
	], true)
	_refresh()


func _show_info(text: String, good: bool) -> void:
	_info_label.text = text
	_info_label.modulate = Color(0.6, 1.0, 0.6) if good else Color(1, 0.55, 0.5)


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


func _grab_initial_focus() -> void:
	for child in _oracle_row.get_children():
		if child is Button and not (child as Button).disabled:
			(child as Button).grab_focus()
			return
	for child in _item_list.get_children():
		var btn := _find_first_button(child)
		if btn:
			btn.grab_focus()
			return


func _find_first_button(node: Node) -> Button:
	if node is Button and not (node as Button).disabled:
		return node as Button
	for child in node.get_children():
		var found := _find_first_button(child)
		if found:
			return found
	return null


func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		hide_popup()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_back"):
		get_viewport().set_input_as_handled()
		hide_popup()
