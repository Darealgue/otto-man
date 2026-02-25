# poison_arc.gd - Zehirli Dev: yumruk zehre batmış gibi sıçrayan damlalar; rastgele yay, yere değene kadar düşer
extends Node2D

const DROPLET_COUNT := 4
const SPREAD_ANGLE_FLAT := deg_to_rad(36)  # Düz: dar koni, yatayda kalsın
const SPREAD_ANGLE_UP := deg_to_rad(26)   # Yukarı: dar koni, dik yaylar
const SPREAD_ANGLE_DOWN := deg_to_rad(60)  # Aşağı heavy
const INITIAL_SPEED_MIN := 240.0   # Genel fırlama gücü 2x
const INITIAL_SPEED_MAX := 440.0
const INITIAL_SPEED_UP_MIN := 260.0   # Yukarı: daha yükseğe çıksın
const INITIAL_SPEED_UP_MAX := 400.0
const GRAVITY := 600.0
const HIT_RADIUS := 18.0
const MAX_LIFETIME := 5.0  # Güvenlik: en fazla bu süre sonra silinir; yoksa yere değene kadar kalır
const POISON_MAX_STACKS := 6
const POISON_DAMAGE_PER_STACK := 1.0
const POISON_TICK_INTERVAL := 1.0
const PARTICLE_SIZE := 5
const PARTICLE_COLOR := Color(0.2, 0.95, 0.35)  # Yeşil zehir

var _positions: Array[Vector2] = []
var _velocities: Array[Vector2] = []
var _hit_enemies: Array[Dictionary] = []
var _active: Array[bool] = []
var _direction: float = 1.0
var _age: float = 0.0

func setup(origin: Vector2, facing: float, attack_name: String = "") -> void:
	global_position = origin
	_direction = facing  # 1 = sağ, -1 = sol (hızın x'ini bununla çarpacağız)
	# Düz heavy: yere daha paralel damlalar (ileri-yatay). Yukarı heavy: yukarı fırlayıp yakına yağar.
	var cone_center: float
	var spread: float
	var speed_min: float = INITIAL_SPEED_MIN
	var speed_max: float = INITIAL_SPEED_MAX
	var angle_jitter_max: float = 0.35
	if attack_name == "up_heavy":
		cone_center = -deg_to_rad(78)  # Dik yaylar, düz heavy'den çok daha yükseğe çıkar
		spread = SPREAD_ANGLE_UP
		speed_min = INITIAL_SPEED_UP_MIN
		speed_max = INITIAL_SPEED_UP_MAX
		angle_jitter_max = 0.15
	elif attack_name == "down_heavy":
		cone_center = PI/2
		spread = SPREAD_ANGLE_DOWN
	else:
		cone_center = -deg_to_rad(8)   # Yere neredeyse paralel, ileri sıçrama (düz heavy)
		spread = SPREAD_ANGLE_FLAT
		angle_jitter_max = 0.28
	# Rastgele sıçrama: her damla farklı açı ve hızda
	for i in range(DROPLET_COUNT):
		var t = float(i) / max(1, DROPLET_COUNT - 1)
		var base_angle = cone_center + spread * (t - 0.5)
		var angle_jitter = randf_range(-angle_jitter_max, angle_jitter_max)
		var angle = base_angle + angle_jitter
		var speed = randf_range(speed_min, speed_max)
		var vel = Vector2(cos(angle), sin(angle)) * speed
		vel.x *= _direction
		_positions.append(Vector2.ZERO)
		_velocities.append(vel)
		_hit_enemies.append({})
		_active.append(true)

func _physics_process(delta: float) -> void:
	_age += delta
	var tree = get_tree()
	if not tree:
		return
	var space = get_world_2d().direct_space_state
	var wall_platform_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM
	var enemies = tree.get_nodes_in_group("enemies")
	var any_active = false
	for i in range(_positions.size()):
		if not _active[i]:
			continue
		any_active = true
		_velocities[i].y += GRAVITY * delta
		_positions[i] += _velocities[i] * delta
		var world_pos = global_position + _positions[i]
		# Duvar / zemin / platform: değen partikül durur (yere değene kadar düşer, sonra yok olur)
		var params = PhysicsPointQueryParameters2D.new()
		params.position = world_pos
		params.collision_mask = wall_platform_mask
		params.collide_with_bodies = true
		params.collide_with_areas = false
		var hits = space.intersect_point(params)
		if hits.size() > 0:
			_active[i] = false
			continue
		# Düşmana değerse zehirle (1 partikül = 1 stack)
		for enemy in enemies:
			if not is_instance_valid(enemy):
				continue
			if enemy.get("current_behavior") == "dead":
				continue
			var eid = enemy.get_instance_id()
			if _hit_enemies[i].get(eid, false):
				continue
			if world_pos.distance_to(enemy.global_position) <= HIT_RADIUS and enemy.has_method("add_poison_stack"):
				enemy.add_poison_stack(POISON_MAX_STACKS, POISON_DAMAGE_PER_STACK, POISON_TICK_INTERVAL)
				_hit_enemies[i][eid] = true
	# Hepsi yere/duvara değdi veya max süre dolduysa node'u sil
	if not any_active or _age >= MAX_LIFETIME:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var radius := PARTICLE_SIZE / 2.0  # 5x5 piksel yuvarlak = yarıçap 2.5
	for i in range(_positions.size()):
		if not _active[i]:
			continue
		var p := _positions[i]
		draw_circle(p, radius, PARTICLE_COLOR)
