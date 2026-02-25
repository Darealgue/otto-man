# ates_topu_dususu.gd
# UNCOMMON - Fall attack alev patlaması (hasar + yanma, 10 sn cooldown)

extends ItemEffect

const COOLDOWN_DURATION := 10.0
const EXPLOSION_RADIUS := 90.0
const EXPLOSION_DAMAGE := 6.0

var _player: CharacterBody2D = null
var _cooldown := 0.0

func _init():
	item_id = "ates_topu_dususu"
	item_name = "Ateş Topu Düşüşü"
	description = "Fall attack alev patlaması (hasar + yanma, 10 sn cooldown)"
	flavor_text = "Ateşli düşüş"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.FALL_ATTACK
	affected_stats = ["fall_fire"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_cooldown = 0.0
	if player.has_signal("fall_attack_impacted"):
		if not player.is_connected("fall_attack_impacted", _on_fall_attack_impacted):
			player.connect("fall_attack_impacted", _on_fall_attack_impacted)
		print("[Ateş Topu Düşüşü] ✅ Fall attack alev patlaması (10 sn cooldown)")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player:
		if _player.has_signal("fall_attack_impacted") and _player.is_connected("fall_attack_impacted", _on_fall_attack_impacted):
			_player.disconnect("fall_attack_impacted", _on_fall_attack_impacted)
	_player = null
	print("[Ateş Topu Düşüşü] ❌ Kaldırıldı")

func process(player: CharacterBody2D, delta: float) -> void:
	if _cooldown > 0:
		_cooldown -= delta

func _on_fall_attack_impacted(position: Vector2) -> void:
	apply_fall_attack_effect_at(position, false)

func apply_fall_attack_effect_at(position: Vector2, is_decoy: bool) -> void:
	if not is_decoy:
		if _cooldown > 0:
			return
		_cooldown = COOLDOWN_DURATION
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return
	var enemies = tree.get_nodes_in_group("enemies")
	for node in enemies:
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		if position.distance_to(node.global_position) <= EXPLOSION_RADIUS:
			if node.has_method("take_damage"):
				node.take_damage(EXPLOSION_DAMAGE, 0.0, 0.0, true)
			if node.has_method("add_burn_stack"):
				node.add_burn_stack()
