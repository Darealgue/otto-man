# keskin_refleks.gd
# COMMON - Parry penceresi kapandıktan sonraki 0.1 sn içinde gelen vuruş da parry sayılır
# (Block state ve Kalkan Küresi balonu, bkz. player.parry_grace).

extends ItemEffect

const GRACE := 0.1

func _init():
	item_id = "keskin_refleks"
	item_name = tr("item.keskin_refleks.name")
	description = tr("item.keskin_refleks.description")
	flavor_text = "Geç kalmak her zaman geç değildir"
	rarity = ItemRarity.COMMON
	category = ItemCategory.PARRY
	affected_stats = ["parry_grace"]

func activate(player: CharacterBody2D):
	super.activate(player)
	player.parry_grace = GRACE
	print("[Keskin Refleks] ✅ Parry penceresi sonrası +0.1 sn tolerans")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if is_instance_valid(player):
		player.parry_grace = 0.0
	print("[Keskin Refleks] ❌ Kaldırıldı")
