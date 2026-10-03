extends Area2D
class_name PoisonDropProjectileV2

## A poison drop that falls straight down from a ceiling trap.
## Applies poison status effect on player hit, destroyed on any collision.

var fall_speed: float = 480.0
var poison_ticks: int = 5
var poison_damage_per_tick: float = 2.0
var _hit: bool = false

## Zehir zindanı: damla yere düşünce kaç tane sıçrayan zehir topuna bölünür (0 = eski davranış).
var splash_balls: int = 0

# --- Sıçrayan top modu (damla yere çarpınca doğan parçalar) ---
const BALL_GRAVITY := 900.0
const BALL_BOUNCE_RESTITUTION := 0.62
const BALL_WALL_RESTITUTION := 0.7
const BALL_FRICTION := 0.85
const BALL_MAX_LIFETIME := 4.0
const BALL_WORLD_MASK := 1
const BALL_RADIUS := 5.0
var ball_mode: bool = false
var ball_velocity: Vector2 = Vector2.ZERO
var ball_bounces_left: int = 3
var _ball_age: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _draw() -> void:
	if not ball_mode:
		return
	# Sıçrayan zehir topu: damla sprite'ı yerine düz yeşil top (koyu gövde + parlak yansıma)
	draw_circle(Vector2.ZERO, BALL_RADIUS + 1.5, Color(0.08, 0.3, 0.08, 0.9))
	draw_circle(Vector2.ZERO, BALL_RADIUS, Color(0.3, 0.85, 0.25))
	draw_circle(Vector2(-2.0, -2.5), BALL_RADIUS * 0.4, Color(0.75, 1.0, 0.65))


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("trap_projectile")
	if ball_mode:
		if sprite:
			sprite.visible = false
		queue_redraw()
		return
	if sprite and sprite.sprite_frames:
		# Play default loop animation for the drop
		if sprite.sprite_frames.has_animation("default"):
			sprite.play("default")
		else:
			sprite.play()
	else:
		_create_drop_placeholder()

func _create_drop_placeholder() -> void:
	var rect := ColorRect.new()
	rect.color = Color(0.2, 0.9, 0.2)
	rect.size = Vector2(6, 8)
	rect.position = Vector2(-3, -4)
	add_child(rect)

func _physics_process(delta: float) -> void:
	if _hit:
		return
	if ball_mode:
		_ball_step(delta)
		return
	position.y += fall_speed * delta


## Sıçrayan zehir topu: kendi basit fiziği (yerçekimi + ışın testiyle zemin/duvar sekmesi).
## Alan2D'nin temas sinyali yüzey normali vermediği için dünya çarpışması ışınla bulunur.
func _ball_step(delta: float) -> void:
	_ball_age += delta
	if _ball_age >= BALL_MAX_LIFETIME:
		queue_free()
		return
	ball_velocity.y += BALL_GRAVITY * delta
	var space := get_world_2d().direct_space_state

	# Yatay: duvara çarparsa yön değiştirir
	var dx: float = ball_velocity.x * delta
	if absf(dx) > 0.0:
		var qx := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(dx + signf(dx) * 4.0, 0.0), BALL_WORLD_MASK)
		if space.intersect_ray(qx).is_empty():
			global_position.x += dx
		else:
			ball_velocity.x = -ball_velocity.x * BALL_WALL_RESTITUTION

	# Dikey: yere inince sek, tavana çarparsa geri dön
	var dy: float = ball_velocity.y * delta
	var qy := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0.0, dy + signf(dy) * 4.0), BALL_WORLD_MASK)
	var hit := space.intersect_ray(qy)
	if hit.is_empty():
		global_position.y += dy
		return
	if ball_velocity.y > 0.0:
		global_position.y = (hit.position as Vector2).y - 1.0
		ball_velocity.y = -ball_velocity.y * BALL_BOUNCE_RESTITUTION
		ball_velocity.x *= BALL_FRICTION
		ball_bounces_left -= 1
		if ball_bounces_left <= 0:
			# Havuz bırakmaz: zehirli alan yalnızca damlanın düştüğü yerde kalır
			_hit = true
			queue_free()
	else:
		ball_velocity.y = absf(ball_velocity.y) * 0.3


## Yere çarpan damlanın yerine sağa-sola sıçrayan zehir topları bırakır.
func _spawn_splash_balls() -> void:
	var scene := load(scene_file_path) as PackedScene
	if not scene:
		return
	var holder: Node = get_tree().current_scene
	for i in range(splash_balls):
		var ball := scene.instantiate() as PoisonDropProjectileV2
		ball.ball_mode = true
		ball.poison_ticks = poison_ticks
		ball.poison_damage_per_tick = poison_damage_per_tick
		var dir: float = -1.0 if i % 2 == 0 else 1.0
		# Sıçrama çeşitliliği: her top biraz farklı hız/yükseklikle
		ball.ball_velocity = Vector2(dir * randf_range(110.0, 210.0), randf_range(-330.0, -230.0))
		ball.ball_bounces_left = randi_range(2, 4)
		holder.add_child(ball)
		ball.global_position = global_position + Vector2(0.0, -8.0)

func _spawn_pool() -> void:
	var scene_path := "res://traps_v2/ceiling/poison_pool.tscn"
	if not ResourceLoader.exists(scene_path):
		return
	# If there is already a pool very close to this position, just retrigger its impact
	for pool in get_tree().get_nodes_in_group("poison_pools"):
		if not is_instance_valid(pool):
			continue
		if pool.global_position.distance_to(global_position) <= 8.0:
			if pool.has_method("trigger_impact"):
				pool.trigger_impact()
			return
	var scene := load(scene_path) as PackedScene
	if not scene:
		return
	var pool := scene.instantiate()
	if pool:
		get_tree().current_scene.add_child(pool)
		pool.global_position = global_position

func _on_body_entered(body: Node2D) -> void:
	if _hit:
		return
	# Sıçrayan top zemini/duvarı kendi ışınlarıyla yönetir; yalnızca oyuncuya temas eder
	if ball_mode and not body.is_in_group("player"):
		return
	_hit = true
	var is_player := body.is_in_group("player")
	if is_player:
		# Respect dodge / invincibility for poison status as well
		if not body.is_dodging and (not (body.invincibility_timer > 0.0)):
			var sem: StatusEffectManager = body.get("status_effects") as StatusEffectManager
			if sem:
				sem.apply_poison(poison_ticks, poison_damage_per_tick)
	else:
		# Only create pool when drop hits the ground / environment, not when it hits the player mid-air
		_spawn_pool()
		if splash_balls > 0:
			_spawn_splash_balls.call_deferred()  # fizik sinyali içinde Area2D eklemeyelim
	# Tuzak Fısıldayan: düşerken/düşünce yakınındaki düşmanlar da zehirlenir
	if TrapEnemyDamage.is_active():
		TrapEnemyDamage.damage_enemies_in_radius(get_tree(), global_position, 20.0, 0.0, "poison")
	queue_free()
