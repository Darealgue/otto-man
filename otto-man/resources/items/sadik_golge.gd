# RARE - Ruh Avcısı'nın hayaletleri kalıcı olur (max 2 aktif), her vuruştan sonra yeni hedef arar
# Önkoşul: ruh_avcisi (ITEM_REQUIREMENTS)
extends ItemEffect

func _init():
	item_id = "sadik_golge"
	item_name = "Sadık Gölge"
	description = "Ruh Avcısı hayaletleri kalıcı dolaşır (en fazla 2)"
	flavor_text = "Sadık ruhlar sahibini terk etmez"
	rarity = ItemRarity.RARE
	category = ItemCategory.SPECIAL
	affected_stats = ["persistent_ghosts"]

# Davranış değişikliği ghost_minion.gd içinde: spawn anında bu item aktifse ve
# kalıcı hayalet sayısı 2'nin altındaysa hayalet persistent moda geçer.
func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Sadık Gölge] ✅ Hayaletler kalıcı (max 2)")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	# Mevcut kalıcı hayaletleri normale döndürmek yerine temizle (basit ve öngörülebilir)
	for ghost in get_tree().get_nodes_in_group("persistent_ghosts"):
		if is_instance_valid(ghost):
			ghost.queue_free()
	print("[Sadık Gölge] ❌ Kaldırıldı")
