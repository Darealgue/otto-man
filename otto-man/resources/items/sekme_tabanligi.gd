# UNCOMMON - Düşüş saldırısı yere çarpınca otomatik tekrar zıplar (pogo), hitbox yeniden aktif olur
extends ItemEffect

func _init():
	item_id = "sekme_tabanligi"
	item_name = "Sekme Tabanlığı"
	description = "Düşüş saldırısı yere çarpınca otomatik pogo zıplaması yapar"
	flavor_text = "Yer, senin için bir yaydır"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.FALL_ATTACK
	affected_stats = ["fall_attack_pogo"]

# Davranış player/states/air/fall_attack_state.gd içinde kontrol edilir. Bu item pasif bir işarettir.

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Sekme Tabanlığı] ✅ Düşüş saldırısı zeminde sekiyor")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Sekme Tabanlığı] ❌ Kaldırıldı")
