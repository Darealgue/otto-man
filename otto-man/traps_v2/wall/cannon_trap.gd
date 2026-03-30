extends BaseTrapV2
class_name CannonTrapV2

## Timer-based cannon trap. Fires cannonballs at longer intervals.
## Direction from surface_type (same logic as ArrowShooterV2).
## 1 tile size (32x32), placed on wall tiles.

const DEBUG_TRAP: bool = false
const CANNONBALL_SCENE_PATH := "res://traps_v2/wall/cannonball_projectile.tscn"

@export var fire_interval: float = 5.0
@export var ball_speed: float = 300.0
@export var explosion_radius: float = 48.0

var _shoot_direction: Vector2 = Vector2.RIGHT

@onready var sprite_left: AnimatedSprite2D = get_node_or_null("left")
@onready var sprite_right: AnimatedSprite2D = get_node_or_null("right")
@onready var fire_timer: Timer = $FireTimer
@onready var muzzle: Marker2D = $Muzzle

var _active_sprite: AnimatedSprite2D = null
var _ball_spawned_this_fire: bool = false

func _ready() -> void:
	fire_timer.wait_time = fire_interval
	fire_timer.timeout.connect(_fire)

func _on_initialized() -> void:
	match surface_type:
		TrapConfigV2.SurfaceType.LEFT_WALL:
			_shoot_direction = Vector2.RIGHT
		TrapConfigV2.SurfaceType.RIGHT_WALL:
			_shoot_direction = Vector2.LEFT
		_:
			_shoot_direction = Vector2.RIGHT

	if surface_type == TrapConfigV2.SurfaceType.LEFT_WALL and sprite_left:
		_active_sprite = sprite_left
		if sprite_right:
			sprite_right.visible = false
		sprite_left.visible = true
	elif surface_type == TrapConfigV2.SurfaceType.RIGHT_WALL and sprite_right:
		_active_sprite = sprite_right
		if sprite_left:
			sprite_left.visible = false
		sprite_right.visible = true
	else:
		_active_sprite = sprite_left if sprite_left else sprite_right
		if sprite_left:
			sprite_left.visible = (_active_sprite == sprite_left)
		if sprite_right:
			sprite_right.visible = (_active_sprite == sprite_right)

	if muzzle:
		muzzle.position = Vector2(16.0 * _shoot_direction.x, 0)
	if fire_timer:
		fire_timer.wait_time = fire_interval
		fire_timer.start()

	if _active_sprite and _active_sprite.sprite_frames and _active_sprite.sprite_frames.has_animation("idle"):
		_active_sprite.play("idle")
	
	if DEBUG_TRAP:
		print("[CannonTrapV2] Direction set: %s (surface: %s)" % [_shoot_direction, TrapConfigV2.SurfaceType.keys()[surface_type]])

func _fire() -> void:
	if is_sleeping:
		return
	_ball_spawned_this_fire = false
	if _active_sprite and _active_sprite.sprite_frames and _active_sprite.sprite_frames.has_animation("fire"):
		if not _active_sprite.frame_changed.is_connected(_on_fire_frame_changed):
			_active_sprite.frame_changed.connect(_on_fire_frame_changed)
		if not _active_sprite.animation_finished.is_connected(_on_fire_animation_finished):
			_active_sprite.animation_finished.connect(_on_fire_animation_finished)
		_active_sprite.play("fire")
	else:
		_spawn_ball()
		if _active_sprite and _active_sprite.sprite_frames and _active_sprite.sprite_frames.has_animation("idle"):
			_active_sprite.play("idle")

func _on_fire_frame_changed() -> void:
	if not _active_sprite or _ball_spawned_this_fire:
		return
	if _active_sprite.animation == "fire" and _active_sprite.frame == 1:
		_ball_spawned_this_fire = true
		_spawn_ball()

func _on_fire_animation_finished() -> void:
	if not _active_sprite:
		return
	_active_sprite.animation_finished.disconnect(_on_fire_animation_finished)
	if _active_sprite.frame_changed.is_connected(_on_fire_frame_changed):
		_active_sprite.frame_changed.disconnect(_on_fire_frame_changed)
	if not _ball_spawned_this_fire:
		_spawn_ball()
	if _active_sprite.sprite_frames and _active_sprite.sprite_frames.has_animation("idle"):
		_active_sprite.play("idle")

func _spawn_ball() -> void:
	var scene := load(CANNONBALL_SCENE_PATH) as PackedScene
	if not scene:
		return
	var ball := scene.instantiate() as CannonballProjectileV2
	ball.velocity = _shoot_direction * ball_speed
	ball.damage = _damage
	ball.explosion_radius = explosion_radius
	ball.global_position = muzzle.global_position if muzzle else global_position
	get_tree().current_scene.add_child(ball)

func _on_sleep() -> void:
	super._on_sleep()
	if fire_timer:
		fire_timer.stop()

func _on_wake() -> void:
	super._on_wake()
	if fire_timer and _initialized:
		fire_timer.start()
