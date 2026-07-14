# RARE - Ağır saldırı genişler: 3 düşmana birden vurabilir, hitbox %40 daha geniş
extends ItemEffect

const MAX_TARGETS = 3
const SHAPE_SCALE_X = 1.4

var _hitbox: Node = null

func _init():
	item_id = "cenk_meydani"
	item_name = "Cenk Meydanı"
	description = "Ağır saldırı %40 genişler ve 3 düşmana birden vurabilir"
	flavor_text = "Meydan senin"
	rarity = ItemRarity.RARE
	category = ItemCategory.HEAVY_ATTACK
	affected_stats = ["heavy_attack_targets"]

func activate(player: CharacterBody2D):
	super.activate(player)
	var hitbox = player.get_node_or_null("Hitbox")
	if hitbox and hitbox is PlayerHitbox:
		_hitbox = hitbox
		_hitbox.max_targets_heavy = MAX_TARGETS
		_hitbox.heavy_shape_scale_x = SHAPE_SCALE_X
		print("[Cenk Meydanı] ✅ Ağır saldırı 3 düşmana, %40 geniş")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _hitbox and is_instance_valid(_hitbox):
		_hitbox.max_targets_heavy = -1
		_hitbox.heavy_shape_scale_x = 1.0
		var cs = _hitbox.get_node_or_null("CollisionShape2D")
		if cs:
			cs.scale.x = 1.0
	_hitbox = null
	print("[Cenk Meydanı] ❌ Ağır saldırı normale döndü")
