# UNCOMMON - Hafif saldırılar aynı vuruşta 2 düşmana temas edebilir
extends ItemEffect

const MAX_TARGETS = 2

var _hitbox: Node = null

func _init():
	item_id = "pala_kilici"
	item_name = "Pala Kılıcı"
	description = "Hafif saldırılar 2 düşmana birden vurabilir"
	flavor_text = "Tek savuruş, iki bela"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.LIGHT_ATTACK
	affected_stats = ["light_attack_targets"]

func activate(player: CharacterBody2D):
	super.activate(player)
	var hitbox = player.get_node_or_null("Hitbox")
	if hitbox and hitbox is PlayerHitbox:
		_hitbox = hitbox
		_hitbox.max_targets_light = MAX_TARGETS
		print("[Pala Kılıcı] ✅ Hafif saldırı 2 düşmana vurabilir")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _hitbox and is_instance_valid(_hitbox):
		_hitbox.max_targets_light = -1
	_hitbox = null
	print("[Pala Kılıcı] ❌ Hafif saldırı tek düşmana döndü")
