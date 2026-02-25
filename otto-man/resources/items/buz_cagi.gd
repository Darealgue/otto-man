# buz_cagi.gd
# UNCOMMON - Fall attack donma dalgası (yakındaki düşmanları yavaşlatır/dondurur)

extends ItemEffect

const COOLDOWN_DURATION := 10.0
const FROST_RADIUS := 100.0
const FROST_STACKS := 5
const FROST_DAMAGE := 3.0

var _player: CharacterBody2D = null
var _cooldown := 0.0

func _init():
	item_id = "buz_cagi"
	item_name = "Buz Çağı"
	description = "Fall attack donma dalgası (yakındakileri yavaşlatır, 10 sn cooldown)"
	flavor_text = "Buzlu düşüş"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.FALL_ATTACK
	affected_stats = ["fall_frost"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_cooldown = 0.0
	if player.has_signal("fall_attack_impacted"):
		if not player.is_connected("fall_attack_impacted", _on_fall_attack_impacted):
			player.connect("fall_attack_impacted", _on_fall_attack_impacted)
	print("[Buz Çağı] ✅ Fall attack donma dalgası (10 sn cooldown)")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player and _player.has_signal("fall_attack_impacted"):
		if _player.is_connected("fall_attack_impacted", _on_fall_attack_impacted):
			_player.disconnect("fall_attack_impacted", _on_fall_attack_impacted)
	_player = null
	print("[Buz Çağı] ❌ Kaldırıldı")

func process(_player_node: CharacterBody2D, delta: float) -> void:
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
	if not tree:
		return
	var enemies = tree.get_nodes_in_group("enemies")
	for node in enemies:
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		if position.distance_to(node.global_position) <= FROST_RADIUS:
			if node.has_method("take_damage"):
				node.take_damage(FROST_DAMAGE, 0.0, 0.0, true)
			if node.has_method("add_frost_stack"):
				node.add_frost_stack(FROST_STACKS)
