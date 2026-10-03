# Top mermisi: Ok Yağmuru'nun varsayılan ağır saldırı mermisi. Ok'tan yavaş, iri, isabette güçlü
# knockback ve çevresine alan (splash) hasarı verir. Ateş Bombası (player_fire_bomb_projectile.gd)
# bu script'ten türer ve aynı splash mantığını yeniden kullanır. Tüm mermi yükseltmeleri
# (Sürü Oku, Yansıyan Ok, Ruh Mermisi, element, echo...) light_attack_projectile.gd tabanından gelir.
extends "res://effects/light_attack_projectile.gd"

const _AoeBurstRingScript = preload("res://effects/aoe_burst_ring.gd")

var splash_radius: float = 70.0
var splash_ratio: float = 0.5
var splash_color: Color = Color(0.85, 0.8, 0.7, 0.8)
var splash_burn: bool = false
var cannon_knockback: float = 220.0
var cannon_knockback_up: float = 60.0

func setup(origin: Vector2, direction: Vector2, damage: float) -> void:
	super.setup(origin, direction, damage)
	_speed = 650.0
	_hit_radius = 64.0
	_ball_radius = 15.0
	_ball_color = Color(0.28, 0.25, 0.22)

func _on_hit(node: Node, world_pos: Vector2) -> void:
	# Ağır Mermi daha yüksek bir değer verdiyse o korunur
	knockback_force = maxf(knockback_force, cannon_knockback)
	knockback_up_force = maxf(knockback_up_force, cannon_knockback_up)
	if splash_burn and is_instance_valid(node) and node.has_method("add_burn_stack"):
		node.add_burn_stack()
	_splash(node, world_pos)
	super._on_hit(node, world_pos)

## world_pos çevresindeki (primary hariç) canlı düşmanlara splash_ratio x hasar verir, projectile'ın
## taşıdığı elementi uygular ve tek bir player_attack_landed("ranged") olayı yayınlar (element
## kaynağı item'ları patlamadan etkilenen herkese uygulansın diye). primary null olabilir.
func _splash(primary: Node, world_pos: Vector2) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var victims: Array = []
	var splash_damage: float = _damage * splash_ratio
	for n in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(n) or n == primary or n.get("current_behavior") == "dead":
			continue
		if world_pos.distance_to(n.global_position) > splash_radius or not n.has_method("take_damage"):
			continue
		n.take_damage(splash_damage, 140.0, 70.0, true)
		_apply_element(n)
		if splash_burn and n.has_method("add_burn_stack"):
			n.add_burn_stack()
		victims.append(n)
	if tree.current_scene:
		var ring := Node2D.new()
		ring.set_script(_AoeBurstRingScript)
		tree.current_scene.add_child(ring)
		ring.setup(world_pos, splash_radius, splash_color)
	if not victims.is_empty():
		var p = tree.get_first_node_in_group("player")
		if p and p.has_signal("player_attack_landed"):
			p.emit_signal("player_attack_landed", "ranged", splash_damage, victims, world_pos, "all")
