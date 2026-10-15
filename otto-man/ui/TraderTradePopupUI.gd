extends Control
class_name TraderTradePopupUI
## Tüccar NPC üzerinden alışveriş — tam ekran, falcıyla aynı örtü animasyonu (bkz. ui/ClothCurtain.gd).
## Ürünler kademe renkli büyük kartlar olarak iki sütunda listelenir (temel / işlenmiş / el işi / silah);
## her kartta ikon, ad, kademe, köydeki mevcut stok, birim fiyatı ve +1 / +5 / +10 düğmeleri (toplam bedelle).
## Oyunu durdurmaz (process_mode ALWAYS).

signal closed

const _MEDIEVAL_THEME := preload("res://resources/medieval_theme.tres")
const _KeyChip := preload("res://ui/KeyChip.gd")
const _CurtainScript := preload("res://ui/ClothCurtain.gd")
const GOLD_ICON := preload("res://assets/Icons/gold_icon.png")

## Tüccarın örtüyü seren el çizimi (3128x1080, kırmızı örtü; 16:9'da son karede el ekranın solundan çıkar).
## Dosya yoksa animasyonsuz açılır.
const CLOTH_TEXTURE_PATH := "res://assets/NPC/trader/Tuccar_arayuz_el.png"

const BUY_AMOUNTS: Array[int] = [1, 5, 10]
const TIER_COLORS: Dictionary = {
	"basic": Color(0.60, 0.72, 0.45),
	"processed": Color(0.45, 0.68, 0.92),
	"crafted": Color(0.78, 0.55, 0.92),
	"arms": Color(0.95, 0.55, 0.35),
}
const TIER_ORDER: Array[String] = ["basic", "processed", "crafted", "arms"]
const MARGIN := 48

var _bg: ColorRect
var _curtain: Control
var _content: Control
var _title_label: Label
var _sub_label: Label
var _gold_label: Label
var _product_grid: GridContainer
var _info_label: Label
var _trader: Dictionary = {}
var _is_open := false
var _intro_active := false
var _closing := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = _MEDIEVAL_THEME
	UiFontFloor.attach(self)
	_build_ui()
	visible = false
	call_deferred("_reapply_full_rect")


func _reapply_full_rect() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_ui() -> void:
	# Zemin: örtü bitince tam siyah zemin devreye girer (animasyon sırasında köy görünür kalır)
	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0.0, 0.0, 0.0, 1.0)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	_curtain = _CurtainScript.new()
	_curtain.setup(CLOTH_TEXTURE_PATH)
	_curtain.covered.connect(_finish_intro)
	_curtain.uncovered.connect(_finish_close)
	add_child(_curtain)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, MARGIN)
	add_child(margin)
	_content = margin

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	# Üst şerit: ad + köken solda, altın sağda
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	root.add_child(head)

	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 38)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
	names.add_child(_title_label)
	_sub_label = Label.new()
	_sub_label.add_theme_font_size_override("font_size", 19)
	_sub_label.modulate = Color(1, 1, 1, 0.65)
	names.add_child(_sub_label)

	var gold_icon := TextureRect.new()
	gold_icon.texture = GOLD_ICON
	gold_icon.custom_minimum_size = Vector2(36, 36)
	gold_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gold_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(gold_icon)
	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 30)
	_gold_label.modulate = Color(1, 0.9, 0.45)
	_gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_gold_label)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color(0.6, 0.47, 0.28, 0.85)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(divider)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_product_grid = GridContainer.new()
	_product_grid.columns = 2
	_product_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_product_grid.add_theme_constant_override("h_separation", 16)
	_product_grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(_product_grid)

	_info_label = Label.new()
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.add_theme_font_size_override("font_size", 19)
	_info_label.modulate = Color(1, 0.55, 0.5, 1)
	root.add_child(_info_label)

	root.add_child(_make_close_hint_bar())
	TextOutline.apply_to_tree(self)


func _make_close_hint_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = tr("trader.close")
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.modulate = Color(1, 1, 1, 0.6)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(lbl)
	# Tuş rozeti oyuncunun kullandığı cihaza göre değişir (klavye Esc, gamepad B)
	var chip: PanelContainer = _KeyChip.new()
	chip.setup("Esc", "B", 16)
	bar.add_child(chip)
	return bar


# ----------------------------------------------------------------------------- aç / kapat

func show_for_trader(trader: Dictionary) -> void:
	_trader = trader.duplicate(true)
	_reapply_full_rect()
	_curtain.reset()
	_closing = false
	_is_open = true
	_info_label.text = ""
	_refresh()
	visible = true
	_play_intro()


## Açılış: örtüyü seren el sağdan girip sola kadar gider; kalan siyah örtü arayüzün zemini olur.
func _play_intro() -> void:
	_bg.visible = false
	_content.visible = false
	if not _curtain.has_cloth():
		_finish_intro()
		return
	_intro_active = true
	_curtain.play_in()


func _finish_intro() -> void:
	_intro_active = false
	_bg.visible = true
	_content.visible = true
	_content.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_content, "modulate:a", 1.0, 0.25)
	call_deferred("_grab_initial_focus")


## Kapanış: açılışın tersi, hızlı.
func hide_popup() -> void:
	if _closing:
		return
	_intro_active = false
	if not _curtain.has_cloth():
		_finish_close()
		return
	_closing = true
	_content.visible = false
	_bg.visible = false
	_curtain.play_out()


func _finish_close() -> void:
	_closing = false
	_is_open = false
	visible = false
	_trader = {}
	closed.emit()


# ----------------------------------------------------------------------------- liste

func _current_gold() -> int:
	var gpd := get_node_or_null("/root/GlobalPlayerData")
	return int(gpd.gold) if gpd else 0


func _village_stock(resource_key: String) -> int:
	var vm := get_node_or_null("/root/VillageManager")
	if vm == null:
		return 0
	return int((vm.get("resource_levels") as Dictionary).get(resource_key, 0))


func _refresh() -> void:
	_title_label.text = String(_trader.get("name", tr("trader.default_name")))
	var origin: String = String(_trader.get("origin_settlement", ""))
	_sub_label.text = (tr("trader.origin") % origin) if not origin.is_empty() else ""
	_gold_label.text = str(_current_gold())

	for child in _product_grid.get_children():
		_product_grid.remove_child(child)
		child.queue_free()

	var products: Array = _trader.get("products", [])
	if products.is_empty():
		var empty := Label.new()
		empty.text = tr("trader.no_products")
		empty.add_theme_font_size_override("font_size", 22)
		empty.modulate = Color(1, 1, 1, 0.55)
		_product_grid.add_child(empty)
		return

	# Temel kaynaklar önde, silah en sonda
	var sorted: Array = products.duplicate()
	sorted.sort_custom(func(a, b): return _tier_index(a) < _tier_index(b))
	for product in sorted:
		_product_grid.add_child(_make_product_row(product))


func _tier_index(product: Dictionary) -> int:
	return TIER_ORDER.find(String(product.get("tier", "basic")))


func _make_product_row(product: Dictionary) -> Control:
	var resource_key := String(product.get("resource", ""))
	var price := int(product.get("price_per_unit", 0))
	var tier := String(product.get("tier", "basic"))
	var res_name := LocaleManager.get_resource_name(resource_key) if resource_key != "" else "?"
	var tier_col: Color = TIER_COLORS.get(tier, TIER_COLORS["basic"])
	var gold := _current_gold()

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = tier_col.darkened(0.75)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(16)
	sb.border_width_left = 8
	sb.border_color = tier_col
	card.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)

	var icon_path := _resource_icon_path(resource_key)
	var icon_holder := Control.new()
	icon_holder.custom_minimum_size = Vector2(72, 72)
	row.add_child(icon_holder)
	var icon := TextureRect.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not icon_path.is_empty():
		icon.texture = load(icon_path)
	icon_holder.add_child(icon)
	# Silah kademeleri ortak simgeyi paylaşır: kademe sağ alt köşede Roma rakamıyla yazılır
	var numeral: String = _weapon_numeral(resource_key)
	if not numeral.is_empty():
		var badge := Label.new()
		badge.text = numeral
		badge.add_theme_font_size_override("font_size", 24)
		badge.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
		badge.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		badge.add_theme_constant_override("outline_size", 6)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		badge.offset_right = 4
		badge.offset_bottom = 4
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_holder.add_child(badge)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	row.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = res_name
	name_lbl.add_theme_font_size_override("font_size", 28)
	info.add_child(name_lbl)

	var meta_lbl := Label.new()
	meta_lbl.text = "%s    %s" % [tr("trader.tier." + tier), tr("trader.in_village") % _village_stock(resource_key)]
	meta_lbl.add_theme_font_size_override("font_size", 18)
	meta_lbl.add_theme_color_override("font_color", tier_col.lightened(0.4))
	info.add_child(meta_lbl)

	var price_lbl := Label.new()
	price_lbl.text = tr("trader.price_per_unit") % price
	price_lbl.add_theme_font_size_override("font_size", 20)
	price_lbl.modulate = Color(1, 0.9, 0.55, 0.95)
	info.add_child(price_lbl)

	for qty in BUY_AMOUNTS:
		var total: int = price * qty
		var btn := Button.new()
		btn.text = "+%d\n%d" % [qty, total]
		btn.custom_minimum_size = Vector2(96, 72)
		btn.add_theme_font_size_override("font_size", 22)
		if gold < total:
			btn.modulate = Color(1, 0.7, 0.65, 0.85)
		btn.pressed.connect(_on_buy_pressed.bind(resource_key, qty))
		_style_focus(btn)
		row.add_child(btn)

	return card


func _weapon_numeral(resource_key: String) -> String:
	match resource_key:
		"weapon_t1":
			return "I"
		"weapon_t2":
			return "II"
		"weapon_t3":
			return "III"
	return ""


func _resource_icon_path(resource_key: String) -> String:
	if resource_key.is_empty():
		return ""
	var path := "res://assets/Icons/%s_icon.png" % resource_key
	if ResourceLoader.exists(path):
		return path
	# Silah kademelerinin ortak ikonu
	if resource_key.begins_with("weapon_"):
		var weapon_path := "res://assets/Icons/weapon_icon.png"
		if ResourceLoader.exists(weapon_path):
			return weapon_path
	return ""


func _on_buy_pressed(resource: String, quantity: int) -> void:
	var tid := String(_trader.get("id", ""))
	if tid.is_empty():
		return
	var mm := get_node_or_null("/root/MissionManager")
	if mm == null or not mm.has_method("buy_from_trader"):
		_info_label.text = tr("trader.purchase_failed")
		return
	if mm.buy_from_trader(tid, resource, quantity):
		_info_label.text = ""
		_refresh()
		call_deferred("_grab_initial_focus")
	else:
		_info_label.text = tr("trader.insufficient_gold_or_stock")


# ----------------------------------------------------------------------------- odak / girdi

func _style_focus(button: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.3, 0.22, 0.1, 0.9)
	sb.set_border_width_all(3)
	sb.border_color = Color(1.0, 0.85, 0.35, 1.0)
	sb.set_corner_radius_all(6)
	button.add_theme_stylebox_override("focus", sb)


func _grab_initial_focus() -> void:
	if not _is_open or _closing:
		return
	for child in _product_grid.get_children():
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


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _closing:
		get_viewport().set_input_as_handled()
		return
	# ui_back = ESC'nin bağlı olduğu ayrı aksiyon (ui_cancel sadece META/gamepad B içeriyor).
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_back"):
		get_viewport().set_input_as_handled()
		hide_popup()
		return
	if _intro_active:
		# Örtü serilirken Escape dışındaki girdiler yutulur
		get_viewport().set_input_as_handled()
