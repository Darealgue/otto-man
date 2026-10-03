# ates_bombasi.gd
# RARE - Ok Yağmuru'nun ağır saldırı mermisi, Top yerine zıplayan bir ateş bombasına dönüşür:
# düşmana değince hemen patlar (alan hasarı + yanma), değmezse zeminde 2-3 kez sekip 3 sn'de ya da
# sekmeler bitince patlar. Sürü Oku 3 bomba atar, Ruh Mermisi/Yansıyan Ok patlayan bombayı bir sonraki
# düşmana yönlendirir, elementler patlamaya işler.
# Önkoşul: ok_yagmuru (ITEM_REQUIREMENTS_ANY). Davranış ok_yagmuru.gd'de has_active_item ile okunur
# ve effects/player_fire_bomb_projectile.gd'dedir — bu item pasif bir işarettir.

extends ItemEffect

func _init():
	item_id = "ates_bombasi"
	item_name = tr("item.ates_bombasi.name")
	description = tr("item.ates_bombasi.description")
	flavor_text = "Sekerek gelir, patlayarak gider"
	rarity = ItemRarity.RARE
	category = ItemCategory.HEAVY_ATTACK
	affected_stats = ["heavy_projectile_bomb"]

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Ateş Bombası] ✅ Ağır saldırı mermisi zıplayan ateş bombası oldu")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Ateş Bombası] ❌ Kaldırıldı")
