extends Node2D

# Arka planda uçan küçük kuş. bird1.png: 5 kareli yatay sprite sheet (her kare 40x20), kendi boyutunda çizilir.

const SHEET: Texture2D = preload("res://village/assets/birds/bird1.png")
const FRAME_SIZE: Vector2 = Vector2(40, 20)
const FRAME_COUNT: int = 5
const GLIDE_FRAMES: Array[int] = [1, 2]  # süzülürken (sayfadaki 2. ve 3. çizim) yavaşça dönüşümlü gösterilir
const GLIDE_FRAME_RATE: float = 1.2

const WIND_SPEED_BONUS: float = 0.5
const DESPAWN_MARGIN: float = 120.0

var velocity_x: float = 50.0
var flap_rate: float = 7.0       # saniyedeki kanat karesi
var bob_amplitude: float = 4.0
var bob_phase: float = 0.0
var base_y: float = 60.0

var _time: float = 0.0
var _flap_time: float = 0.0
var _current_frame_index: int = -1
var _gliding: bool = false
var _state_timer: float = 0.0

func _ready() -> void:
	_state_timer = randf_range(1.0, 2.5)
	bob_phase = randf() * TAU
	_flap_time = randf() * FRAME_COUNT
	position.y = base_y
	_update_frame(true)

func _process(delta: float) -> void:
	_time += delta
	var wind: float = 0.0
	var weather := get_node_or_null("/root/WeatherManager")
	if weather != null and "wind_strength" in weather:
		wind = float(weather.wind_strength)
	position.x += velocity_x * delta * (1.0 + wind * WIND_SPEED_BONUS)
	position.y = base_y + sin(_time * 1.3 + bob_phase) * bob_amplitude

	# Çırpma ve süzülme dönüşümlü: bir süre çırpar, bir süre kanat açık süzülür.
	_state_timer -= delta
	if _state_timer <= 0.0:
		_gliding = not _gliding
		_state_timer = randf_range(0.8, 2.0) if _gliding else randf_range(1.5, 3.5)
	_flap_time += delta * (GLIDE_FRAME_RATE if _gliding else flap_rate)
	_update_frame(false)

	var vp_width: float = get_viewport_rect().size.x
	if (velocity_x > 0.0 and position.x > vp_width + DESPAWN_MARGIN) or (velocity_x < 0.0 and position.x < -DESPAWN_MARGIN):
		queue_free()

func _update_frame(force: bool) -> void:
	var frame_index: int = GLIDE_FRAMES[int(_flap_time) % GLIDE_FRAMES.size()] if _gliding else int(_flap_time) % FRAME_COUNT
	if force or frame_index != _current_frame_index:
		_current_frame_index = frame_index
		queue_redraw()

func _draw() -> void:
	if _current_frame_index < 0:
		return
	var src := Rect2(Vector2(_current_frame_index * FRAME_SIZE.x, 0), FRAME_SIZE)
	draw_texture_rect_region(SHEET, Rect2(-FRAME_SIZE * 0.5, FRAME_SIZE), src)
