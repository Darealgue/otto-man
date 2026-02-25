# tas_yurek.gd
# LEGENDARY - Canın %25'in altına indiyse gelen tüm hasarlar %50 azalır.

extends ItemEffect

const HP_THRESHOLD := 0.25
const DAMAGE_REDUCTION := 0.50

var _player: CharacterBody2D = null

func _init():
	item_id = "tas_yurek"
	item_name = "Taş Yürek"
	description = "Canın %25'in altına indiyse gelen tüm hasarlar %50 azalır."
	flavor_text = "Son direnç"
	rarity = ItemRarity.LEGENDARY
	category = ItemCategory.SPECIAL
	affected_stats = ["low_hp_reduction"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_player.tas_yurek_reduction = DAMAGE_REDUCTION
	print("[Taş Yürek] Can %25 altında %50 hasar azalması")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player and is_instance_valid(_player):
		_player.tas_yurek_reduction = 0.0
	_player = null
