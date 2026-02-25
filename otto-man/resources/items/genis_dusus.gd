# genis_dusus.gd
# COMMON item - Fall attack 2 düşmana vurabilir

extends ItemEffect

const MAX_TARGETS = 2  # Fall attack ile 2 düşmana vur

func _init():
	item_id = "genis_dusus"
	item_name = "Geniş Düşüş"
	description = "Fall attack 2 düşmana vurabilir"
	flavor_text = "Daha geniş etki"
	rarity = ItemRarity.COMMON
	category = ItemCategory.FALL_ATTACK
	affected_stats = ["fall_attack_targets"]

var _player: CharacterBody2D = null
var _fall_attack_hitbox: Node = null  # PlayerHitbox (FallAttack node)

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	var fall_attack_hitbox = player.get_node_or_null("FallAttack")
	if fall_attack_hitbox and fall_attack_hitbox is PlayerHitbox:
		_fall_attack_hitbox = fall_attack_hitbox
		if not _fall_attack_hitbox.has_meta("original_max_targets_genis_dusus"):
			_fall_attack_hitbox.set_meta("original_max_targets_genis_dusus", _fall_attack_hitbox.max_targets_per_attack)
		_fall_attack_hitbox.max_targets_per_attack = MAX_TARGETS
		print("[Geniş Düşüş] ✅ Fall attack 2 düşmana vurabilir")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _fall_attack_hitbox and is_instance_valid(_fall_attack_hitbox) and _fall_attack_hitbox.has_meta("original_max_targets_genis_dusus"):
		_fall_attack_hitbox.max_targets_per_attack = _fall_attack_hitbox.get_meta("original_max_targets_genis_dusus")
		_fall_attack_hitbox.remove_meta("original_max_targets_genis_dusus")
	_player = null
	_fall_attack_hitbox = null
	print("[Geniş Düşüş] ❌ Fall attack tek düşmana döndü")
