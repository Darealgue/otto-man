# patlama_topuzu.gd
# RARE - Heavy attack patlama; yakındaki düşmanlara hasar. Eksi: Charge süresi +%30

extends ItemEffect

const HeavyExplosionScript = preload("res://effects/heavy_explosion.gd")
const CHARGE_SLOW_FACTOR := 0.30  # +30% charge süresi = anim hızı 1/(1.3) ≈ 0.77

var _player: CharacterBody2D = null

func _init():
	item_id = "patlama_topuzu"
	item_name = "Patlama Topuzu"
	description = "Heavy attack patlama yaratır (yakındaki düşmanlara hasar). Charge süresi +%30"
	flavor_text = "Patlayıcı güç"
	rarity = ItemRarity.RARE
	category = ItemCategory.HEAVY_ATTACK
	affected_stats = ["heavy_explosion"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	var heavy_attack_state = player.get_node_or_null("StateMachine/HeavyAttack")
	if heavy_attack_state:
		if not heavy_attack_state.has_meta("original_animation_speed_patlama_topuzu"):
			heavy_attack_state.set_meta("original_animation_speed_patlama_topuzu", heavy_attack_state.ANIMATION_SPEED)
		heavy_attack_state.ANIMATION_SPEED = heavy_attack_state.ANIMATION_SPEED * (1.0 / (1.0 + CHARGE_SLOW_FACTOR))
		print("[Patlama Topuzu] ✅ Heavy attack patlama (charge +%30)")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	var heavy_attack_state = player.get_node_or_null("StateMachine/HeavyAttack")
	if heavy_attack_state and heavy_attack_state.has_meta("original_animation_speed_patlama_topuzu"):
		heavy_attack_state.ANIMATION_SPEED = heavy_attack_state.get_meta("original_animation_speed_patlama_topuzu")
		heavy_attack_state.remove_meta("original_animation_speed_patlama_topuzu")
	_player = null
	print("[Patlama Topuzu] ❌ Kaldırıldı")

func _on_heavy_attack_impact(_attack_name: String = "") -> void:
	if not _player or not is_instance_valid(_player):
		return
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return
	var pos: Vector2 = _player.global_position + Vector2(_player.facing_direction * 40, 0)
	var hitbox = _player.get_node_or_null("Hitbox")
	if hitbox:
		var cs = hitbox.get_node_or_null("CollisionShape2D")
		if cs:
			pos = hitbox.to_global(cs.position)
	var explosion = Node2D.new()
	explosion.set_script(HeavyExplosionScript)
	tree.current_scene.add_child(explosion)
	explosion.global_position = pos
