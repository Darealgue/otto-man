# nobetci.gd
# COMMON - Yerinde savunma yaparken (Block basılı tutma ya da yerde duran balon) stamina
# 2 kat hızlı yenilenir. Yenilenme hızını stamina_bar.gd uygular.

extends ItemEffect

const REGEN_MULT := 2.0

func _init():
	item_id = "nobetci"
	item_name = tr("item.nobetci.name")
	description = tr("item.nobetci.description")
	flavor_text = "Sabır, en iyi zırhtır"
	rarity = ItemRarity.COMMON
	category = ItemCategory.BLOCK
	affected_stats = ["guard_regen"]

func activate(player: CharacterBody2D):
	super.activate(player)
	player.block_regen_mult = REGEN_MULT
	print("[Nöbetçi] ✅ Yerinde savunmada stamina 2x hızlı dolar")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if is_instance_valid(player):
		player.block_regen_mult = 1.0
	print("[Nöbetçi] ❌ Kaldırıldı")
