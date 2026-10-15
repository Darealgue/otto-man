# kum_saati.gd
# RARE - Zaman Durdurucu ile birlikte: perfect parry zaman yavaşlatması 2x daha yavaş ve 4 sn sürer.
# Tek başına bir şey yapmaz; sadece Zaman Durdurucu varken seçenekte çıkar.

extends ItemEffect

func _init():
	item_id = "kum_saati"
	item_name = tr("item.kum_saati.name")
	description = tr("item.kum_saati.description")
	flavor_text = "Kum akıyor..."
	category = ItemCategory.PARRY
	affected_stats = ["parry_time_slow"]

func activate(player: CharacterBody2D):
	super.activate(player)

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
