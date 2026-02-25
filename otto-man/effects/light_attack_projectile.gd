# Uzun Menzil itemi: light attack ile fırlayan projectile (yatay / 45° yukarı / 45° aşağı)
extends Node2D

const SPEED := 1100.0
const MAX_DISTANCE := 250.0  # Yarı mesafe (önceki 500)
const HIT_RADIUS := 56.0
const BALL_RADIUS := 10.0
const PROJECTILE_COLOR := Color(0.9, 0.85, 0.5)

var _direction: Vector2 = Vector2.RIGHT
var _traveled: float = 0.0
var _damage: float = 15.0

func setup(origin: Vector2, direction: Vector2, damage: float) -> void:
	global_position = origin
	_direction = direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
	rotation = _direction.angle()  # Çıkış açısına uygun ilerle (hitbox doğrultusu)
	_damage = max(1.0, damage)

func _physics_process(delta: float) -> void:
	var move := _direction * SPEED * delta
	_traveled += move.length()
	if _traveled >= MAX_DISTANCE:
		queue_free()
		return
	global_position += move
	var world_pos := global_position
	var space = get_world_2d().direct_space_state
	var params = PhysicsPointQueryParameters2D.new()
	params.position = world_pos
	params.collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM
	params.collide_with_bodies = true
	params.collide_with_areas = false
	if space.intersect_point(params).size() > 0:
		queue_free()
		return
	var tree = get_tree()
	if not tree:
		return
	var enemies = tree.get_nodes_in_group("enemies")
	for node in enemies:
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		if world_pos.distance_to(node.global_position) <= HIT_RADIUS:
			if node.has_method("take_damage"):
				# Sadece hasar; knockback ve hurt animasyonu yok (apply_knockback = false)
				node.take_damage(_damage, 0.0, 0.0, false)
			queue_free()
			return
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, BALL_RADIUS, PROJECTILE_COLOR)
