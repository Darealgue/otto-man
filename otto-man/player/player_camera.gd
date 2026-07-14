extends Camera2D

# Horizontal look-ahead: shows a bit more of the direction the player is running towards.

@export var look_ahead_x: float = 140.0
@export var look_ahead_smooth_speed: float = 4.0

var _player: CharacterBody2D
var _offset_x: float = 0.0

func _ready() -> void:
	_player = get_parent() as CharacterBody2D

func _process(delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		return
	var reference_speed: float = _player.speed if "speed" in _player else 400.0
	var target_x: float = 0.0
	if reference_speed > 0.0:
		target_x = clamp(_player.velocity.x / reference_speed, -1.0, 1.0) * look_ahead_x
	var k: float = 1.0 - exp(-look_ahead_smooth_speed * delta)
	_offset_x = lerp(_offset_x, target_x, clamp(k, 0.0, 1.0))
	offset.x = _offset_x
