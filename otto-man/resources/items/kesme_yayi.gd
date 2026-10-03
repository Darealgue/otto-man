# kesme_yayi.gd
# UNCOMMON - Light attack combo'sunun SON vuruşu (attack_1.4) geniş bir yay
# çizip oyuncunun 90px çevresindeki herkese değer (180°).

extends ItemEffect

const ARC_RADIUS := 90.0
const _AoeBurstRingScript = preload("res://effects/aoe_burst_ring.gd")
const IMPACT_COLOR := Color(1.0, 0.9, 0.6, 0.8)
## Hafif saldırı varyantları rastgele seçildiği için animasyon adına bağlamak "son vuruş"
## değil rastgele tetiklenme demekti. Ardışık vuruş sayılıyor (4.'sü).
const EVERY_NTH_HIT := 4
const CHAIN_WINDOW := 1.5
var _chain := 0
var _chain_timer := 0.0

var _player: CharacterBody2D = null
var _hitbox: Node = null

func _init():
	item_id = "kesme_yayi"
	item_name = tr("item.kesme_yayi.name")
	description = tr("item.kesme_yayi.description")
	flavor_text = "Son vuruş en genişi"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.LIGHT_ATTACK
	affected_stats = ["light_attack_arc"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_hitbox = player.get_node_or_null("Hitbox")
	if player.has_signal("player_attack_landed"):
		if not player.is_connected("player_attack_landed", _on_player_attack_landed):
			player.connect("player_attack_landed", _on_player_attack_landed)
	print("[Kesme Yayı] ✅ Combo'nun son vuruşu 180° kapsıyor")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player and _player.has_signal("player_attack_landed"):
		if _player.is_connected("player_attack_landed", _on_player_attack_landed):
			_player.disconnect("player_attack_landed", _on_player_attack_landed)
	_player = null
	_hitbox = null
	print("[Kesme Yayı] ❌ Kaldırıldı")

func process(_player_ref: CharacterBody2D, delta: float) -> void:
	if _chain_timer > 0.0:
		_chain_timer -= delta
		if _chain_timer <= 0.0:
			_chain = 0

func _on_player_attack_landed(attack_type: String, damage: float, targets: Array, _position: Vector2, effect_filter: String = "all") -> void:
	if effect_filter == "physical_only" or attack_type != "normal":
		return
	if not is_instance_valid(_player):
		return
	_chain += 1
	_chain_timer = CHAIN_WINDOW
	if _chain % EVERY_NTH_HIT != 0:
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
		if _player.global_position.distance_to(node.global_position) > ARC_RADIUS:
			continue
		if node.has_method("take_damage"):
			node.take_damage(damage, 0.0, 0.0, true)
	if tree.current_scene:
		var burst = Node2D.new()
		burst.set_script(_AoeBurstRingScript)
		tree.current_scene.add_child(burst)
		burst.setup(_player.global_position, ARC_RADIUS, IMPACT_COLOR)

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
