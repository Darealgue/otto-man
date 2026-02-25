# fireball_projectile.gd - Lav Çekici: yön vektörüyle fırlayan alev topu (yatay / yukarı / aşağı heavy), düşmana çarparsa burn stack
extends Node2D

const SPEED := 380.0
const MAX_DISTANCE := 400.0
const HIT_RADIUS := 56.0  # Büyük düşmanlar (Heavy, Summoner) için yeterli; light projectile ile aynı
const BALL_RADIUS := 12.0
const FIRE_COLOR := Color(1.0, 0.5, 0.1)

var _direction: Vector2 = Vector2.RIGHT
var _traveled: float = 0.0

func setup(origin: Vector2, direction: Vector2) -> void:
	global_position = origin
	_direction = direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
	rotation = _direction.angle()

func _physics_process(delta: float) -> void:
	var move := _direction * SPEED * delta
	_traveled += move.length()
	if _traveled >= MAX_DISTANCE:
		queue_free()
		return
	global_position += move
	var world_pos := global_position
	# Duvar/zemin: çarparsa yok ol
	var space = get_world_2d().direct_space_state
	var params = PhysicsPointQueryParameters2D.new()
	params.position = world_pos
	params.collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM
	params.collide_with_bodies = true
	params.collide_with_areas = false
	if space.intersect_point(params).size() > 0:
		queue_free()
		return
	# Düşmana değerse burn stack ekle ve yok ol (hurtbox merkezine göre; büyük düşmanlar için)
	var tree = get_tree()
	if not tree:
		return
	var enemies = tree.get_nodes_in_group("enemies")
	for node in enemies:
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		var check_pos: Vector2 = node.global_position
		if "hurtbox" in node and node.hurtbox and is_instance_valid(node.hurtbox):
			check_pos = node.hurtbox.global_position
		if world_pos.distance_to(check_pos) <= HIT_RADIUS:
			if node.has_method("add_burn_stack"):
				node.add_burn_stack()
			queue_free()
			return
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, BALL_RADIUS, FIRE_COLOR)
