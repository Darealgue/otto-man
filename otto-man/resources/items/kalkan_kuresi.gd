# kalkan_kuresi.gd
# RARE - Hareket halinde savunma. Block tuşu, oyuncunun etrafında yarı saydam bir balon açar;
# koşarken, zıplarken, duvarda kayarken, ledge'de asılıyken bile bloklayabilirsin.
# Block state'i ve sprite'ı kullanılmaz (bkz. player/guard_bubble.gd). Balonun ilk anlarında
# gelen saldırı parry sayılır: yerdeyken parry animasyonu, havadayken balon patlaması.

extends ItemEffect

func _init():
	item_id = "kalkan_kuresi"
	item_name = tr("item.kalkan_kuresi.name")
	description = tr("item.kalkan_kuresi.description")
	flavor_text = "Durmadan savun"
	rarity = ItemRarity.RARE
	category = ItemCategory.BLOCK
	affected_stats = ["mobile_guard"]

func activate(player: CharacterBody2D):
	super.activate(player)
	if player.has_method("enable_mobile_guard"):
		player.enable_mobile_guard()
	print("[Kalkan Küresi] ✅ Hareket halinde savunma açık")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if is_instance_valid(player) and player.has_method("disable_mobile_guard"):
		player.disable_mobile_guard()
	print("[Kalkan Küresi] ❌ Kaldırıldı")
