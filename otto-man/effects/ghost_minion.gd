# ghost_minion.gd - Ruh Avcısı: ölen düşmandan çıkan kısa süreli hayalet, en yakın düşmana gidip hasar verir
extends Node2D

const SPEED := 220.0
const HIT_RADIUS := 28.0
const DAMAGE := 4.0
const LIFETIME := 4.5
const TICK := 0.05

var _age := 0.0
var _hit_enemies: Dictionary = {}  # id -> true

func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	var tree = get_tree()
	if not tree:
		return
	var enemies = tree.get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist := 9999.0
	for node in enemies:
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		var d = global_position.distance_to(node.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = node
	if nearest and nearest_dist <= HIT_RADIUS:
		if nearest.has_method("take_damage") and not _hit_enemies.get(nearest.get_instance_id(), false):
			_hit_enemies[nearest.get_instance_id()] = true
			nearest.take_damage(DAMAGE, 40.0, -30.0, true)
		queue_free()
		return
	if nearest:
		var dir = (nearest.global_position - global_position).normalized()
		global_position += dir * SPEED * delta

func _draw() -> void:
	# Basit hayalet görseli: yarı saydam daire
	draw_circle(Vector2.ZERO, 10, Color(0.9, 0.95, 1.0, 0.6))

func _process(_delta: float) -> void:
	queue_redraw()
