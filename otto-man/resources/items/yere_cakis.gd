# yere_cakis.gd
# RARE - Havadaki aşağı saldırı (air_attack_down1/2) isabet ettiğinde, iniş
# noktasının 60px çevresine küçük bir şok dalgası yayılır — juggle'ın finalini
# ödüllendiren bir "yere çakış" hissi. Ateş Topu Düşüşü vb. fall-attack
# item'larından farklı: fall_attack değil, HAVADAKİ aşağı saldırıya bağlı.

extends ItemEffect

const SLAM_RADIUS := 60.0
const SLAM_DAMAGE := 8.0
const _AoeBurstRingScript = preload("res://effects/aoe_burst_ring.gd")
const IMPACT_COLOR := Color(1.0, 0.9, 0.6, 0.8)
const DOWN_AIR_NAMES := ["air_attack_down1", "air_attack_down2"]

var _player: CharacterBody2D = null
var _hitbox: Node = null

func _init():
	item_id = "yere_cakis"
	item_name = tr("item.yere_cakis.name")
	description = tr("item.yere_cakis.description")
	flavor_text = "Havadan gelen, yeri sarsar"
	rarity = ItemRarity.RARE
	category = ItemCategory.SPECIAL
	affected_stats = ["air_down_slam"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_hitbox = player.get_node_or_null("Hitbox")
	if player.has_signal("player_attack_landed"):
		if not player.is_connected("player_attack_landed", _on_player_attack_landed):
			player.connect("player_attack_landed", _on_player_attack_landed)
	print("[Yere Çakış] ✅ Havadaki aşağı saldırı şok dalgası yayıyor")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player and _player.has_signal("player_attack_landed"):
		if _player.is_connected("player_attack_landed", _on_player_attack_landed):
			_player.disconnect("player_attack_landed", _on_player_attack_landed)
	_player = null
	_hitbox = null
	print("[Yere Çakış] ❌ Kaldırıldı")

func _on_player_attack_landed(attack_type: String, _damage: float, targets: Array, position: Vector2, effect_filter: String = "all") -> void:
	if effect_filter == "physical_only" or attack_type != "normal":
		return
	if not is_instance_valid(_hitbox):
		return
	if not DOWN_AIR_NAMES.has(String(_hitbox.get("current_attack_name"))):
		return
	var already: Array = []
	for t in targets:
		var e = _resolve_enemy_node(t)
		if e:
			already.append(e)
	var tree = get_tree()
	if not tree:
		return
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		if already.has(node):
			continue
		if position.distance_to(node.global_position) > SLAM_RADIUS:
			continue
		if node.has_method("take_damage"):
			node.take_damage(SLAM_DAMAGE, 100.0, 40.0, true)
	if tree.current_scene:
		var burst = Node2D.new()
		burst.set_script(_AoeBurstRingScript)
		tree.current_scene.add_child(burst)
		burst.setup(position, SLAM_RADIUS, IMPACT_COLOR)

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
