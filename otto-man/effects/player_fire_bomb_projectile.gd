# Ateş Bombası (oyuncu tarafı): Ok Yağmuru'nun ağır mermisi yerine geçen, yerçekimiyle zıplayarak
# ilerleyen bomba. Düşmana değince hemen patlar (alan hasarı + yanma); değmezse zeminde 2-3 kez
# sekebilir, sekmeler bitince ya da 3 sn sonra olduğu yerde patlar. FireBombProjectile (enemy/
# firemage) düşman mermisi olduğu için (oyuncu hurtbox'ını hedefler) doğrudan kullanılamıyor; fiziği
# örnek alındı. Ruh Mermisi/Yansıyan Ok bombayı patladıktan sonra bir sonraki düşmana yönlendirir.
# Peşine Düşen (homing) yerçekimli bomba için anlamsız, uygulanmaz.
extends "res://effects/cannon_projectile.gd"

const GRAVITY := 980.0
const BOUNCE_DAMPING := 0.75
const FUSE_TIME := 3.0
const LOB_KICK := -220.0

var _velocity: Vector2 = Vector2.ZERO
var _bounces_left: int = 2
var _fuse: float = FUSE_TIME
var _exploded: bool = false

func setup(origin: Vector2, direction: Vector2, damage: float) -> void:
	super.setup(origin, direction, damage)
	_speed = 430.0
	_hit_radius = 56.0
	_ball_radius = 13.0
	_ball_color = Color(1.0, 0.45, 0.1)
	splash_radius = 90.0
	splash_ratio = 0.8
	splash_color = Color(1.0, 0.5, 0.15, 0.85)
	splash_burn = true
	cannon_knockback = 200.0
	cannon_knockback_up = 140.0
	_velocity = _direction * _speed + Vector2(0.0, LOB_KICK)
	_bounces_left = randi_range(2, 3)

func _physics_process(delta: float) -> void:
	if _exploded:
		return
	_fuse -= delta
	if _fuse <= 0.0:
		_explode_in_place()
		return
	_velocity.y += GRAVITY * delta
	var next_pos := global_position + _velocity * delta
	var space = get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, next_pos)
	# Tek yönlü platformlar sadece düşerken zemin sayılır (alttan zıplarken içinden geçer)
	query.collision_mask = CollisionLayers.WORLD | (CollisionLayers.PLATFORM if _velocity.y > 0.0 else 0)
	var ray = space.intersect_ray(query)
	if ray.size() > 0:
		var normal: Vector2 = ray.normal
		_velocity = _velocity.bounce(normal) * BOUNCE_DAMPING
		global_position = ray.position + normal * 2.0
		_bounces_left -= 1
		if absf(normal.y) > 0.7 and _velocity.y > -150.0:
			_velocity.y = -150.0
		if _bounces_left < 0:
			_explode_in_place()
			return
	else:
		global_position = next_pos
	if _check_enemy_hits(global_position):
		return
	queue_redraw()

func _on_hit(node: Node, world_pos: Vector2) -> void:
	super._on_hit(node, world_pos)
	# Ruh Mermisi/Yansıyan Ok bombayı kurtardıysa (queue_free edilmedi) yeni hedefe doğru fırlat
	if not is_queued_for_deletion():
		_velocity = _direction * _speed + Vector2(0.0, LOB_KICK * 0.5)
		_fuse = FUSE_TIME

func _explode_in_place() -> void:
	if _exploded:
		return
	_exploded = true
	_splash(null, global_position)
	queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, _ball_radius * 1.5, Color(1.0, 0.5, 0.1, 0.25))
	draw_circle(Vector2.ZERO, _ball_radius, _ball_color)
	draw_circle(Vector2.ZERO, _ball_radius * 0.5, Color(1.0, 0.85, 0.3))
