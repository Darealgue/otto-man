# sirt_darbesi.gd
# RARE - Light attack combo'sunun 3. vuruşu (attack_1.3) artık ARKAYA da vurur —
# çevrelenirsen sırtındaki düşmanı da yakalarsın.

extends ItemEffect

const BACK_RADIUS := 70.0
const THIRD_HIT_NAME := "attack_1.3"

var _player: CharacterBody2D = null
var _hitbox: Node = null

func _init():
	item_id = "sirt_darbesi"
	item_name = tr("item.sirt_darbesi.name")
	description = tr("item.sirt_darbesi.description")
	flavor_text = "Gözün arkanda da olsun"
	rarity = ItemRarity.RARE
	category = ItemCategory.LIGHT_ATTACK
	affected_stats = ["light_attack_back_hit"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_hitbox = player.get_node_or_null("Hitbox")
	if player.has_signal("player_attack_landed"):
		if not player.is_connected("player_attack_landed", _on_player_attack_landed):
			player.connect("player_attack_landed", _on_player_attack_landed)
	print("[Sırt Darbesi] ✅ 3. combo vuruşu arkaya da vuruyor")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player and _player.has_signal("player_attack_landed"):
		if _player.is_connected("player_attack_landed", _on_player_attack_landed):
			_player.disconnect("player_attack_landed", _on_player_attack_landed)
	_player = null
	_hitbox = null
	print("[Sırt Darbesi] ❌ Kaldırıldı")

func _on_player_attack_landed(attack_type: String, damage: float, targets: Array, _position: Vector2, effect_filter: String = "all") -> void:
	if effect_filter == "physical_only" or attack_type != "normal":
		return
	if not is_instance_valid(_player) or not is_instance_valid(_hitbox):
		return
	if String(_hitbox.get("current_attack_name")) != THIRD_HIT_NAME:
		return
	var already: Array = []
	for t in targets:
		var e = _resolve_enemy_node(t)
		if e:
			already.append(e)
	# Sırt yönü: oyuncunun baktığı yönün TERSİ
	var facing_left: bool = _player.sprite.flip_h if _player.sprite else false
	var back_dir := Vector2(1.0 if facing_left else -1.0, 0.0)
	var back_origin: Vector2 = _player.global_position + back_dir * (BACK_RADIUS * 0.5)
	var tree = get_tree()
	if not tree:
		return
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		if already.has(node):
			continue
		if back_origin.distance_to(node.global_position) > BACK_RADIUS:
			continue
		if node.has_method("take_damage"):
			node.take_damage(damage, 0.0, 0.0, true)

func _resolve_enemy_node(target: Node) -> Node:
	if not is_instance_valid(target):
		return null
	if target.has_method("take_damage"):
		return target
	var p = target.get_parent()
	if p and p.has_method("take_damage"):
		return p
	if p and p.get_parent() and p.get_parent().has_method("take_damage"):
		return p.get_parent()
	return null
