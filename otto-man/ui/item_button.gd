# item_button.gd
# Button for displaying item info in selection UI

extends Button

var item_scene: PackedScene
var progress: float = 0.0

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
		if has_node("/root/ItemManager") and ItemManager.has_method("get_set_hint_if_selected"):
			var hint := ItemManager.get_set_hint_if_selected(item.item_id)
			if not hint.is_empty():
				desc_full += "\n" + hint
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

## Şablon kart çizimini (card_template.png) rarity rengine göre boyayıp buton arka planına basar.
func _apply_card_tint(tint: Color) -> void:
	var sb := CardVisualUtil.build_tinted_card_stylebox(tint)
	if sb == null:
		return
	add_theme_stylebox_override("normal", sb)
	add_theme_stylebox_override("hover", sb)
	add_theme_stylebox_override("pressed", sb)
	add_theme_stylebox_override("focus", sb)

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
