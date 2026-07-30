# UNCOMMON - Mermin çarptıktan 1sn sonra aynı noktada %60 hasarlık ikinci patlama olur
extends ItemEffect

func _init():
	item_id = "yanki_oku"
	item_name = tr("item.yanki_oku.name")
	description = tr("item.yanki_oku.description")
	flavor_text = "Ses gider, yankı kalır"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.LIGHT_ATTACK
	affected_stats = ["projectile_echo"]

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Yankı Oku] ✅ Mermiler yankılanıyor")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Yankı Oku] ❌ Kaldırıldı")
