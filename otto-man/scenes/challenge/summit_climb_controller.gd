class_name SummitClimbController
extends Node

## Zirve Tırmanışı çalışma zamanı: dikey kamera, altın toplama, düşme ve zirve denetimi, yükseklikle
## koyulaşan gökyüzü ve dünya uzayında akan bulutlar (yükseldiğini hissettirmek için).
## Düzen SummitTowerBuilder'dan gelir; ChallengeRoom yalnız sinyalleri dinler.

signal reached_summit
signal fell
signal stats_changed(gold: int, meters: int, total_meters: int)

## En yüksek durulan noktadan bu kadar aşağı inilirse düşülmüş sayılır (14 karo)
const FAIL_DROP: float = 448.0
const METER_PX: float = 64.0
const PICKUP_RADIUS: Array[float] = [32.0, 40.0, 52.0]
const CLOUD_PATHS: Array[String] = [
	"res://village/assets/clouds/cloud1.png", "res://village/assets/clouds/cloud2.png",
	"res://village/assets/clouds/cloud3.png", "res://village/assets/clouds/cloud4.png",
	"res://village/assets/clouds/cloud5.png", "res://village/assets/clouds/cloud6.png",
	"res://village/assets/clouds/cloud7.png", "res://village/assets/clouds/cloud8.png",
]

var player: Node2D = null
var cam: Camera2D = null
var layout: Dictionary = {}
var active: bool = false
var gold: int = 0
var total_meters: int = 0

var _floor_y: float = 0.0
var _summit_y: float = 0.0
var _best_y: float = 0.0
var _ref_y: float = 0.0
var _coins: Array = []
var _clock: float = 0.0
var _sky_tint: ColorRect = null
var _clouds: Array[Dictionary] = []
var _done: bool = false


func setup(p_player: Node2D, p_cam: Camera2D, p_layout: Dictionary) -> void:
	player = p_player
	cam = p_cam
	layout = p_layout
	_floor_y = float(layout["floor_y"])
	_summit_y = float(layout["summit_y"])
	_best_y = _floor_y
	_ref_y = _floor_y
	_coins = layout["coins"]
	total_meters = int((_floor_y - _summit_y) / METER_PX)
	_build_sky_tint()
	_build_clouds()


func start() -> void:
	active = true


func _physics_process(delta: float) -> void:
	_clock += delta
	_animate_coins()
	_drift_clouds(delta)
	if not is_instance_valid(player) or cam == null:
		return
	_update_camera(delta)
	_update_sky()
	if not active or _done:
		return
	var on_floor: bool = bool(player.call("is_on_floor"))
	var py: float = player.global_position.y
	if on_floor and py < _best_y:
		_best_y = py
		stats_changed.emit(gold, int((_floor_y - _best_y) / METER_PX), total_meters)
	_collect_coins()
	if on_floor and py <= _summit_y + 12.0 \
			and player.global_position.x >= float(layout["summit_x0"]) - 8.0 \
			and player.global_position.x <= float(layout["summit_x1"]) + 8.0:
		_done = true
		active = false
		reached_summit.emit()
		return
	if py > _best_y + FAIL_DROP:
		_done = true
		active = false
		fell.emit()


## Kamera: oyuncunun son bastığı yüzeyi yumuşakça izler (zıplayınca sallanmaz); oyuncu ekranın
## üstüne çok yaklaşırsa ya da düşüyorsa onunla birlikte hareket eder.
func _update_camera(delta: float) -> void:
	var py: float = player.global_position.y
	if bool(player.call("is_on_floor")):
		_ref_y = py
	var target: float = _ref_y - 170.0
	target = minf(target, py + 380.0)
	target = maxf(target, py - 430.0)
	target = clampf(target, float(layout["cam_min_y"]), 540.0)
	cam.position.y = lerpf(cam.position.y, target, minf(1.0, 6.0 * delta))
	cam.position.x = 960.0


func _collect_coins() -> void:
	var pc: Vector2 = player.global_position + Vector2(0.0, -24.0)
	for c in _coins:
		if bool(c["taken"]):
			continue
		var pos: Vector2 = c["pos"]
		if absf(pos.y - pc.y) > 60.0 or absf(pos.x - pc.x) > 60.0:
			continue
		if pos.distance_to(pc) > PICKUP_RADIUS[int(c["tier"])]:
			continue
		c["taken"] = true
		gold += int(c["v"])
		_pop_coin(c)
		stats_changed.emit(gold, int((_floor_y - _best_y) / METER_PX), total_meters)


func _pop_coin(c: Dictionary) -> void:
	var sprite: Sprite2D = c["node"]
	if is_instance_valid(sprite):
		var tw := sprite.create_tween()
		tw.set_parallel(true)
		tw.tween_property(sprite, "scale", sprite.scale * 1.8, 0.18)
		tw.tween_property(sprite, "modulate:a", 0.0, 0.18)
		tw.chain().tween_callback(sprite.queue_free)
	var parent := get_parent()
	if parent == null:
		return
	var label := Label.new()
	label.text = "+%d" % int(c["v"])
	label.add_theme_font_size_override("font_size", 22 + 6 * int(c["tier"]))
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 5)
	label.z_index = 20
	label.position = (c["pos"] as Vector2) + Vector2(-14.0, -40.0)
	parent.add_child(label)
	var lt := label.create_tween()
	lt.set_parallel(true)
	lt.tween_property(label, "position:y", label.position.y - 46.0, 0.7)
	lt.tween_property(label, "modulate:a", 0.0, 0.7)
	lt.chain().tween_callback(label.queue_free)


func _animate_coins() -> void:
	var base: int = int(_clock * 10.0)
	var i: int = 0
	for c in _coins:
		i += 1
		if bool(c["taken"]):
			continue
		var sprite: Sprite2D = c["node"]
		if is_instance_valid(sprite):
			sprite.frame = (base + i) % 8


# --- Gökyüzü ve bulutlar ----------------------------------------------------------------------

func _build_sky_tint() -> void:
	var layer := CanvasLayer.new()
	layer.name = "AltitudeSky"
	layer.layer = -999   # gökyüzü gradyanının (-1000) hemen önünde, parallax dağların arkasında
	add_child(layer)
	_sky_tint = ColorRect.new()
	_sky_tint.color = Color(0.04, 0.06, 0.3, 0.0)
	_sky_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sky_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_sky_tint)


func _update_sky() -> void:
	if _sky_tint == null:
		return
	var progress: float = clampf((_floor_y - player.global_position.y) / maxf(_floor_y - _summit_y, 1.0), 0.0, 1.0)
	_sky_tint.color.a = 0.62 * pow(progress, 1.3)


## Dünya uzayında (kamerayla aynı hızda kayan) bulutlar: yükselirken yanından geçip gider.
func _build_clouds() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var holder := Node2D.new()
	holder.name = "SummitClouds"
	holder.z_index = -8
	parent.add_child(holder)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var y: float = _floor_y - 360.0
	while y > _summit_y - 700.0:
		for k in range(rng.randi_range(1, 2)):
			var sprite := Sprite2D.new()
			var tex := load(CLOUD_PATHS[rng.randi() % CLOUD_PATHS.size()]) as Texture2D
			if tex == null:
				continue
			sprite.texture = tex
			var s: float = rng.randf_range(2.2, 4.0)
			sprite.scale = Vector2(s, s)
			sprite.modulate = Color(1, 1, 1, rng.randf_range(0.5, 0.85))
			sprite.position = Vector2(rng.randf_range(-100.0, 2020.0), y + rng.randf_range(-120.0, 120.0))
			holder.add_child(sprite)
			_clouds.append({"node": sprite, "speed": rng.randf_range(6.0, 22.0)})
		y -= rng.randf_range(300.0, 440.0)


func _drift_clouds(delta: float) -> void:
	for c in _clouds:
		var sprite: Sprite2D = c["node"]
		if not is_instance_valid(sprite):
			continue
		sprite.position.x += float(c["speed"]) * delta
		if sprite.position.x > 2200.0:
			sprite.position.x = -300.0
