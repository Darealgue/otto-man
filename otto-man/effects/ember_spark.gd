# ember_spark.gd - Zıplayan kıvılcım (Kıvılcım Yağmuru). Yay çizerek düşer, iki kez zıplar, değdiği düşmanı yakar.
# Placeholder görsel: küçük turuncu top. Zemin, doğduğu yükseklik (düşme noktası) kabul edilir.
extends Node2D

const GRAVITY := 900.0
const HIT_RADIUS := 26.0
const HIT_DAMAGE := 3.0
const MAX_LIFETIME := 3.0

var velocity: Vector2 = Vector2.ZERO
var bounces_left: int = 2

var _floor_y: float = 0.0
var _age: float = 0.0
var _hit_ids: Dictionary = {}

func setup(pos: Vector2, vel: Vector2) -> void:
	global_position = pos
	velocity = vel
	_floor_y = pos.y
	z_index = 57
	z_as_relative = false

func _process(delta: float) -> void:
	_age += delta
	if _age >= MAX_LIFETIME:
		queue_free()
		return
	velocity.y += GRAVITY * delta
	global_position += velocity * delta
	if global_position.y >= _floor_y and velocity.y > 0.0:
		global_position.y = _floor_y
		if bounces_left <= 0:
			queue_free()
			return
		bounces_left -= 1
		velocity.y = -velocity.y * 0.55
		velocity.x *= 0.8
	_hit_nearby()
	queue_redraw()

func _hit_nearby() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for enemy in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.get("current_behavior") == "dead":
			continue
		var eid: int = enemy.get_instance_id()
		if _hit_ids.has(eid):
			continue
		if global_position.distance_to(enemy.global_position) > HIT_RADIUS:
			continue
		_hit_ids[eid] = true
		if enemy.has_method("take_damage"):
			enemy.take_damage(HIT_DAMAGE, 0.0, 0.0, true)
		if enemy.has_method("add_burn_stack"):
			enemy.add_burn_stack()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 7.0, Color(1.0, 0.5, 0.1, 0.9))
	draw_circle(Vector2.ZERO, 3.5, Color(1.0, 0.9, 0.5, 0.95))
