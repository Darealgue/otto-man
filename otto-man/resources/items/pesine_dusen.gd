# pesine_dusen.gd
# UNCOMMON - Mermiler hafif homing kazanır, en yakın düşmana doğru yolunu büker.
# Önkoşul (VEYA): uzun_menzil veya ok_yagmuru (ITEM_REQUIREMENTS_ANY)
# Etki ItemManager.spawn_upgraded_projectile()'da uygulanır (light_attack_projectile.gd'nin
# homing_strength alanı) — bu item pasif bir işarettir.

extends ItemEffect

func _init():
	item_id = "pesine_dusen"
	item_name = tr("item.pesine_dusen.name")
	description = tr("item.pesine_dusen.description")
	flavor_text = "Kaçış yok, sadece gecikme"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.LIGHT_ATTACK
	affected_stats = ["projectile_homing"]

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Peşine Düşen] ✅ Mermiler hafif homing kazandı")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Peşine Düşen] ❌ Kaldırıldı")
