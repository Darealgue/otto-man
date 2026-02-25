# berserker_ruhu.gd
# RARE - Can azaldıkça verdiğin hasar artar (en fazla +%100). Daha fazla hasar alırsın.

extends ItemEffect

const MAX_DAMAGE_BONUS := 1.0  # +%100 at 0% HP
const INCOMING_DAMAGE_MULT := 1.25  # %25 daha fazla hasar alırsın

var _player: CharacterBody2D = null

func _init():
	item_id = "berserker_ruhu"
	item_name = "Berserker Ruhu"
	description = "Canın azaldıkça verdiğin hasar artar (en fazla iki kat). Daha fazla hasar alırsın."
	flavor_text = "Öfke güç verir"
	rarity = ItemRarity.RARE
	category = ItemCategory.SPECIAL
	affected_stats = ["berserker_damage", "berserker_incoming"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_player.incoming_damage_multiplier *= INCOMING_DAMAGE_MULT
	_update_bonus()
	print("[Berserker Ruhu] Can azaldıkça hasar artar, daha fazla hasar alırsın")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player and is_instance_valid(_player):
		_player.berserker_damage_bonus = 0.0
		_player.incoming_damage_multiplier /= INCOMING_DAMAGE_MULT
		if _player.hitbox:
			_player.hitbox.damage = _player.base_damage * _player.get_effective_damage_multiplier()
	_player = null

func process(player: CharacterBody2D, delta: float) -> void:
	if not is_instance_valid(player):
		return
	_update_bonus()

func _update_bonus():
	if not _player or not is_instance_valid(_player):
		return
	var ps = _player.get_node_or_null("/root/PlayerStats")
	if not ps:
		return
	var cur = ps.get_current_health()
	var max_hp = ps.get_max_health()
	if max_hp <= 0:
		_player.berserker_damage_bonus = 0.0
		return
	var missing_ratio = 1.0 - (cur / max_hp)
	_player.berserker_damage_bonus = missing_ratio * MAX_DAMAGE_BONUS
	if _player.hitbox:
		_player.hitbox.damage = _player.base_damage * _player.get_effective_damage_multiplier()
