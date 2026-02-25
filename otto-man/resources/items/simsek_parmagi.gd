# simsek_parmagi.gd
# RARE - Light attack belli ihtimalle şimşek çakar; düşmanda buz varsa ihtimal 2x

extends ItemEffect

const LIGHTNING_CHANCE := 0.20  # %20 temel ihtimal
const LIGHTNING_DAMAGE := 5.0
const CHAIN_RADIUS := 120.0
const CHAIN_DAMAGE := 3.0
const MAX_CHAIN_TARGETS := 3
const LightningFlashScript = preload("res://effects/lightning_flash.gd")

var _player: CharacterBody2D = null

func _init():
	item_id = "simsek_parmagi"
	item_name = "Şimşek Parmak"
	description = "Light attack belli ihtimalle şimşek çakar; buzlu düşmanda ihtimal 2x"
	flavor_text = "Elektrikli parmaklar"
	rarity = ItemRarity.RARE
	category = ItemCategory.LIGHT_ATTACK
	affected_stats = ["lightning_chain"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	if player.has_signal("player_attack_landed"):
		if not player.is_connected("player_attack_landed", _on_player_attack_landed):
			player.connect("player_attack_landed", _on_player_attack_landed)
		print("[Şimşek Parmak] ✅ Light attack şimşek sıçratır")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player and _player.has_signal("player_attack_landed"):
		if _player.is_connected("player_attack_landed", _on_player_attack_landed):
			_player.disconnect("player_attack_landed", _on_player_attack_landed)
	_player = null
	print("[Şimşek Parmak] ❌ Kaldırıldı")

func _get_enemy_node(target: Node) -> Node:
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

func _has_frost(enemy: Node) -> bool:
	if not is_instance_valid(enemy):
		return false
	var stacks = enemy.get("frost_stacks")
	return int(stacks) > 0 if stacks != null else false

func _on_player_attack_landed(attack_type: String, _damage: float, targets: Array, position: Vector2, effect_filter: String = "all"):
	if effect_filter == "physical_only":
		return  # Hacivat gölgesi: sadece elemental; şimşek uygulanmasın
	if not _player or attack_type != "normal":
		return
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return
	var hit_enemies: Array[Node] = []
	for t in targets:
		var enemy = _get_enemy_node(t)
		if enemy and enemy.get("current_behavior") != "dead" and enemy not in hit_enemies:
			hit_enemies.append(enemy)
	if hit_enemies.is_empty():
		return
	# Şans: temel ihtimal; vurulanlardan birinde buz varsa ihtimal 2 katı
	var chance: float = LIGHTNING_CHANCE
	for enemy in hit_enemies:
		if _has_frost(enemy):
			chance = min(1.0, LIGHTNING_CHANCE * 2.0)
			break
	if randf() >= chance:
		return
	var elem_mult: float = 1.0
	if _player:
		var val = _player.get("elemental_damage_mult")
		if val is float:
			elem_mult = val
		elif val is int:
			elem_mult = float(val)
	var first_dmg: float = LIGHTNING_DAMAGE * elem_mult
	var chain_dmg: float = CHAIN_DAMAGE * elem_mult
	# İlk hedeflere şimşek hasarı
	var first_pos := position
	for enemy in hit_enemies:
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			enemy.take_damage(first_dmg, 0.0, 0.0, true)
			first_pos = enemy.global_position
	# Görsel: ilk vurulan noktada flaş
	var flash = Node2D.new()
	flash.set_script(LightningFlashScript)
	tree.current_scene.add_child(flash)
	flash.global_position = first_pos
	# Zincir: yakındaki diğer düşmanlara sıçra
	var all_enemies = tree.get_nodes_in_group("enemies")
	var chain_count := 0
	for node in all_enemies:
		if chain_count >= MAX_CHAIN_TARGETS:
			break
		if not is_instance_valid(node) or node in hit_enemies:
			continue
		if node.get("current_behavior") == "dead":
			continue
		if first_pos.distance_to(node.global_position) <= CHAIN_RADIUS and node.has_method("take_damage"):
			node.take_damage(chain_dmg, 0.0, 0.0, true)
			chain_count += 1
