# agir_yumruk.gd
# UNCOMMON - Havadaki (juggle penceresindeki) bir düşmana yapılan saldırılar
# %30 daha güçlü — devam eden juggle'ı ödüllendirir. Davranış
# player_hitbox.gd'nin air_target_damage_multiplier alanı üzerinden
# get_damage_for_target()'ta (her hedef için hasar hesaplanan asıl nokta,
# base_enemy.gd/boss'lar/basic_enemy.gd hepsi buradan çağırıyor) uygulanır.

extends ItemEffect

const AIR_TARGET_MULTIPLIER := 1.3

var _hitbox: Node = null

func _init():
	item_id = "agir_yumruk"
	item_name = tr("item.agir_yumruk.name")
	description = tr("item.agir_yumruk.description")
	flavor_text = "Havadaki düşmana ikinci bir şans yok"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.HEAVY_ATTACK
	affected_stats = ["air_target_damage"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_hitbox = player.get_node_or_null("Hitbox")
	if _hitbox:
		_hitbox.air_target_damage_multiplier = AIR_TARGET_MULTIPLIER
	print("[Ağır Yumruk] ✅ Havadaki düşmana saldırılar %30 güçlü")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _hitbox and is_instance_valid(_hitbox):
		_hitbox.air_target_damage_multiplier = 1.0
	_hitbox = null
	print("[Ağır Yumruk] ❌ Kaldırıldı")
