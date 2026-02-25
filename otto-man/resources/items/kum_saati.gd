# kum_saati.gd
# RARE - Zaman Durdurucu ile birlikte: perfect parry zaman yavaşlatması 2x daha yavaş ve 4 sn sürer.
# Tek başına bir şey yapmaz; sadece Zaman Durdurucu varken seçenekte çıkar.

extends ItemEffect

func _init():
	item_id = "kum_saati"
	item_name = "Kum Saati"
	description = "Zaman Durdurucu ile: zaman 2x daha yavaş akar, 4 sn sürer."
	flavor_text = "Kum akıyor..."
	rarity = ItemRarity.RARE
	category = ItemCategory.PARRY
	affected_stats = ["parry_time_slow"]

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Kum Saati] ✅ Zaman yavaşlatma güçlendi (Zaman Durdurucu ile)")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Kum Saati] ❌ Kaldırıldı")
