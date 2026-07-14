# Uzun Menzil itemi: light attack ile fırlayan projectile (yatay / 45° yukarı / 45° aşağı)
# Ok Yağmuru (ağır saldırı) da bu sahneyi kullanır.
# Opsiyonel özellikler (item'lar setup() sonrası set eder):
#   bounce_remaining  - Yansıyan Ok: ilk çarpışta bounce_range içindeki 2. düşmana sekme
#   element           - Rüzgârın Nişanı: "poison"/"fire"/"frost" ise çarpışta ilgili stack uygulanır
#   echo              - Yankı Oku: çarpışma noktasında 1sn sonra %60 hasarlık ikinci patlama
#   unlimited_range / crit_range / crit_mult - Kartal Bakışı: menzil sınırı kalkar, uzak mesafe kritik
extends Node2D

const SPEED := 1100.0
const MAX_DISTANCE := 250.0  # Yarı mesafe (önceki 500)
const HIT_RADIUS := 56.0
const BALL_RADIUS := 10.0
const PROJECTILE_COLOR := Color(0.9, 0.85, 0.5)
const BOUNCE_RANGE := 140.0
const ECHO_DELAY := 1.0
const ECHO_DAMAGE_RATIO := 0.6
const ECHO_RADIUS := 60.0

var _direction: Vector2 = Vector2.RIGHT
var _traveled: float = 0.0
var _damage: float = 15.0

# Uzun Menzil/Ok Yağmuru'nun kendi çağrılarını bozmamak için varsayılan -1 (item set etmezse kapalı)
var max_distance: float = MAX_DISTANCE
var bounce_remaining: int = 0
var element: String = ""
var echo: bool = false
var unlimited_range: bool = false
var crit_range: float = 300.0
var crit_mult: float = 1.75

func setup(origin: Vector2, direction: Vector2, damage: float) -> void:
	global_position = origin
	_direction = direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
	rotation = _direction.angle()  # Çıkış açısına uygun ilerle (hitbox doğrultusu)
	_damage = max(1.0, damage)

func _physics_process(delta: float) -> void:
	var move := _direction * SPEED * delta
	_traveled += move.length()
	if not unlimited_range and _traveled >= max_distance:
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
			_on_hit(node, world_pos)
			return
	queue_redraw()

func _on_hit(node: Node, world_pos: Vector2) -> void:
	if node.has_method("take_damage"):
		var dmg := _damage
		if unlimited_range and _traveled > crit_range:
			dmg *= crit_mult
		# Sadece hasar; knockback ve hurt animasyonu yok (apply_knockback = false)
		node.take_damage(dmg, 0.0, 0.0, false)
	_apply_element(node)
	if echo:
		_spawn_echo(world_pos)
	if bounce_remaining > 0:
		var next_target := _find_bounce_target(node, world_pos)
		if next_target:
			bounce_remaining -= 1
			_traveled = 0.0
			_direction = (next_target.global_position - world_pos).normalized()
			rotation = _direction.angle()
			return
	queue_free()

func _apply_element(node: Node) -> void:
	if element == "" or not is_instance_valid(node):
		return
	match element:
		"poison":
			if node.has_method("add_poison_stack"):
				node.add_poison_stack(5, 1.0, 2.0)
		"fire":
			if node.has_method("add_burn_stack"):
				node.add_burn_stack()
		"frost":
			if node.has_method("add_frost_stack"):
				node.add_frost_stack(1)

func _find_bounce_target(exclude: Node, from_pos: Vector2) -> Node:
	var tree = get_tree()
	if not tree:
		return null
	var best: Node = null
	var best_dist := BOUNCE_RANGE
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node == exclude:
			continue
		if node.get("current_behavior") == "dead":
			continue
		var d := from_pos.distance_to(node.global_position)
		if d <= best_dist:
			best_dist = d
			best = node
	return best

func _spawn_echo(world_pos: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if not tree or not tree.current_scene:
		return
	var timer := get_tree().create_timer(ECHO_DELAY)
	var echo_damage := _damage * ECHO_DAMAGE_RATIO
	var scene_root: Node = tree.current_scene
	timer.timeout.connect(func():
		if not is_instance_valid(scene_root):
			return
		for node in scene_root.get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(node) or node.get("current_behavior") == "dead":
				continue
			if world_pos.distance_to(node.global_position) <= ECHO_RADIUS:
				if node.has_method("take_damage"):
					node.take_damage(echo_damage, 0.0, 0.0, false)
	)

func _draw() -> void:
	draw_circle(Vector2.ZERO, BALL_RADIUS, PROJECTILE_COLOR)
