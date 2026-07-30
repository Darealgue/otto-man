extends Camera2D

# Horizontal look-ahead: shows a bit more of the direction the player is running towards.
#
# Uses a critically-damped spring (inertia-based) instead of a direct position lerp: the offset
# has to build up speed before it moves much, so a quick direction reversal (e.g. rapid A-D-A-D
# tapping) mostly cancels out instead of sweeping the camera hard between the two extremes. Once
# the offset gets very close to its target, it's hard-snapped to the exact value — spring/lerp
# easing never mathematically reaches the target, which reads as a sub-pixel wobble in pixel art
# if left to approach forever.

@export var look_ahead_x: float = 140.0
## Roughly how long the offset takes to settle on a new target after it changes.
@export var look_ahead_smooth_time: float = 0.22
## Caps how fast the offset itself can move, so sustained same-direction acceleration can't make
## it swing unboundedly fast either.
@export var look_ahead_max_speed: float = 900.0

var _player: CharacterBody2D
var _offset_x: float = 0.0
var _offset_vel: float = 0.0

## Set by ScreenEffects instead of writing to `offset` directly, so shake and look-ahead combine
## in one place each frame rather than two separate scripts stomping the same property.
var shake_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	_player = get_parent() as CharacterBody2D


func _process(delta: float) -> void:
	if _player and is_instance_valid(_player):
		var reference_speed: float = _player.speed if "speed" in _player else 400.0
		var target_x: float = 0.0
		if reference_speed > 0.0:
			target_x = clamp(_player.velocity.x / reference_speed, -1.0, 1.0) * look_ahead_x
		var result := _spring_damp(_offset_x, target_x, _offset_vel, look_ahead_smooth_time, delta, look_ahead_max_speed)
		_offset_x = result[0]
		_offset_vel = result[1]
		if absf(_offset_x - target_x) < 0.05 and absf(_offset_vel) < 1.0:
			_offset_x = target_x
			_offset_vel = 0.0
	offset = Vector2(_offset_x, 0.0) + shake_offset


func set_shake_offset(v: Vector2) -> void:
	shake_offset = v


## Critically-damped spring toward `target`, given current value/velocity. Standard smoothing
## technique (same shape as Unity's SmoothDamp) — has real inertia instead of snapping to a
## target speed, and won't overshoot/oscillate. Returns [new_value, new_velocity].
func _spring_damp(current: float, target: float, current_velocity: float, smooth_time: float, delta: float, max_speed: float) -> Array:
	var st: float = maxf(0.0001, smooth_time)
	var omega: float = 2.0 / st
	var x: float = omega * delta
	var exp_term: float = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change: float = current - target
	var max_change: float = max_speed * st
	change = clampf(change, -max_change, max_change)
	var clamped_target: float = current - change
	var temp: float = (current_velocity + omega * change) * delta
	var new_velocity: float = (current_velocity - omega * temp) * exp_term
	var output: float = clamped_target + (change + temp) * exp_term
	if (target - current > 0.0) == (output > target):
		output = target
		new_velocity = (output - target) / maxf(delta, 0.0001)
	return [output, new_velocity]
