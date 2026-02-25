# elemental_odak.gd
# RARE - Elemental hasar +%300, fiziksel hasar -%75. Büyücü build'i teşvik eder.

extends ItemEffect

const ELEMENTAL_MULT := 4.0   # +300%
const PHYSICAL_MULT := 0.25  # -75%

var _player: CharacterBody2D = null

func _init():
	item_id = "elemental_odak"
	item_name = "Elemental Odak"
	description = "Elemental hasar (zehir, ateş, buz, şimşek) +%300 artar. Fiziksel hasar -%75 düşer."
	flavor_text = "Büyücü ruhu"
	rarity = ItemRarity.RARE
	category = ItemCategory.SPECIAL
	affected_stats = ["elemental_focus"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_player.physical_damage_mult = PHYSICAL_MULT
	_player.elemental_damage_mult = ELEMENTAL_MULT
	print("[Elemental Odak] Elemental 4x, fiziksel 0.25x")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player and is_instance_valid(_player):
		_player.physical_damage_mult = 1.0
		_player.elemental_damage_mult = 1.0
	_player = null
