# guc_devri.gd
# RARE - Bir vuruş öldürürse, sıradaki vuruşun hasarı +%50 (can çalmıyor —
# zincirleme öldürmeyi ödüllendiren bir bonus).

extends ItemEffect

const BONUS_MULTIPLIER := 1.5

var _hitbox: Node = null

func _init():
	item_id = "guc_devri"
	item_name = tr("item.guc_devri.name")
	description = tr("item.guc_devri.description")
	flavor_text = "Ölüm güç doğurur"
	rarity = ItemRarity.RARE
	category = ItemCategory.SPECIAL
	affected_stats = ["kill_chain_damage"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_hitbox = player.get_node_or_null("Hitbox")
	print("[Güç Devri] ✅ Öldürme sonrası sıradaki vuruş +%50")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _hitbox and is_instance_valid(_hitbox):
		_hitbox.next_attack_bonus_multiplier = 1.0
	_hitbox = null
	print("[Güç Devri] ❌ Kaldırıldı")

func on_enemy_killed(_enemy: Node2D) -> void:
	if _hitbox and is_instance_valid(_hitbox):
		_hitbox.next_attack_bonus_multiplier = BONUS_MULTIPLIER
