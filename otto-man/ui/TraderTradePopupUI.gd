extends Control
class_name TraderTradePopupUI
## Tüccar NPC üzerinden alışveriş — parşömen temalı, oyunu durdurmaz.

signal closed

const _MEDIEVAL_THEME := preload("res://resources/medieval_theme.tres")

var _panel: PanelContainer
var _title_label: Label
var _gold_label: Label
var _product_list: VBoxContainer
var _info_label: Label
var _trader: Dictionary = {}
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
	_panel.offset_left = -260
	_panel.offset_top = -220
	_panel.offset_right = 260
	_panel.offset_bottom = 220
	ParchmentTextures.apply_large_panel_style(_panel, 20)
	add_child(_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	_panel.add_child(root)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 22)
	root.add_child(_title_label)

	_gold_label = Label.new()
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label.add_theme_font_size_override("font_size", 13)
	_gold_label.modulate = Color(1, 0.9, 0.45)
	root.add_child(_gold_label)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color(0.6, 0.47, 0.28, 0.85)
	root.add_child(divider)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 280)
	scroll.follow_focus = true
	root.add_child(scroll)

	_product_list = VBoxContainer.new()
	_product_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_product_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_product_list)

	_info_label = Label.new()
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.add_theme_font_size_override("font_size", 11)
	_info_label.modulate = Color(1, 0.55, 0.5, 1)
	root.add_child(_info_label)

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


func show_for_trader(trader: Dictionary) -> void:
	_trader = trader.duplicate(true)
	_reapply_full_rect()
	_is_open = true
	_info_label.text = ""
	_refresh()
	visible = true
	call_deferred("_grab_initial_focus")


func hide_popup() -> void:
	_is_open = false
	visible = false
	_trader = {}
	closed.emit()


func _refresh() -> void:
	_title_label.text = String(_trader.get("name", "Tüccar"))
	var gpd := get_node_or_null("/root/GlobalPlayerData")
	var gold := int(gpd.gold) if gpd else 0
	_gold_label.text = "Altın: %d" % gold

	for child in _product_list.get_children():
		child.queue_free()

	var products: Array = _trader.get("products", [])
	if products.is_empty():
		var empty := Label.new()
		empty.text = "Satılık ürün yok."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.modulate = Color(1, 1, 1, 0.55)
		_product_list.add_child(empty)
		return

	for product in products:
		_product_list.add_child(_make_product_row(product))


func _make_product_row(product: Dictionary) -> Control:
	var resource_key := String(product.get("resource", ""))
	var price := int(product.get("price_per_unit", 0))
	var res_name := LocaleManager.get_resource_name(resource_key) if resource_key != "" else "?"

	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.12, 0.08, 0.55)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.set_content_margin_all(8)
	sb.border_width_left = 3
	sb.border_color = Color(0.55, 0.65, 0.85)
	card.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)

	var icon_path := _resource_icon_path(resource_key)
	if not icon_path.is_empty():
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(20, 20)
		icon.texture = load(icon_path)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = res_name
	name_lbl.add_theme_font_size_override("font_size", 15)
	info.add_child(name_lbl)

	var price_lbl := Label.new()
	price_lbl.text = "%d altın / birim" % price
	price_lbl.add_theme_font_size_override("font_size", 11)
	price_lbl.modulate = Color(1, 1, 1, 0.7)
	info.add_child(price_lbl)

	for qty in [1, 5, 10]:
		var btn := Button.new()
		btn.text = "+%d" % qty
		btn.custom_minimum_size = Vector2(48, 34)
		btn.pressed.connect(_on_buy_pressed.bind(resource_key, qty))
		_style_focus(btn)
		row.add_child(btn)

	return card


func _resource_icon_path(resource_key: String) -> String:
	if resource_key.is_empty():
		return ""
	var path := "res://assets/Icons/%s_icon.png" % resource_key
	return path if ResourceLoader.exists(path) else ""


func _on_buy_pressed(resource: String, quantity: int) -> void:
	var tid := String(_trader.get("id", ""))
	if tid.is_empty():
		return
	var mm := get_node_or_null("/root/MissionManager")
	if mm == null or not mm.has_method("buy_from_trader"):
		_info_label.text = "Satın alma başarısız."
		return
	if mm.buy_from_trader(tid, resource, quantity):
		_info_label.text = ""
		_refresh()
	else:
		_info_label.text = "Yetersiz altın veya stok yok."


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
	for child in _product_list.get_children():
		var btn := _find_first_button(child)
		if btn:
			btn.grab_focus()
			return


func _find_first_button(node: Node) -> Button:
	if node is Button:
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
	# ui_back = ESC'nin bağlı olduğu ayrı aksiyon (ui_cancel sadece META/gamepad B içeriyor).
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_back"):
		get_viewport().set_input_as_handled()
		hide_popup()
