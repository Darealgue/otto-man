# daire_darbesi.gd
# RARE - Heavy attack (heavy_neutral) artık yönsüz vurur: hitbox'ın vurduğu
# hedeflerin yanı sıra, oyuncunun 100px çevresindeki TÜM düşmanlar da aynı
# hasarı alır (360°).

extends ItemEffect

const SWEEP_RADIUS := 100.0

var _player: CharacterBody2D = null

func _init():
	item_id = "daire_darbesi"
	item_name = tr("item.daire_darbesi.name")
	description = tr("item.daire_darbesi.description")
	flavor_text = "Çevren senin meydanın"
	rarity = ItemRarity.RARE
	category = ItemCategory.HEAVY_ATTACK
	affected_stats = ["heavy_attack_360"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	if player.has_signal("player_attack_landed"):
		if not player.is_connected("player_attack_landed", _on_player_attack_landed):
			player.connect("player_attack_landed", _on_player_attack_landed)
	print("[Daire Darbesi] ✅ Heavy attack artık 360° vuruyor")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player and _player.has_signal("player_attack_landed"):
		if _player.is_connected("player_attack_landed", _on_player_attack_landed):
			_player.disconnect("player_attack_landed", _on_player_attack_landed)
	_player = null
	print("[Daire Darbesi] ❌ Kaldırıldı")

func _on_player_attack_landed(attack_type: String, damage: float, targets: Array, _position: Vector2, effect_filter: String = "all") -> void:
	if effect_filter == "physical_only" or attack_type != "heavy":
		return
	if not is_instance_valid(_player):
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
		if _player.global_position.distance_to(node.global_position) > SWEEP_RADIUS:
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
