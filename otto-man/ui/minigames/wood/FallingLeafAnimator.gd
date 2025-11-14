extends Node2D

# Yaprak animasyonunu minigame'den bağımsız yönetir
var _fall_start_pos: Vector2
var _fall_end_pos: Vector2
var _fall_start_rotation: float
var _fall_end_rotation: float
var _fall_start_scale: Vector2
var _fall_end_scale: Vector2
var _fall_time: float
var _fall_elapsed: float = 0.0
var _is_falling: bool = false

func _ready() -> void:
	# Script eklendiğinde hemen process'i aktif et (start_fall() çağrılmasını bekler)
	set_process(true)

func start_fall(start_pos: Vector2, end_pos: Vector2, start_rotation: float, end_rotation: float, start_scale: Vector2, end_scale: Vector2, fall_time: float) -> void:
	_fall_start_pos = start_pos
	_fall_end_pos = end_pos
	_fall_start_rotation = start_rotation
	_fall_end_rotation = end_rotation
	_fall_start_scale = start_scale
	_fall_end_scale = end_scale
	_fall_time = fall_time
	_fall_elapsed = 0.0
	_is_falling = true
	set_process(true)

func _process(delta: float) -> void:
	if not _is_falling:
		set_process(false)
		return
	
	_fall_elapsed += delta
	
	if _fall_elapsed >= _fall_time:
		# Animasyon bitti, sil
		queue_free()
		return
	
	# Interpolasyon ile pozisyon, rotasyon ve scale hesapla
	var t = _fall_elapsed / _fall_time
	var start_pos = _fall_start_pos
	var end_pos = _fall_end_pos
	var start_rotation = _fall_start_rotation
	var end_rotation = _fall_end_rotation
	var start_scale = _fall_start_scale
	var end_scale = _fall_end_scale
	
	# Ease in için quadratic easing
	var eased_t = t * t
	
	global_position = start_pos.lerp(end_pos, eased_t)
	rotation_degrees = lerp(start_rotation, end_rotation, eased_t)
	scale = start_scale.lerp(end_scale, eased_t)
	
	# Fade out - son 40% sürede
	if t > 0.6:
		var fade_t = (t - 0.6) / 0.4
		modulate.a = 1.0 - fade_t

