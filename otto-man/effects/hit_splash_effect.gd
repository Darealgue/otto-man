extends Node2D
class_name HitSplashEffect

const SPLASH_TEXTURE := preload("res://assets/effects/player fx/hit_splash.png")
const FRAME_COUNT := 4
const FRAME_DURATION := 0.05

var _sprite: Sprite2D

func setup(
	spawn_position: Vector2,
	rotation_deg: float,
	flip_h: bool,
	scale_multiplier: float = 1.0
) -> void:
	z_index = 10
	global_position = spawn_position
	rotation_degrees = rotation_deg
	scale = Vector2(scale_multiplier, scale_multiplier)
	_ensure_sprite()
	_sprite.flip_h = flip_h
	_play_animation()

func _ensure_sprite() -> void:
	if _sprite:
		return
	_sprite = Sprite2D.new()
	_sprite.centered = true
	_sprite.texture = SPLASH_TEXTURE
	_sprite.hframes = FRAME_COUNT
	_sprite.vframes = 1
	_sprite.frame = 0
	add_child(_sprite)

func _play_animation() -> void:
	var tween := create_tween()
	for frame in range(FRAME_COUNT):
		tween.tween_callback(_set_frame.bind(frame))
		tween.tween_interval(FRAME_DURATION)
	tween.tween_callback(queue_free)

func _set_frame(frame: int) -> void:
	if _sprite:
		_sprite.frame = frame
