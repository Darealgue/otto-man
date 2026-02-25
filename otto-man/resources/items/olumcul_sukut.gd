# olumcul_sukut.gd
# UNCOMMON - Blok veya parry yaptıktan sonraki ilk light attack ekstra hasar verir.

extends ItemEffect

const BONUS_MULTIPLIER := 1.5  # +50% hasar

var _player: CharacterBody2D = null

func _init():
	item_id = "olumcul_sukut"
	item_name = "Ölümcül Sükût"
	description = "Blok veya parry yaptıktan sonraki ilk hafif saldırın ekstra hasar verir."
	flavor_text = "Sessizlikten sonra darbe"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.PARRY
	affected_stats = ["counter_light_bonus"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	if player.has_signal("perfect_parry"):
		if not player.is_connected("perfect_parry", _on_parry_or_block):
			player.connect("perfect_parry", _on_parry_or_block)
	if player.has_signal("player_blocked"):
		if not player.is_connected("player_blocked", _on_parry_or_block):
			player.connect("player_blocked", _on_parry_or_block)
	print("[Ölümcül Sükût] Parry/blok sonrası ilk light attack +%50")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player:
		_player.olumcul_sukut_next_light_bonus = 1.0
		if _player.has_signal("perfect_parry") and _player.is_connected("perfect_parry", _on_parry_or_block):
			_player.disconnect("perfect_parry", _on_parry_or_block)
		if _player.has_signal("player_blocked") and _player.is_connected("player_blocked", _on_parry_or_block):
			_player.disconnect("player_blocked", _on_parry_or_block)
	_player = null

func _on_parry_or_block(_a = null, _b = null):
	if _player and is_instance_valid(_player):
		_player.olumcul_sukut_next_light_bonus = BONUS_MULTIPLIER
