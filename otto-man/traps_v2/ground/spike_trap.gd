extends BaseTrapV2
class_name SpikeTrapV2

## Timer-based spike trap. Rhythmically rises and falls regardless of player.
## 1 tile size (32x32), placed on floor tiles.

enum SpikeState { IDLE, RISING, ACTIVE, FALLING }

## Duration (seconds) the spikes stay up (ACTIVE) and the pause before next cycle (IDLE). Kept equal.
@export var active_idle_duration: float = 1.0
## Fallback duration if rise/fall animations are missing.
@export var rise_fall_fallback_duration: float = 0.25

const KNOCKBACK_FORCE: float = 400.0
const KNOCKBACK_UP_FORCE: float = 320.0

var _state: SpikeState = SpikeState.IDLE
var _has_dealt_damage_this_cycle: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var damage_area: Area2D = $DamageArea
@onready var cycle_timer: Timer = $CycleTimer

func _ready() -> void:
	damage_area.body_entered.connect(_on_body_entered)
	cycle_timer.timeout.connect(_start_cycle)
	var has_frames := sprite and sprite.sprite_frames and sprite.sprite_frames.get_frame_count("idle") > 0
	if not has_frames:
		_create_placeholder(Color(0.8, 0.2, 0.2, 0.6), "SPIKE")

func _on_initialized() -> void:
	if cycle_timer:
		cycle_timer.wait_time = active_idle_duration
		cycle_timer.start()

func _start_cycle() -> void:
	if is_sleeping:
		return
	cycle_timer.stop()
	_has_dealt_damage_this_cycle = false
	# RISING: duration from animation (SpriteFrames speed/FPS), not fixed timer
	_set_state(SpikeState.RISING)
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("rise"):
		sprite.play("rise")
		await sprite.animation_finished
	else:
		await get_tree().create_timer(rise_fall_fallback_duration).timeout
	if is_sleeping:
		_set_state(SpikeState.IDLE)
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")
		cycle_timer.wait_time = active_idle_duration
		cycle_timer.start()
		return
	_set_state(SpikeState.ACTIVE)
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("active"):
		sprite.play("active")
	_check_overlap()
	await get_tree().create_timer(active_idle_duration).timeout
	if is_sleeping:
		_set_state(SpikeState.IDLE)
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")
		cycle_timer.wait_time = active_idle_duration
		cycle_timer.start()
		return
	# FALLING: duration from animation (SpriteFrames speed/FPS)
	_set_state(SpikeState.FALLING)
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("fall"):
		sprite.play("fall")
		await sprite.animation_finished
	else:
		await get_tree().create_timer(rise_fall_fallback_duration).timeout
	if is_sleeping:
		_set_state(SpikeState.IDLE)
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")
		cycle_timer.wait_time = active_idle_duration
		cycle_timer.start()
		return
	_set_state(SpikeState.IDLE)
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")
	# Idle duration = active duration (same as time spikes were up)
	cycle_timer.wait_time = active_idle_duration
	if not is_sleeping:
		cycle_timer.start()

func _set_state(new_state: SpikeState) -> void:
	_state = new_state
	if damage_area:
		damage_area.monitoring = (_state == SpikeState.RISING or _state == SpikeState.ACTIVE)
	_set_placeholder_active(_state == SpikeState.RISING or _state == SpikeState.ACTIVE)

func _on_body_entered(body: Node2D) -> void:
	if _has_dealt_damage_this_cycle:
		return
	if (_state == SpikeState.RISING or _state == SpikeState.ACTIVE) and body.is_in_group("player"):
		apply_damage_with_knockback(body, KNOCKBACK_FORCE, KNOCKBACK_UP_FORCE)
		_has_dealt_damage_this_cycle = true

func _check_overlap() -> void:
	if _has_dealt_damage_this_cycle or not damage_area:
		return
	for body in damage_area.get_overlapping_bodies():
		if body.is_in_group("player"):
			apply_damage_with_knockback(body, KNOCKBACK_FORCE, KNOCKBACK_UP_FORCE)
			_has_dealt_damage_this_cycle = true
			break

func _on_sleep() -> void:
	super._on_sleep()
	if cycle_timer:
		cycle_timer.stop()
	_set_state(SpikeState.IDLE)

func _on_wake() -> void:
	super._on_wake()
	if cycle_timer and _initialized:
		cycle_timer.start()
