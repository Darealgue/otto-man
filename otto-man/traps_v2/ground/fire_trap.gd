extends BaseTrapV2
class_name FireTrapV2

## Proximity-based fire trap. Activates when player is nearby,
## deals continuous damage + burn debuff.
##
## Animation flow:
##   idle  → (player enters detection) →  active (one-shot opening)
##         → sustain (looping damage phase)
##         → (player leaves detection) →  cooldown (one-shot closing)
##         → idle

enum FireState { DORMANT, OPENING, SUSTAIN, CLOSING }

@export var detection_radius: float = 80.0
@export var burn_ticks: int = 4
@export var burn_damage_per_tick: float = 2.0
@export var damage_interval: float = 0.4
@export var cooldown_after_deactivate: float = 2.0
## Fire must stay on at least this long after activating (prevents instant off when player steps away).
@export var min_active_duration: float = 1.2
## Fire turns off after this long even if player is still in range (so they don't burn forever).
@export var max_active_duration: float = 3.0

const KNOCKBACK_FORCE: float = 360.0
const KNOCKBACK_UP_FORCE: float = 260.0

var _state: FireState = FireState.DORMANT
var _damage_cooldown: float = 0.0
var _player_in_range: bool = false
var _sustain_elapsed: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var damage_area: Area2D = $DamageArea
@onready var fire_light: PointLight2D = $PointLight2D

func _ready() -> void:
	detection_area.body_entered.connect(_on_detection_entered)
	detection_area.body_exited.connect(_on_detection_exited)
	damage_area.monitoring = false

	var det_shape := detection_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if det_shape and det_shape.shape is CircleShape2D:
		(det_shape.shape as CircleShape2D).radius = detection_radius

	var has_frames := sprite and sprite.sprite_frames and sprite.sprite_frames.get_frame_count("idle") > 0
	if not has_frames:
		_create_placeholder(Color(1.0, 0.4, 0.0, 0.6), "FIRE")
	else:
		sprite.animation_finished.connect(_on_animation_finished)
		sprite.play("idle")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_sleeping:
		return
	if _state != FireState.SUSTAIN:
		return
	_sustain_elapsed += delta
	# Max duration: turn off even if player still in range (don't burn forever)
	if _sustain_elapsed >= max_active_duration:
		_start_closing()
		return
	# Player left: only close after minimum active time
	if not _player_in_range and _sustain_elapsed >= min_active_duration:
		_start_closing()
		return
	_damage_cooldown -= delta
	if _damage_cooldown > 0.0:
		return
	for body in damage_area.get_overlapping_bodies():
		if body.is_in_group("player"):
			if body.is_dodging or (body.invincibility_timer > 0.0):
				continue
			apply_damage_with_knockback(body, KNOCKBACK_FORCE, KNOCKBACK_UP_FORCE)
			var sem := get_status_effect_manager(body)
			if sem:
				sem.apply_burn(burn_ticks, burn_damage_per_tick)
			_damage_cooldown = damage_interval
			break

func _on_detection_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		if _state == FireState.DORMANT:
			_start_opening()

func _on_detection_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		# Closing is handled in _physics_process: only after min_active_duration in SUSTAIN

func _start_opening() -> void:
	_state = FireState.OPENING
	damage_area.monitoring = true
	_damage_cooldown = 0.0
	_set_placeholder_active(true)
	_set_fire_light(true)
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("active"):
		sprite.play("active")
	else:
		_enter_sustain()

func _enter_sustain() -> void:
	_state = FireState.SUSTAIN
	_sustain_elapsed = 0.0
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("sustain"):
		sprite.play("sustain")

func _start_closing() -> void:
	_state = FireState.CLOSING
	damage_area.monitoring = false
	_set_placeholder_active(false)
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("cooldown"):
		sprite.play("cooldown")
	else:
		_enter_dormant()

func _enter_dormant() -> void:
	_state = FireState.DORMANT
	damage_area.monitoring = false
	_set_fire_light(false)
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")

func _on_animation_finished() -> void:
	match _state:
		FireState.OPENING:
			_enter_sustain()
		FireState.CLOSING:
			if _player_in_range:
				_start_opening()
			else:
				_enter_dormant()

func _set_fire_light(on: bool) -> void:
	if fire_light:
		fire_light.visible = on
		fire_light.energy = 3.5 if on else 0.0

func _on_sleep() -> void:
	super._on_sleep()
	detection_area.monitoring = false
	damage_area.monitoring = false
	if fire_light:
		fire_light.visible = false

func _on_wake() -> void:
	super._on_wake()
	detection_area.monitoring = true
	if _state == FireState.SUSTAIN or _state == FireState.OPENING:
		damage_area.monitoring = true
		_set_fire_light(true)
