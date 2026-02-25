# flank_avantaji.gd
# RARE - Düşmana arkadan vurduğunda +%50 hasar. Görünmezlikle birleşince 4.5x toplam.

extends ItemEffect

const FLANK_MULT := 1.5  # +50%

var _player: CharacterBody2D = null

func _init():
	item_id = "flank_avantaji"
	item_name = "Flank Avantajı"
	description = "Düşmana arkadan vurduğunda +%50 hasar verir. Görünmezlikle birleşince çok güçlü."
	flavor_text = "Sırtından vur"
	rarity = ItemRarity.RARE
	category = ItemCategory.SPECIAL
	affected_stats = ["flank_damage"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_player.flank_damage_mult = FLANK_MULT
	print("[Flank Avantajı] Arkadan vuruş +%50")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player and is_instance_valid(_player):
		_player.flank_damage_mult = 1.0
	_player = null
