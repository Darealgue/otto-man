extends BaseTrapV2
class_name ArrowShooterV2

## Timer-based arrow shooter. Fires arrows at regular intervals.
## Direction is auto-determined from surface_type:
##   left_wall  → shoots RIGHT
##   right_wall → shoots LEFT
## 1 tile size (32x32), placed on wall tiles.

const DEBUG_TRAP: bool = false

const ARROW_SCENE_PATH := "res://traps_v2/wall/arrow_projectile.tscn"

@export var fire_interval: float = 2.5
@export var arrow_speed: float = 400.0
@export var arrow_max_distance: float = 600.0

var _shoot_direction: Vector2 = Vector2.RIGHT

@onready var sprite_default: AnimatedSprite2D = $AnimatedSprite2D
@onready var sprite_left: AnimatedSprite2D = get_node_or_null("left")
@onready var sprite_right: AnimatedSprite2D = get_node_or_null("right")
@onready var fire_timer: Timer = $FireTimer
@onready var muzzle: Marker2D = $Muzzle

var _active_sprite: AnimatedSprite2D = null
var _fire_anim_name: String = ""
var _fire_last_frame_index: int = -1
var _arrow_fired: bool = false

func _ready() -> void:
	fire_timer.wait_time = fire_interval
	fire_timer.timeout.connect(_fire)
	# No placeholder for arrow trap — use left/right sprites only

func _on_initialized() -> void:
	# Direction: left wall trap shoots right (into room), right wall trap shoots left (into room).
	match surface_type:
		TrapConfigV2.SurfaceType.LEFT_WALL:
			_shoot_direction = Vector2.RIGHT
		TrapConfigV2.SurfaceType.RIGHT_WALL:
			_shoot_direction = Vector2.LEFT
		_:
			_shoot_direction = Vector2.RIGHT

	# Choose which sprite to use based on wall side
	# LEFT_WALL  -> use 'left' sprite; RIGHT_WALL -> use 'right' sprite
	if surface_type == TrapConfigV2.SurfaceType.LEFT_WALL and sprite_left:
		_active_sprite = sprite_left
		if sprite_right:
			sprite_right.visible = false
		if sprite_default and sprite_default != _active_sprite:
			sprite_default.visible = false
		_active_sprite.visible = true
	elif surface_type == TrapConfigV2.SurfaceType.RIGHT_WALL and sprite_right:
		_active_sprite = sprite_right
		if sprite_left:
			sprite_left.visible = false
		if sprite_default and sprite_default != _active_sprite:
			sprite_default.visible = false
		_active_sprite.visible = true
	else:
		# Fallback: use default sprite and flip it
		_active_sprite = sprite_default
		if sprite_left:
			sprite_left.visible = false
		if sprite_right:
			sprite_right.visible = false
		if _active_sprite:
			_active_sprite.visible = true
			_active_sprite.flip_h = (_shoot_direction == Vector2.LEFT)
	if muzzle:
		muzzle.position = Vector2(16.0 * _shoot_direction.x, 0)
	if fire_timer:
		fire_timer.wait_time = fire_interval
		fire_timer.start()
	# Start with idle animation
	if _active_sprite and _active_sprite.sprite_frames:
		if _active_sprite == sprite_left and _active_sprite.sprite_frames.has_animation("idle_left"):
			_active_sprite.play("idle_left")
		elif _active_sprite == sprite_right and _active_sprite.sprite_frames.has_animation("idle_right"):
			_active_sprite.play("idle_right")
		elif _active_sprite.sprite_frames.has_animation("idle"):
			_active_sprite.play("idle")
	
	if DEBUG_TRAP:
		print("[ArrowShooterV2] Direction set: %s (surface: %s)" % [_shoot_direction, TrapConfigV2.SurfaceType.keys()[surface_type]])

func _fire() -> void:
	if is_sleeping:
		return
	# Only start fire animation; arrow spawns one frame BEFORE the last fire frame
	if _active_sprite and _active_sprite.sprite_frames:
		_arrow_fired = false
		_fire_anim_name = ""
		_fire_last_frame_index = -1
		if _active_sprite.animation_finished.is_connected(_on_reload_animation_finished):
			_active_sprite.animation_finished.disconnect(_on_reload_animation_finished)
		if not _active_sprite.animation_finished.is_connected(_on_fire_animation_finished):
			_active_sprite.animation_finished.connect(_on_fire_animation_finished)
		if not _active_sprite.frame_changed.is_connected(_on_fire_frame_changed):
			_active_sprite.frame_changed.connect(_on_fire_frame_changed)
		if _active_sprite == sprite_left and _active_sprite.sprite_frames.has_animation("fire_left"):
			_fire_anim_name = "fire_left"
			_active_sprite.play(_fire_anim_name)
		elif _active_sprite == sprite_right and _active_sprite.sprite_frames.has_animation("fire_right"):
			_fire_anim_name = "fire_right"
			_active_sprite.play(_fire_anim_name)
		elif _active_sprite.sprite_frames.has_animation("fire"):
			_fire_anim_name = "fire"
			_active_sprite.play(_fire_anim_name)

		if _fire_anim_name != "":
			var count := _active_sprite.sprite_frames.get_frame_count(_fire_anim_name)
			_fire_last_frame_index = count - 1 if count > 0 else -1

func _spawn_arrow() -> void:
	var scene := load(ARROW_SCENE_PATH) as PackedScene
	if not scene:
		return
	var arrow := scene.instantiate() as ArrowProjectileV2
	arrow.velocity = _shoot_direction * arrow_speed
	arrow.damage = _damage
	arrow.max_distance = arrow_max_distance
	arrow.global_position = muzzle.global_position if muzzle else global_position
	get_tree().current_scene.add_child(arrow)

func _on_fire_frame_changed() -> void:
	if not _active_sprite or _fire_anim_name == "" or _fire_last_frame_index <= 0:
		return
	if _arrow_fired:
		return
	# Spawn arrow ONE FRAME BEFORE the last fire frame
	if _active_sprite.animation == _fire_anim_name and _active_sprite.frame == _fire_last_frame_index - 1:
		_arrow_fired = true
		_spawn_arrow()

func _on_fire_animation_finished() -> void:
	if not _active_sprite or not _active_sprite.sprite_frames:
		return
	_active_sprite.animation_finished.disconnect(_on_fire_animation_finished)
	if _active_sprite.frame_changed.is_connected(_on_fire_frame_changed):
		_active_sprite.frame_changed.disconnect(_on_fire_frame_changed)
	if not _arrow_fired:
		_spawn_arrow()
	# Play reload to the end, then idle
	if _active_sprite == sprite_left and _active_sprite.sprite_frames.has_animation("reload_left"):
		_active_sprite.play("reload_left")
		_active_sprite.animation_finished.connect(_on_reload_animation_finished)
	elif _active_sprite == sprite_right and _active_sprite.sprite_frames.has_animation("reload_right"):
		_active_sprite.play("reload_right")
		_active_sprite.animation_finished.connect(_on_reload_animation_finished)
	else:
		# No reload anim, go straight to idle
		_play_idle()

func _on_reload_animation_finished() -> void:
	if not _active_sprite or not _active_sprite.sprite_frames:
		return
	_active_sprite.animation_finished.disconnect(_on_reload_animation_finished)
	_play_idle()

func _play_idle() -> void:
	if not _active_sprite or not _active_sprite.sprite_frames:
		return
	if _active_sprite == sprite_left and _active_sprite.sprite_frames.has_animation("idle_left"):
		_active_sprite.play("idle_left")
	elif _active_sprite == sprite_right and _active_sprite.sprite_frames.has_animation("idle_right"):
		_active_sprite.play("idle_right")
	elif _active_sprite.sprite_frames.has_animation("idle"):
		_active_sprite.play("idle")

func _on_sleep() -> void:
	super._on_sleep()
	if fire_timer:
		fire_timer.stop()

func _on_wake() -> void:
	super._on_wake()
	if fire_timer and _initialized:
		fire_timer.start()
