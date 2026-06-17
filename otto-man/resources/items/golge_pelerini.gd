# golge_pelerini.gd
# UNCOMMON - Düşman görüş konisi menzili -%20

extends ItemEffect

const VISION_REDUCTION: float = 0.8  # düşman algısı %80

var _player: CharacterBody2D = null

func _init():
	item_id = "golge_pelerini"
	item_name = "Gölge Pelerini"
	description = "Düşmanların görüş menzili -%20"
	flavor_text = "Gölgelerde kaybol"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.SPECIAL
	affected_stats = ["stealth_vision"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	player.stealth_enemy_vision_mult = VISION_REDUCTION
	print("[Gölge Pelerini] Düşman görüş menzili -%d%%" % int((1.0 - VISION_REDUCTION) * 100.0))

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player and is_instance_valid(_player):
		_player.stealth_enemy_vision_mult = 1.0
	_player = null
