extends BaseTrapV2
class_name LightningRodTrapV2

## Fırtına zindanının tuzağı: yıldırım direği. Oyuncu yakına gelince direk şarj olur
## (yukarıdaki sütun titreyerek uyarı verir), sonra sütuna yıldırım düşer. Uyarı süresince
## sütundan çıkan oyuncu hasar almaz; hasar sadece vuruş anında sütunun içindekine gider.
## Sprite'ı yok, tamamen kodla çizilir (_draw). 1 tile, zemin karolarına konur.

enum RodState { IDLE, CHARGING, STRIKE, COOLDOWN }

## Oyuncu bu yatay yarı genişlik ve dikey aralık içindeyse direk şarj olmaya başlar.
@export var detect_half_width: float = 150.0
@export var detect_height: float = 260.0
@export var charge_time: float = 0.9
@export var strike_time: float = 0.25
@export var cooldown_time: float = 2.5

const BEAM_HALF_WIDTH: float = 20.0
const BEAM_HEIGHT: float = 224.0
const KNOCKBACK_FORCE: float = 380.0
const KNOCKBACK_UP_FORCE: float = 300.0
const ROD_COLOR := Color(0.28, 0.28, 0.4)
const GLOW_COLOR := Color(0.75, 0.85, 1.0)

var _state: RodState = RodState.IDLE
var _t: float = 0.0
var _bolt_points: PackedVector2Array = PackedVector2Array()


func _on_initialized() -> void:
	_set_state(RodState.IDLE)


func _physics_process(delta: float) -> void:
	if is_sleeping:
		return
	match _state:
		RodState.IDLE:
			if _player_in_detect_range():
				_set_state(RodState.CHARGING)
		RodState.CHARGING:
			_t += delta
			queue_redraw()
			if _t >= charge_time:
				_strike()
		RodState.STRIKE:
			_t += delta
			queue_redraw()
			if _t >= strike_time:
				_set_state(RodState.COOLDOWN)
		RodState.COOLDOWN:
			_t += delta
			if _t >= cooldown_time:
				_set_state(RodState.IDLE)


func _set_state(s: RodState) -> void:
	_state = s
	_t = 0.0
	queue_redraw()


func _player_in_detect_range() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return false
	var d: Vector2 = player.global_position - global_position
	return absf(d.x) <= detect_half_width and d.y >= -detect_height and d.y <= 48.0


func _strike() -> void:
	_set_state(RodState.STRIKE)
	_build_bolt()
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		var d: Vector2 = player.global_position - global_position
		# Oyuncunun origin'i ayak hizasında; gövde yaklaşık 44 px yukarı uzanır
		if absf(d.x) <= BEAM_HALF_WIDTH and d.y >= -BEAM_HEIGHT and d.y <= 12.0:
			apply_damage_with_knockback(player, KNOCKBACK_FORCE, KNOCKBACK_UP_FORCE)
	# Tuzak Fısıldayan: yıldırım sütunundaki düşmanlar da hasar alır
	if TrapEnemyDamage.is_active():
		TrapEnemyDamage.damage_enemies_in_radius(get_tree(), global_position + Vector2(0.0, -BEAM_HEIGHT * 0.5), BEAM_HEIGHT * 0.5, get_damage())


## Direğin ucundan sütunun tepesine tırtıklı bir yıldırım çizgisi.
func _build_bolt() -> void:
	_bolt_points = PackedVector2Array()
	var steps := 9
	var top := Vector2(0.0, -BEAM_HEIGHT)
	var tip := Vector2(0.0, -18.0)
	for i in range(steps + 1):
		var p: Vector2 = top.lerp(tip, float(i) / float(steps))
		if i > 0 and i < steps:
			p.x += randf_range(-14.0, 14.0)
		_bolt_points.append(p)


func _draw() -> void:
	# Direk: gövde + uç
	draw_rect(Rect2(-3.0, -16.0, 6.0, 16.0), ROD_COLOR)
	draw_rect(Rect2(-6.0, -2.0, 12.0, 2.0), ROD_COLOR)
	var tip_color := Color(0.9, 0.9, 0.5)
	match _state:
		RodState.CHARGING:
			var k: float = clampf(_t / charge_time, 0.0, 1.0)
			# Uyarı sütunu: giderek belirginleşen, titreyen alan
			var flicker: float = 0.6 + 0.4 * sin(_t * 40.0)
			draw_rect(Rect2(-BEAM_HALF_WIDTH, -BEAM_HEIGHT, BEAM_HALF_WIDTH * 2.0, BEAM_HEIGHT),
				Color(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, (0.04 + 0.2 * k) * flicker))
			# Uçta büyüyen parıltı
			draw_circle(Vector2(0.0, -18.0), 4.0 + 8.0 * k, Color(1.0, 1.0, 0.6, 0.35 + 0.4 * k))
			tip_color = Color(1.0, 1.0, 0.8)
		RodState.STRIKE:
			var fade: float = 1.0 - clampf(_t / strike_time, 0.0, 1.0)
			draw_rect(Rect2(-BEAM_HALF_WIDTH, -BEAM_HEIGHT, BEAM_HALF_WIDTH * 2.0, BEAM_HEIGHT),
				Color(0.8, 0.9, 1.0, 0.18 * fade))
			if _bolt_points.size() > 1:
				draw_polyline(_bolt_points, Color(0.55, 0.7, 1.0, 0.55 * fade), 9.0)
				draw_polyline(_bolt_points, Color(1.0, 1.0, 1.0, fade), 3.0)
			draw_circle(Vector2(0.0, -18.0), 12.0 * fade + 3.0, Color(1.0, 1.0, 0.8, 0.8 * fade))
			tip_color = Color(1.0, 1.0, 1.0)
	draw_circle(Vector2(0.0, -18.0), 3.0, tip_color)


func _on_sleep() -> void:
	super._on_sleep()
	_set_state(RodState.IDLE)
