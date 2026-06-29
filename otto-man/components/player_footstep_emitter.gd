class_name PlayerFootstepEmitter
extends Node
## Koşu loop'unda ayak indiği animasyon karelerinde adım SFX.

const RunFootstepConfig = preload("res://components/run_footstep_config.gd")

var _player: CharacterBody2D = null
var _sprite: Sprite2D = null
var _last_run_frame: int = -1

const MIN_RUN_SPEED: float = 40.0


func setup(player: CharacterBody2D) -> void:
	_player = player
	_sprite = player.get_node_or_null("Sprite2D") as Sprite2D


func _process(_delta: float) -> void:
	if not is_instance_valid(_player) or _sprite == null:
		return
	_poll_run_footsteps()


func _poll_run_footsteps() -> void:
	var anim_player: AnimationPlayer = _player.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim_player == null:
		return
	if StringName(anim_player.current_animation) != RunFootstepConfig.RUN_ANIM or not anim_player.is_playing():
		_last_run_frame = -1
		return
	if not _player.is_on_floor() or absf(float(_player.velocity.x)) < MIN_RUN_SPEED:
		_last_run_frame = -1
		return

	var frame: int = _sprite.frame
	if frame == _last_run_frame:
		return
	if _last_run_frame >= 0 and RunFootstepConfig.is_foot_contact_frame(frame):
		_play_footstep()
	_last_run_frame = frame


func _play_footstep() -> void:
	var sm := get_node_or_null("/root/SoundManager")
	if sm == null:
		return
	var pitch: float = randf_range(0.9, 1.08)
	if sm.has_method("play_footstep"):
		sm.play_footstep(_player.global_position, pitch)
	elif sm.has_method("play_sfx"):
		sm.play_sfx("footstep_player", _player.global_position, pitch)
