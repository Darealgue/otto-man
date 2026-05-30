extends CharacterBody2D

@export var projectile_damage: float = 14.0
@export var projectile_speed: float = 320.0
@export var lifetime: float = 14.0
@export var body_radius: float = 14.0
@export var max_bounces: int = 3

var velocity_vec: Vector2 = Vector2.ZERO

var _hitbox: Area2D
var _bounce_count: int = 0
var _tile_layers: Array[TileMapLayer] = []


func _ready() -> void:
	collision_layer = CollisionLayers.NONE
	collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM
	motion_mode = MOTION_MODE_FLOATING
	add_to_group("boss_projectile")
	_build_body_collision()
	_build_visual()
	_build_hitbox()
	call_deferred("_cache_tile_layers")
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)


func setup(direction: Vector2, speed: float, _bounds: Rect2, damage: float = -1.0, bounces: int = -1) -> void:
	velocity_vec = direction.normalized() * speed
	projectile_speed = speed
	if damage >= 0.0:
		projectile_damage = damage
	if bounces >= 0:
		max_bounces = bounces
	_bounce_count = 0
	if is_instance_valid(_hitbox):
		_hitbox.damage = projectile_damage


func _cache_tile_layers() -> void:
	_tile_layers.clear()
	var scene_root := get_tree().current_scene
	if scene_root:
		_collect_physics_tile_layers(scene_root)


func _collect_physics_tile_layers(node: Node) -> void:
	if node is TileMapLayer:
		var layer := node as TileMapLayer
		if layer.tile_set != null and layer.tile_set.get_physics_layers_count() > 0:
			_tile_layers.append(layer)
	for child in node.get_children():
		_collect_physics_tile_layers(child)


func _build_body_collision() -> void:
	var shape_node := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = body_radius
	shape_node.shape = circle
	add_child(shape_node)


func _build_visual() -> void:
	var body := Polygon2D.new()
	body.name = "Body"
	body.color = Color(0.35, 0.75, 1.0, 0.95)
	body.polygon = _make_circle_points(body_radius, 16)
	add_child(body)

	var core := Polygon2D.new()
	core.name = "Core"
	core.color = Color(0.85, 0.95, 1.0, 1.0)
	core.polygon = _make_circle_points(body_radius * 0.45, 10)
	add_child(core)


func _build_hitbox() -> void:
	var hitbox_script: Script = load("res://components/enemy_hitbox.gd") as Script
	_hitbox = Area2D.new()
	_hitbox.set_script(hitbox_script)
	_hitbox.name = "Hitbox"
	_hitbox.damage = projectile_damage
	_hitbox.knockback_force = 220.0
	_hitbox.knockback_up_force = 80.0
	add_child(_hitbox)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = body_radius + 2.0
	shape.shape = circle
	_hitbox.add_child(shape)

	_hitbox.setup_attack("boss_orb", false, 0.0)
	_hitbox.enable()


func _physics_process(delta: float) -> void:
	if _tile_layers.is_empty():
		_cache_tile_layers()

	var speed := velocity_vec.length()
	if speed < 1.0:
		return

	var motion: Vector2 = velocity_vec * delta
	var from_pos: Vector2 = global_position
	var collision := move_and_collide(motion)
	if collision == null:
		return

	if _is_one_way_collision(collision):
		global_position = from_pos + motion
		return

	var normal: Vector2 = collision.get_normal().normalized()
	velocity_vec = velocity_vec.bounce(normal).normalized() * speed
	_bounce_count += 1
	if _bounce_count >= max_bounces:
		queue_free()


func _is_one_way_collision(collision: KinematicCollision2D) -> bool:
	var collider: Object = collision.get_collider()
	if collider == null:
		return false

	if collider is Node:
		var node := collider as Node
		if node.is_in_group("one_way_platforms"):
			return true
		if node.get_class() == "OneWayPlatform":
			return true

	var hit_pos: Vector2 = collision.get_position()
	if collider is TileMapLayer:
		return _is_one_way_tile_at(collider as TileMapLayer, hit_pos, collision.get_normal())
	if collider is TileMap:
		return _is_one_way_tile_at_legacy(collider as TileMap, hit_pos)

	if collider is CollisionObject2D:
		for child in (collider as CollisionObject2D).get_children():
			if child is CollisionShape2D and child.one_way_collision:
				return true

	for layer in _tile_layers:
		if _is_one_way_tile_at(layer, hit_pos, collision.get_normal()):
			return true
	return false


func _is_one_way_tile_at(tilemap: TileMapLayer, world_pos: Vector2, surface_normal: Vector2 = Vector2.ZERO) -> bool:
	var local_pos: Vector2 = tilemap.to_local(world_pos)
	var center_cell: Vector2i = tilemap.local_to_map(local_pos)
	if _cell_is_one_way(tilemap, center_cell):
		return true

	# Yalnızca platform üst/alt yüzeyine yakın çarpışmalarda komşu hücreye bak.
	if absf(surface_normal.y) > 0.35:
		var vertical_cell: Vector2i = center_cell
		if surface_normal.y < 0.0:
			vertical_cell.y -= 1
		else:
			vertical_cell.y += 1
		if _cell_is_one_way(tilemap, vertical_cell):
			return true
	return false


func _is_one_way_tile_at_legacy(tilemap: TileMap, world_pos: Vector2) -> bool:
	var cell: Vector2i = tilemap.local_to_map(tilemap.to_local(world_pos))
	var tile_data: TileData = tilemap.get_cell_tile_data(0, cell)
	return _tile_data_is_one_way(tile_data)


func _cell_is_one_way(tilemap: TileMapLayer, cell: Vector2i) -> bool:
	if tilemap.get_cell_source_id(cell) == -1:
		return false
	return _tile_data_is_one_way(tilemap.get_cell_tile_data(cell))


func _tile_data_is_one_way(tile_data: TileData) -> bool:
	if tile_data == null:
		return false
	if tile_data.terrain == 1:
		return true
	var poly_count: int = tile_data.get_collision_polygons_count(0)
	for poly_idx in range(poly_count):
		if tile_data.is_collision_polygon_one_way(0, poly_idx):
			return true
	return false


static func _make_circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
