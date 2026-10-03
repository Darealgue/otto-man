# item_button.gd
# Button for displaying item info in selection UI

extends Button

var item_scene: PackedScene
var progress: float = 0.0

## Açıklama puntosu karta göre otomatik seçilir: sığan en büyük punto kullanılır.
## Sabit 14 punto hem okunmuyordu hem de uzun açıklamaların bir kısmı kutuya sığmıyordu.
const DESC_FONT_MAX := 22
const DESC_FONT_MIN := 13


func _ready() -> void:
	# setup() buton ağaca eklenmeden çalışıyor; tema fontu ancak ağaçtayken çözülüyor.
	_fit_desc_font()


## Ağaca eklenmemiş buton için autoload erişimi (bkz. setup içindeki not).
func _item_manager() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("ItemManager")
	return null

func setup(scene: PackedScene) -> void:
	item_scene = scene

	# Instance the item to get its info
	var item = scene.instantiate()

	if item is ItemEffect:
		var item_name = item.item_name
		var description = item.description
		var rarity = item.rarity

		# Get rarity color
		var rarity_color = Color.WHITE
		match rarity:
			ItemEffect.ItemRarity.COMMON:
				rarity_color = Color(0.7, 0.7, 0.7)  # Gray
			ItemEffect.ItemRarity.UNCOMMON:
				rarity_color = Color(0.0, 0.5, 1.0)  # Blue
			ItemEffect.ItemRarity.RARE:
				rarity_color = Color(0.6, 0.0, 1.0)  # Purple
			ItemEffect.ItemRarity.LEGENDARY:
				rarity_color = Color(1.0, 0.5, 0.0)  # Orange

		# Rarity artık isme karışmıyor, ayrı küçük bir rozet olarak gösteriliyor
		var rarity_text = ""
		match rarity:
			ItemEffect.ItemRarity.COMMON:
				rarity_text = "Common"
			ItemEffect.ItemRarity.UNCOMMON:
				rarity_text = "Uncommon"
			ItemEffect.ItemRarity.RARE:
				rarity_text = "Rare"
			ItemEffect.ItemRarity.LEGENDARY:
				rarity_text = "Legendary"
		_apply_card_tint(rarity_color)

		var desc_full: String = description
		# setup() buton daha ağaca EKLENMEDEN çağrılıyor; has_node("/root/...") burada
		# "Can't use get_node() with absolute paths from outside the active scene tree"
		# hatası veriyor ve set ipucu hiç görünmüyordu. Autoload'a ana döngü üzerinden eriş.
		var im: Node = _item_manager()
		if im and im.has_method("get_set_hint_if_selected"):
			var hint: String = im.call("get_set_hint_if_selected", item.item_id)
			if not hint.is_empty():
				desc_full += "\n" + hint
		if im and im.has_method("get_synergy_hint"):
			var synergy: String = im.call("get_synergy_hint", item.item_id)
			if not synergy.is_empty():
				desc_full += "\n" + synergy
		_set_card_text(item_name, desc_full, rarity_text, rarity_color)
	else:
		_set_card_text("Unknown Item", "", "", Color.WHITE)

	item.queue_free()

## İsim büyük punto bölgesine, açıklama altına, rarity ise küçük bir rozet olarak sol üst köşeye
## yazılır. get_node ile doğrudan çekiyoruz — @onready, setup() çağrıldığı anda (buton henüz
## ağaca eklenmeden) çalıştığı için henüz doldurulmamış oluyordu (yazılar sessizce kayboluyordu).
func _set_card_text(card_name: String, description: String, tag_text: String = "", tag_color: Color = Color.WHITE) -> void:
	var name_label := get_node_or_null("NameLabel") as Label
	var desc_label := get_node_or_null("DescLabel") as Label
	var tag_label := get_node_or_null("RarityLabel") as Label
	if name_label:
		name_label.text = card_name
	if desc_label:
		desc_label.text = description
	if tag_label:
		tag_label.text = tag_text
		tag_label.add_theme_color_override("font_color", tag_color)

## Açıklama kutusuna sığan en büyük puntoyu bulup uygular. Kutu ölçüleri kartın
## arka plan şablonundaki (card_template.png) açıklama paneline göre ayarlı.
func _fit_desc_font() -> void:
	var label := get_node_or_null("DescLabel") as Label
	if label == null or label.text.is_empty():
		return
	var font: Font = label.get_theme_font("font")
	if font == null:
		return
	var box_w: float = label.offset_right - label.offset_left
	var box_h: float = label.offset_bottom - label.offset_top
	if box_w <= 0.0 or box_h <= 0.0:
		return
	var spacing: int = label.get_theme_constant("line_spacing")
	for fs in range(DESC_FONT_MAX, DESC_FONT_MIN - 1, -1):
		var sz: Vector2 = font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, box_w, fs)
		var line_h: float = maxf(1.0, font.get_height(fs))
		var lines: int = maxi(1, int(round(sz.y / line_h)))
		if sz.y + float(spacing * (lines - 1)) <= box_h:
			label.add_theme_font_size_override("font_size", fs)
			return
	label.add_theme_font_size_override("font_size", DESC_FONT_MIN)


## Şablon kart çizimini (card_template.png) rarity rengine göre boyayıp buton arka planına basar.
func _apply_card_tint(tint: Color) -> void:
	var sb := CardVisualUtil.build_tinted_card_stylebox(tint)
	if sb == null:
		return
	add_theme_stylebox_override("normal", sb)
	add_theme_stylebox_override("hover", sb)
	add_theme_stylebox_override("pressed", sb)
	add_theme_stylebox_override("focus", sb)

const GOLD_ICON := preload("res://assets/Icons/gold_icon.png")

## Dükkân modu: kartın ALTINA büyük bir fiyat şeridi koyar (altın ikonu + sayı).
## Köşede küçük punto denendi, okunmuyordu (playtest geri bildirimi).
func set_price_tag(price: int, affordable: bool) -> void:
	var row := get_node_or_null("PriceRow") as HBoxContainer
	if row == null:
		row = HBoxContainer.new()
		row.name = "PriceRow"
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		# Kartın üst görsel alanında, ortalanmış. Alt bölge açıklama panelinin kutusu,
		# oraya konursa metnin üstüne biner.
		row.offset_left = 0.0
		row.offset_right = 320.0
		row.offset_top = 60.0
		row.offset_bottom = 112.0
		add_child(row)

		var icon := TextureRect.new()
		icon.name = "GoldIcon"
		icon.texture = GOLD_ICON
		icon.custom_minimum_size = Vector2(40, 40)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)

		var label := Label.new()
		label.name = "PriceLabel"
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 34)
		label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.02))
		label.add_theme_constant_override("outline_size", 5)
		row.add_child(label)

	var price_label := row.get_node_or_null("PriceLabel") as Label
	if price_label:
		price_label.text = str(price)
		price_label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.86, 0.35) if affordable else Color(0.92, 0.34, 0.30)
		)


func set_progress(value: float) -> void:
	progress = value
	queue_redraw()

func _draw() -> void:
	if progress > 0:
		var size = get_size()
		# Kartın altında, küçük ve kalın bir dolum halkası (eskisi kart ortasında dev ve incecikti)
		var radius = (min(size.x, size.y) * 0.4) / 5.0
		var center = Vector2(size.x * 0.5, size.y + radius + 20.0)
		var angle_from = -PI/2
		var angle_to = angle_from + (PI * 2 * progress)

		draw_arc(center, radius, angle_from, angle_to, 32, Color(1, 1, 1, 0.9), 6.0)
