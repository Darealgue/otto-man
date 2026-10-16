class_name VisitGuard
extends CharacterBody2D
## Ziyaret köyünün nöbetçisi: köy askeri sprite'ı (oyuncu köyündeki askerlerle aynı, Worker._get_soldier_frames),
## köye göre ufak renk farkı, iki nokta arasında devriye. Görüş konisi VisitPerception'dan gelir.
## StealthPerception'ın beklediği düşman arayüzünü (direction, is_sleeping, current_behavior, health,
## get_nearest_player) sağlar; gerçek düşman değildir, hasar almaz.

const WORKER_SCRIPT := preload("res://village/scripts/Worker.gd")
const SPRITE_OFFSET := Vector2(0.0, -60.0)
const WALK_SPEED: float = 55.0
const BASE_VISION_RANGE: float = 260.0
const VISION_ANGLE_DEG: float = 70.0
const SUSPICION_THRESHOLD: float = 1.1
const EYE_OFFSET := Vector2(0.0, -62.0)

# StealthPerception'ın okuduğu alanlar
var direction: int = 1
var is_sleeping: bool = false
var current_behavior: String = "patrol"
var health: float = 1.0
var enemy_id: String = ""
var stats: Variant = null

var scene_ref: Node = null
var patrol_left: float = 0.0
var patrol_right: float = 0.0
var perception: VisitPerception = null

var _sprite: AnimatedSprite2D = null
var _target_x: float = 0.0
var _pause_left: float = 0.0
var _suspicious_turn_cooldown: float = 0.0


func setup(p_scene: Node, p_left: float, p_right: float, tint: Color, p_id: String) -> void:
	scene_ref = p_scene
	patrol_left = minf(p_left, p_right)
	patrol_right = maxf(p_left, p_right)
	enemy_id = p_id
	z_index = 2
	collision_layer = 0
	collision_mask = 0
	var frames: SpriteFrames = WORKER_SCRIPT._get_soldier_frames()
	if frames != null:
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = frames
		_sprite.position = SPRITE_OFFSET
		_sprite.modulate = tint
		add_child(_sprite)
		_play("idle")
	perception = VisitPerception.new()
	perception.name = "StealthPerception"
	perception.scene_ref = scene_ref
	perception.vision_angle_deg = VISION_ANGLE_DEG
	perception.vision_range = BASE_VISION_RANGE
	perception.suspicion_threshold = SUSPICION_THRESHOLD
	perception.eye_offset = EYE_OFFSET
	add_child(perception)
	perception.setup(self)
	_target_x = patrol_right if randf() < 0.5 else patrol_left
	direction = 1 if _target_x >= global_position.x else -1
	_face()
	_pause_left = randf_range(0.0, 2.0)


## Görüş menzilini kipe göre ayarlar (gündüz düşman köyde çok geniş).
func set_vision_multiplier(mult: float) -> void:
	if perception != null:
		perception.vision_range = BASE_VISION_RANGE * maxf(mult, 0.0)


func get_nearest_player() -> Node2D:
	var p: Node = get_tree().get_first_node_in_group("player")
	return p as Node2D


func get_nearest_player_in_range() -> Node2D:
	var p: Node2D = get_nearest_player()
	if p != null and global_position.distance_to(p.global_position) <= 300.0:
		return p
	return null


func _physics_process(delta: float) -> void:
	if perception != null:
		perception.update_perception(delta)
	var alarm: bool = scene_ref != null and bool(scene_ref.get("alarm_active"))
	if alarm:
		_play("idle")
		return
	# Şüphelenince durur ve gördüğü yöne döner.
	if perception != null and perception.is_suspicious():
		var t: Node2D = perception.get_watch_target()
		if t != null:
			var dir_to: int = 1 if t.global_position.x >= global_position.x else -1
			if dir_to != direction:
				direction = dir_to
				_face()
		_play("idle")
		return
	if _pause_left > 0.0:
		_pause_left -= delta
		_play("idle")
		return
	var dx: float = _target_x - global_position.x
	if absf(dx) <= 4.0:
		# Uçta bekler, sonra diğer uca döner.
		_target_x = patrol_left if _target_x >= patrol_right - 1.0 else patrol_right
		_pause_left = randf_range(1.5, 4.0)
		direction = 1 if _target_x >= global_position.x else -1
		_face()
		return
	direction = 1 if dx > 0.0 else -1
	_face()
	global_position.x += float(direction) * minf(WALK_SPEED * delta, absf(dx))
	_play("walk")


func _face() -> void:
	if _sprite != null:
		_sprite.flip_h = direction < 0


func _play(anim: String) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if _sprite.animation != anim or not _sprite.is_playing():
		if _sprite.sprite_frames.has_animation(anim):
			_sprite.play(anim)
