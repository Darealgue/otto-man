extends Node

# Gündüz zaman zaman gökyüzünde kuş sürüleri geçirir. Ekran uzayında çalışan bir ParallaxLayer'a (bulutlarla aynı)
# AmbientBird ekler. Yağmur/fırtınada ve geceleyin kuş çıkmaz.

@export var layer_path: NodePath = ^"../ParallaxBackground/ParallaxLayerFar"
@export var min_interval: float = 35.0
@export var max_interval: float = 90.0
@export var first_spawn_min: float = 6.0
@export var first_spawn_max: float = 20.0
@export var sky_y_min: float = 10.0
@export var sky_y_max: float = 110.0

const DAY_START_HOUR: int = 7
const DAY_END_HOUR: int = 18
const MAX_RAIN_INTENSITY: float = 0.15
const SPAWN_MARGIN: float = 120.0
# Büyük göç: nadir (%3), 9-11 kuşluk uzun V.
const MIGRATION_CHANCE_THRESHOLD: float = 0.97
const MIGRATION_MIN_BIRDS: int = 9
const MIGRATION_MAX_BIRDS: int = 11
const AmbientBird = preload("res://village/scripts/AmbientBird.gd")

var _layer: Node = null
var _timer: float = 0.0
var _time_manager: Node = null

func _ready() -> void:
	_layer = get_node_or_null(layer_path)
	if _layer == null:
		push_warning("BirdFlockManager: layer bulunamadi: %s" % str(layer_path))
		set_process(false)
		return
	_timer = randf_range(first_spawn_min, first_spawn_max)

func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = randf_range(min_interval, max_interval)
	if _can_spawn_now():
		_spawn_flock()

func _can_spawn_now() -> bool:
	if _time_manager == null or not is_instance_valid(_time_manager):
		_time_manager = get_node_or_null("/root/TimeManager")
	if _time_manager != null and _time_manager.has_method("get_hour"):
		var hour: int = int(_time_manager.get_hour())
		if hour < DAY_START_HOUR or hour >= DAY_END_HOUR:
			return false
	var weather := get_node_or_null("/root/WeatherManager")
	if weather != null:
		if "storm_active" in weather and weather.storm_active:
			return false
		if "rain_intensity" in weather and float(weather.rain_intensity) > MAX_RAIN_INTENSITY:
			return false
	return true

func _spawn_flock() -> void:
	var roll: float = randf()
	var count: int = 1
	var is_migration: bool = roll >= MIGRATION_CHANCE_THRESHOLD
	if is_migration:
		count = randi_range(MIGRATION_MIN_BIRDS, MIGRATION_MAX_BIRDS)
	elif roll >= 0.85:
		count = randi_range(4, 5)
	elif roll >= 0.5:
		count = randi_range(2, 3)

	var vp_width: float = get_viewport().get_visible_rect().size.x
	var go_right: bool = randf() < 0.5
	var speed: float = randf_range(45.0, 70.0)
	var lead_y: float = randf_range(sky_y_min, sky_y_max)
	if is_migration:
		# Geniş V ekran dışına taşmasın diye yüksekliği orta banda al.
		lead_y = randf_range(sky_y_min + 40.0, sky_y_max - 20.0)
	var start_x: float = -SPAWN_MARGIN if go_right else vp_width + SPAWN_MARGIN

	for i in count:
		var bird := AmbientBird.new()
		bird.velocity_x = (speed if go_right else -speed) * randf_range(0.95, 1.05)
		bird.flap_rate = randf_range(6.0, 8.0)
		bird.bob_amplitude = randf_range(2.0, 5.0)
		# V şeklinde dizilim: arkadaki kuşlar sürünün gerisinde ve iki yana açılır.
		var behind: float = float(i) * randf_range(45.0, 75.0)
		var side: float = float((i + 1) / 2) * (14.0 if i % 2 == 1 else -14.0)
		bird.base_y = lead_y + side
		_layer.add_child(bird)
		bird.position = Vector2(start_x - behind if go_right else start_x + behind, bird.base_y)
