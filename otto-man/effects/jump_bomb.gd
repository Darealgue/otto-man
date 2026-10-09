# jump_bomb.gd - Barut Sıçrayışı: hava zıplamasında bırakılan, yer çekiminden etkilenen bomba.
# Düşer; zemine/platforma ya da bir düşmana değince patlar, değmezse 2 sn fünyeyle patlar. Patlama yakındaki
# düşmanlara hasar verir ve onları havaya fırlatır (hava kombolarına köprü). Oyuncuya zarar vermez.
# Placeholder görsel: koyu top + yanan fitil. Fitil Hattı komşu patlamada bunu hemen patlatabilir (barut_fuse).
extends Node2D

const _AoeBurstRingScript = preload("res://effects/aoe_burst_ring.gd")
const GRAVITY := 980.0
const FUSE_TIME := 2.0
const TRIGGER_RADIUS := 34.0
const BLAST_RADIUS := 90.0
const BLAST_DAMAGE := 10.0
const LAUNCH_UP_FORCE := 220.0
const KNOCKBACK := 60.0
const BALL_RADIUS := 11.0
const RING_COLOR := Color(1.0, 0.6, 0.2, 0.85)

var velocity: Vector2 = Vector2.ZERO

var _fuse: float = FUSE_TIME
var _exploded: bool = false

func setup(pos: Vector2, initial_velocity: Vector2 = Vector2.ZERO) -> void:
	global_position = pos
	velocity = initial_velocity
	z_index = 57
	z_as_relative = false

func _ready() -> void:
	add_to_group("barut_fuse")

## Fitil Hattı çağırır: fünyeyi beklemeden hemen patlar.
func detonate_now() -> void:
	_explode()

func _physics_process(delta: float) -> void:
	if _exploded:
		return
	_fuse -= delta
	if _fuse <= 0.0:
		_explode()
		return
	velocity.y += GRAVITY * delta
	var next_pos: Vector2 = global_position + velocity * delta
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, next_pos)
	# Tek yönlü platformlar sadece düşerken zemin sayılır
	query.collision_mask = CollisionLayers.WORLD | (CollisionLayers.PLATFORM if velocity.y > 0.0 else 0)
	var hit := space.intersect_ray(query)
	if hit.size() > 0:
		global_position = hit.position + Vector2(0.0, -2.0)
		_explode()
		return
	global_position = next_pos
	if _enemy_in_trigger_range():
		_explode()
		return
	queue_redraw()

func _enemy_in_trigger_range() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		if global_position.distance_to(node.global_position) <= TRIGGER_RADIUS:
			return true
	return false

func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	var tree := get_tree()
	if tree == null:
		queue_free()
		return
	var radius: float = BLAST_RADIUS * ExplosionModifiers.radius_mult()
	var dmg: float = BLAST_DAMAGE * ExplosionModifiers.damage_mult()
	var im := get_node_or_null("/root/ItemManager")
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead" or not node.has_method("take_damage"):
			continue
		if global_position.distance_to(node.global_position) <= radius:
			# Tüm düşman tiplerini gerçekten havaya kaldırır (bkz. ItemManager.launch_enemy)
			if im:
				im.launch_enemy(node, dmg, KNOCKBACK, LAUNCH_UP_FORCE)
			else:
				node.take_damage(dmg, KNOCKBACK, LAUNCH_UP_FORCE, true)
	if tree.current_scene:
		var ring := Node2D.new()
		ring.set_script(_AoeBurstRingScript)
		tree.current_scene.add_child(ring)
		ring.setup(global_position, radius, RING_COLOR)
	ExplosionModifiers.announce(global_position, radius)
	queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, BALL_RADIUS, Color(0.12, 0.1, 0.1))
	draw_arc(Vector2.ZERO, BALL_RADIUS, 0.0, TAU, 20, Color(0.35, 0.3, 0.3), 2.0)
	# Fitil yandıkça sıkılaşan kıvılcım
	var t: float = clampf(1.0 - _fuse / FUSE_TIME, 0.0, 1.0)
	draw_circle(Vector2(5.0, -BALL_RADIUS - 2.0), 3.0 + 3.0 * t, Color(1.0, 0.55 + 0.3 * t, 0.15))
