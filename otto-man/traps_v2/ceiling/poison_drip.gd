extends BaseTrapV2
class_name PoisonDripV2

## Timer-based ceiling trap. Drips poison drops at regular intervals.
## Drops fall straight down, applying poison on player hit.
## 1 tile size (32x32), placed on ceiling tiles.

const DROP_SCENE_PATH := "res://traps_v2/ceiling/poison_drop_projectile.tscn"

@export var drip_interval: float = 2.0
@export var drop_speed: float = 480.0
@export var poison_ticks: int = 5
@export var poison_damage_per_tick: float = 2.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var drip_timer: Timer = $DripTimer
@onready var drip_point: Marker2D = $DripPoint

var _pending_drop: bool = false
var _drip_last_frame_index: int = -1

func _ready() -> void:
	drip_timer.wait_time = drip_interval
	drip_timer.timeout.connect(_drip)
	var has_frames := sprite and sprite.sprite_frames and sprite.sprite_frames.get_frame_count("idle") > 0
	if not has_frames:
		_create_placeholder(Color(0.2, 0.8, 0.2, 0.6), "POISON")
	else:
		# Start in idle and listen for drip animation finish
		if sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")
		if not sprite.animation_finished.is_connected(_on_animation_finished):
			sprite.animation_finished.connect(_on_animation_finished)
		# Cache last frame index of drip animation and listen for frame changes
		if sprite.sprite_frames.has_animation("drip"):
			var count := sprite.sprite_frames.get_frame_count("drip")
			_drip_last_frame_index = count - 1 if count > 0 else -1
			if not sprite.frame_changed.is_connected(_on_frame_changed):
				sprite.frame_changed.connect(_on_frame_changed)

func _on_initialized() -> void:
	poison_damage_per_tick = _damage
	if drip_timer:
		drip_timer.wait_time = drip_interval
		drip_timer.start()

func _drip() -> void:
	if is_sleeping:
		return
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("drip"):
		sprite.play("drip")
	_pending_drop = true

func _spawn_drop() -> void:
	var scene := load(DROP_SCENE_PATH) as PackedScene
	if not scene:
		return
	var drop := scene.instantiate() as PoisonDropProjectileV2
	drop.fall_speed = drop_speed
	drop.poison_ticks = poison_ticks
	drop.poison_damage_per_tick = poison_damage_per_tick
	drop.global_position = drip_point.global_position if drip_point else global_position + Vector2(0, 16)
	get_tree().current_scene.add_child(drop)

func _on_frame_changed() -> void:
	if not sprite:
		return
	# Spawn the drop one frame before the drip animation finishes
	if sprite.animation == "drip" and _pending_drop and _drip_last_frame_index > 0:
		if sprite.frame == _drip_last_frame_index - 1:
			_pending_drop = false
			_spawn_drop()

func _on_animation_finished() -> void:
	if not sprite:
		return
	# When the drip animation finishes, ensure we return to idle
	if sprite.animation == "drip":
		# Fallback: if for some reason frame_changed didn't fire, spawn now
		if _pending_drop:
			_pending_drop = false
			_spawn_drop()
		if sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")

func _on_sleep() -> void:
	super._on_sleep()
	if drip_timer:
		drip_timer.stop()

func _on_wake() -> void:
	super._on_wake()
	if drip_timer and _initialized:
		drip_timer.start()
