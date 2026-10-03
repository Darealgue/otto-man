extends Node2D
class_name StormWatcher

## Fırtına zindanının "hareket et" kuralı: oyuncu bir yerde sabit durursa tepeden yıldırım çarpar.
## Akış: SABİT SAYIM -> UYARI (oyuncunun başında "!" + zemin halkası + kıvılcımlar) -> VURUŞ -> BEKLEME.
## Uyarı süresince halkadan çıkan hasar almaz; yıldırım boş zemine düşer.
## Level generator tema ayarıyla (DungeonThemeStyle "idle_strike") kurar. Görseller kodla çizilir.

enum Phase { WATCHING, WARNING, STRIKE, COOLDOWN }

var stationary_time: float = 2.0
var warning_time: float = 0.9
var cooldown_time: float = 3.0
var damage: float = 14.0

## Bu kadar pikselden fazla uzaklaşmak "kıpırdadı" sayılır.
const MOVE_THRESHOLD: float = 28.0
## Yıldırımın vurduğu alan (yatay yarıçap / oyuncu ayağından yukarı yükseklik)
const STRIKE_RADIUS: float = 96.0
const STRIKE_HEIGHT: float = 140.0
const BOLT_TOP: float = 700.0
const WARN_COLOR := Color(1.0, 0.85, 0.2)

var _phase: Phase = Phase.WATCHING
var _t: float = 0.0
var _anchor: Vector2 = Vector2.ZERO
var _has_anchor: bool = false
var _strike_pos: Vector2 = Vector2.ZERO
var _bolt_points: PackedVector2Array = PackedVector2Array()
var _player: Node2D = null


func setup(settings: Dictionary, level: int) -> void:
	stationary_time = float(settings.get("stationary_time", stationary_time))
	warning_time = float(settings.get("warning_time", warning_time))
	cooldown_time = float(settings.get("cooldown", cooldown_time))
	damage = float(settings.get("damage", damage)) * (1.0 + 0.25 * float(maxi(level, 1) - 1))


func _ready() -> void:
	# Dünya koordinatlarında çiziyoruz; üst düğümün konumundan bağımsız olsun
	top_level = true
	global_position = Vector2.ZERO
	z_index = 40
	z_as_relative = false


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
	match _phase:
		Phase.WATCHING:
			_watch(delta)
		Phase.WARNING:
			_t += delta
			queue_redraw()
			if _t >= warning_time:
				_strike()
		Phase.STRIKE:
			_t += delta
			queue_redraw()
			if _t >= 0.3:
				_enter(Phase.COOLDOWN)
		Phase.COOLDOWN:
			_t += delta
			if _t >= cooldown_time:
				_enter(Phase.WATCHING)


func _enter(p: Phase) -> void:
	_phase = p
	_t = 0.0
	_has_anchor = false
	queue_redraw()


func _watch(delta: float) -> void:
	var pos: Vector2 = _player.global_position
	if not _has_anchor or pos.distance_to(_anchor) > MOVE_THRESHOLD:
		_anchor = pos
		_has_anchor = true
		_t = 0.0
		return
	_t += delta
	if _t >= stationary_time:
		_strike_pos = _anchor
		_enter(Phase.WARNING)
		_has_anchor = true


func _strike() -> void:
	_enter(Phase.STRIKE)
	_build_bolt(_strike_pos)
	if _in_strike_zone(_player.global_position):
		_hurt_player()
	# Yıldırım düşmanlara da vurur: hasar + şok (1 sn stun), oyuncuyla aynı etki
	for node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		if _in_strike_zone(node.global_position):
			if node.has_method("take_damage"):
				node.take_damage(damage, 0.0, 0.0, true)
			if is_instance_valid(node) and node.has_method("apply_shock"):
				node.apply_shock()


func _in_strike_zone(pos: Vector2) -> bool:
	var d: Vector2 = pos - _strike_pos
	return absf(d.x) <= STRIKE_RADIUS and d.y >= -STRIKE_HEIGHT and d.y <= 40.0


## Hasar + şok (1 sn stun). Itme/Hurt yok: oyuncu olduğu yerde donar. Şok bitince kısa süre
## dokunulmazlık verilir ki arka arkaya hasar zinciri oluşmasın.
func _hurt_player() -> void:
	if _player.get("is_dodging") or (_player.get("invincibility_timer") != null and _player.invincibility_timer > 0.0):
		return
	if not _player.has_method("take_damage"):
		return
	_player.take_damage(damage)
	var sem = _player.get("status_effects")
	if sem and sem.has_method("apply_shock"):
		sem.apply_shock(1.0)
	_player.invincibility_timer = maxf(float(_player.invincibility_timer), 1.6)


func _build_bolt(ground: Vector2) -> void:
	_bolt_points = PackedVector2Array()
	var steps := 12
	var top := ground + Vector2(randf_range(-30.0, 30.0), -BOLT_TOP)
	for i in range(steps + 1):
		var p: Vector2 = top.lerp(ground, float(i) / float(steps))
		if i > 0 and i < steps:
			p.x += randf_range(-22.0, 22.0)
		_bolt_points.append(p)


func _draw() -> void:
	match _phase:
		Phase.WARNING:
			var k: float = clampf(_t / warning_time, 0.0, 1.0)
			var blink: float = 0.55 + 0.45 * sin(_t * 28.0)
			# Zemin halkası: yıldırımın düşeceği yer, giderek daralıp yoğunlaşır
			var r: float = STRIKE_RADIUS * (1.15 - 0.15 * k)
			draw_arc(_strike_pos, r, 0.0, TAU, 40, Color(WARN_COLOR.r, WARN_COLOR.g, WARN_COLOR.b, 0.4 + 0.5 * k), 3.0)
			draw_circle(_strike_pos, r, Color(1.0, 0.95, 0.5, 0.08 + 0.12 * k))
			# Zeminden fışkıran kıvılcımlar
			for i in range(12):
				var ang: float = float(i) / 12.0 * TAU + _t * 6.0
				var base: Vector2 = _strike_pos + Vector2(cos(ang) * r * 0.8, 0.0)
				var spark_len: float = 8.0 + 14.0 * k * (0.5 + 0.5 * sin(_t * 30.0 + float(i) * 2.1))
				draw_line(base, base + Vector2(randf_range(-4.0, 4.0), -spark_len), Color(0.8, 0.9, 1.0, 0.9), 2.0)
			# Gökten inecek yıldırımın soluk ön izlemesi
			draw_line(_strike_pos + Vector2(0.0, -BOLT_TOP), _strike_pos, Color(0.7, 0.8, 1.0, 0.05 + 0.15 * k * blink), 2.0)
			# Oyuncunun başında ünlem işareti (sarı üçgen + "!")
			if _player and is_instance_valid(_player):
				_draw_exclamation(_player.global_position + Vector2(0.0, -86.0 - 4.0 * absf(sin(_t * 14.0))), blink)
		Phase.STRIKE:
			var fade: float = 1.0 - clampf(_t / 0.3, 0.0, 1.0)
			if _bolt_points.size() > 1:
				draw_polyline(_bolt_points, Color(0.5, 0.65, 1.0, 0.5 * fade), 14.0)
				draw_polyline(_bolt_points, Color(1.0, 1.0, 1.0, fade), 4.0)
			draw_circle(_strike_pos, STRIKE_RADIUS * (1.2 - 0.4 * fade), Color(1.0, 1.0, 0.9, 0.5 * fade))
			draw_arc(_strike_pos, STRIKE_RADIUS * (1.6 - 0.6 * fade), 0.0, TAU, 40, Color(0.8, 0.9, 1.0, 0.8 * fade), 3.0)


func _draw_exclamation(center: Vector2, alpha: float) -> void:
	var tri := PackedVector2Array([center + Vector2(0, -16), center + Vector2(15, 12), center + Vector2(-15, 12)])
	draw_colored_polygon(tri, Color(WARN_COLOR.r, WARN_COLOR.g, WARN_COLOR.b, 0.55 + 0.45 * alpha))
	draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(0.15, 0.1, 0.0), 2.0)
	draw_rect(Rect2(center + Vector2(-1.5, -7), Vector2(3, 11)), Color(0.15, 0.1, 0.0))
	draw_rect(Rect2(center + Vector2(-1.5, 6), Vector2(3, 3)), Color(0.15, 0.1, 0.0))
