# Buzlu Kayma: zehir gibi fizik motoruyla düşen buz partikülleri; ayak hizasında spawn, yere değince buz patch'i
extends Node2D

const PARTICLE_COUNT := 3
const GRAVITY := 500.0
const INITIAL_SPEED_DOWN := 40.0
const INITIAL_SPEED_HORIZ := 30.0
const HIT_RADIUS := 14.0
const MAX_LIFETIME := 4.0
const PARTICLE_SIZE := 5
const PARTICLE_COLOR := Color(0.5, 0.8, 1.0)

const ICE_PATCH_SCENE = preload("res://effects/ground_ice_patch.tscn")

var _positions: Array[Vector2] = []
var _velocities: Array[Vector2] = []
var _hit_enemies: Array[Dictionary] = []
var _active: Array[bool] = []
var _slide_direction: float = 1.0
var _age: float = 0.0

func setup(origin: Vector2, slide_dir: float) -> void:
	# get_foot_position zeminin altında kalabildiği için yukarıda spawn ediyoruz; partiküller yere düşsün
	global_position = origin + Vector2(0, -50)
	_slide_direction = sign(slide_dir) if slide_dir != 0.0 else 1.0
	for i in range(PARTICLE_COUNT):
		_positions.append(Vector2.ZERO)
		var vx = randf_range(-INITIAL_SPEED_HORIZ, INITIAL_SPEED_HORIZ) * _slide_direction
		var vy = randf_range(20.0, INITIAL_SPEED_DOWN)
		_velocities.append(Vector2(vx, vy))
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
		# Zemine/duvara değince patch spawn et ve partikülü kapat
		var params = PhysicsPointQueryParameters2D.new()
		params.position = world_pos
		params.collision_mask = wall_platform_mask
		params.collide_with_bodies = true
		params.collide_with_areas = false
		var hits = space.intersect_point(params)
		if hits.size() > 0:
			_active[i] = false
			var patch = ICE_PATCH_SCENE.instantiate()
			tree.current_scene.add_child(patch)
			# Patch'i zeminin üstüne koy (rect 0..24 aşağı gidiyor; -12 ile düşman ayaklarıyla çakışsın)
			patch.global_position = world_pos + Vector2(0, -12)
			continue
		# Havadayken değen düşmana 1 frost
		for enemy in enemies:
			if not is_instance_valid(enemy) or enemy.get("current_behavior") == "dead":
				continue
			var eid = enemy.get_instance_id()
			if _hit_enemies[i].get(eid, false):
				continue
			if world_pos.distance_to(enemy.global_position) <= HIT_RADIUS and enemy.has_method("add_frost_stack"):
				enemy.add_frost_stack(1)
				_hit_enemies[i][eid] = true
	if not any_active or _age >= MAX_LIFETIME:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var r := PARTICLE_SIZE / 2.0
	for i in range(_positions.size()):
		if not _active[i]:
			continue
		draw_circle(_positions[i], r, PARTICLE_COLOR)
