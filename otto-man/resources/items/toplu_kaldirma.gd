# toplu_kaldirma.gd
# RARE - Bir düşman gerçek bir fırlatmayla (up_heavy, Zıplatan Yumruk vb.) havaya
# kalkarsa, 80px içindeki diğer tüm düşmanlar da aynı kuvvetle havalanır — tekli
# juggle'ı grup juggle'ına çevirir. Ekstra hasar vermez, sadece hedef genişletir.
# Davranış enemy/base_enemy.gd içinde (_try_group_launch_nearby_enemies)
# kontrol edilir, bu item pasif bir işarettir.

extends ItemEffect

func _init():
	item_id = "toplu_kaldirma"
	item_name = tr("item.toplu_kaldirma.name")
	description = tr("item.toplu_kaldirma.description")
	flavor_text = "Biri uçarsa hepsi uçar"
	rarity = ItemRarity.RARE
	category = ItemCategory.HEAVY_ATTACK
	affected_stats = ["group_launch"]

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Toplu Kaldırma] ✅ Fırlatma artık yakındaki tüm düşmanları da kaldırıyor")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Toplu Kaldırma] ❌ Kaldırıldı")
