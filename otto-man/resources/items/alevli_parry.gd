# alevli_parry.gd
# RARE - Perfect parry saldırganın yönüne alev dalgası gönderir; şeritteki düşmanlar yanar.
# Savunma hattının "karşılık verip yak" ayağı.

extends ItemEffect

const WAVE_LENGTH := 240.0
const WAVE_PATCHES := 5

var _player: CharacterBody2D = null

func _init():
	item_id = "alevli_parry"
	item_name = tr("item.alevli_parry.name")
	description = tr("item.alevli_parry.description")
	flavor_text = "Savuşturan, yakar"
	rarity = ItemRarity.RARE
	category = ItemCategory.PARRY
	affected_stats = ["parry_flame_wave"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null

func _on_perfect_parry() -> void:
	if not is_instance_valid(_player):
		return
	var im := get_node_or_null("/root/ItemManager")
	if im == null:
		return
	var dir_x: float = float(_player.get("facing_direction")) if _player.get("facing_direction") != null else 1.0
	var block_state := _player.get_node_or_null("StateMachine/Block")
	if block_state and block_state.get("_last_parried_attacker") != null:
		var attacker = block_state.get("_last_parried_attacker")
		if is_instance_valid(attacker) and attacker is Node2D:
			dir_x = 1.0 if attacker.global_position.x >= _player.global_position.x else -1.0
	im.spawn_flame_wave(_player.global_position, dir_x, WAVE_LENGTH, WAVE_PATCHES)
