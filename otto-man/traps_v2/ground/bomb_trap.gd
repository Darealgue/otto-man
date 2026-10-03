extends BaseTrapV2
class_name BombTrapV2

## Barut zindanının tuzağı: zemindeki bomba. Oyuncu yaklaşınca fitili yanar (yanıp sönme + patlama
## alanını gösteren halka), süre dolunca patlar. Patlama yakındaki diğer bombaların fitilini de
## yakar (zincir). Patlayan bomba bir süre sonra yeniden kurulur.
## Sprite'ı yok, kodla çizilir (_draw); sprite gelince _draw yerine animasyon konabilir.
## 1 tile, zemin karolarına konur.

enum BombState { ARMED, LIT, EXPLODED }

## Oyuncu bu mesafeye (yatay yarı genişlik / yukarı yükseklik) girince fitil yanar.
@export var trigger_half_width: float = 52.0
@export var trigger_height: float = 56.0
@export var fuse_time: float = 0.7
## Zincirleme tutuşan bombanın fitil süresi (daha kısa: zincir hızlı yayılır).
@export var chain_fuse_time: float = 0.3
@export var explosion_radius: float = 80.0
@export var rearm_time: float = 10.0

const CHAIN_RADIUS: float = 96.0
const KNOCKBACK_FORCE: float = 600.0
const KNOCKBACK_UP_FORCE: float = 380.0

var _state: BombState = BombState.ARMED
var _t: float = 0.0
var _fuse_left: float = 0.0


func _on_initialized() -> void:
	add_to_group("bomb_traps")
	_set_state(BombState.ARMED)


func _physics_process(delta: float) -> void:
	if is_sleeping:
		return
	match _state:
		BombState.ARMED:
			if _player_near():
				ignite(fuse_time)
		BombState.LIT:
			_t += delta
			queue_redraw()
			if _t >= _fuse_left:
				_explode()
		BombState.EXPLODED:
			_t += delta
			if _t >= rearm_time:
				_set_state(BombState.ARMED)


## Fitili yakar (zaten yanıyorsa kalan süreyi kısaltabilir, uzatmaz).
func ignite(fuse: float) -> void:
	if _state == BombState.EXPLODED:
		return
	if _state == BombState.LIT:
		_fuse_left = minf(_fuse_left, _t + fuse)
		return
	_set_state(BombState.LIT)
	_fuse_left = fuse


func _set_state(s: BombState) -> void:
	_state = s
	_t = 0.0
	queue_redraw()


func _player_near() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return false
	var d: Vector2 = player.global_position - global_position
	return absf(d.x) <= trigger_half_width and d.y >= -trigger_height and d.y <= 24.0


func _explode() -> void:
	_set_state(BombState.EXPLODED)
	var center: Vector2 = global_position + Vector2(0.0, -10.0)
	# Görsel
	var holder: Node = get_tree().current_scene
	if holder:
		var blast := BlastVisualV2.new()
		holder.add_child(blast)
		blast.global_position = center
		blast.setup(explosion_radius)
	# Oyuncu
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and player.global_position.distance_to(center) <= explosion_radius + 12.0:
		_hurt_player(player, center)
	# Tuzak Fısıldayan: patlama düşmanlara da hasar verir
	if TrapEnemyDamage.is_active():
		TrapEnemyDamage.damage_enemies_in_radius(get_tree(), center, explosion_radius, get_damage())
	# Zincir: yakındaki diğer bombaların fitilini yakar
	for other in get_tree().get_nodes_in_group("bomb_traps"):
		if other == self or not is_instance_valid(other):
			continue
		if (other as Node2D).global_position.distance_to(global_position) <= CHAIN_RADIUS and other.has_method("ignite"):
			other.ignite(chain_fuse_time)


func _hurt_player(player: Node2D, center: Vector2) -> void:
	if player.get("is_dodging") or (player.get("invincibility_timer") != null and player.invincibility_timer > 0.0):
		return
	player.last_hit_position = center
	player.last_hit_knockback = { "force": KNOCKBACK_FORCE, "up_force": KNOCKBACK_UP_FORCE }
	player.take_damage(get_damage())
	if player.get("state_machine") and player.state_machine.has_node("Hurt"):
		player.state_machine.transition_to("Hurt", true)


func _draw() -> void:
	if _state == BombState.EXPLODED:
		return
	var lit: bool = _state == BombState.LIT
	var k: float = clampf(_t / maxf(_fuse_left, 0.01), 0.0, 1.0) if lit else 0.0
	# Gövde: koyu yuvarlak + parlama
	var body_color := Color(0.16, 0.15, 0.17)
	if lit and fmod(_t * (6.0 + 18.0 * k), 1.0) < 0.5:
		body_color = Color(0.55, 0.15, 0.1)   # yanıp sönen kızıl
	draw_circle(Vector2(0.0, -10.0), 10.0, body_color)
	draw_circle(Vector2(-3.0, -13.0), 2.5, Color(0.5, 0.5, 0.55, 0.8))
	draw_rect(Rect2(-4.0, -21.0, 8.0, 3.0), Color(0.3, 0.22, 0.12))
	# Fitil: kıvrık çizgi; yanarken kısalır, ucunda kıvılcım
	var fuse_len: float = 8.0 * (1.0 - k)
	var tip := Vector2(4.0, -22.0 - fuse_len)
	draw_polyline(PackedVector2Array([Vector2(0.0, -21.0), Vector2(3.0, -22.0 - fuse_len * 0.5), tip]), Color(0.75, 0.6, 0.35), 2.0)
	if lit:
		draw_circle(tip, 3.0 + 2.0 * sin(_t * 40.0), Color(1.0, 0.85, 0.3))
		draw_circle(tip, 1.6, Color(1.0, 1.0, 0.9))
		# Patlama alanı: giderek belirginleşen uyarı halkası
		var center := Vector2(0.0, -10.0)
		draw_arc(center, explosion_radius, 0.0, TAU, 48, Color(1.0, 0.4, 0.15, 0.25 + 0.5 * k), 2.0)
		draw_circle(center, explosion_radius, Color(1.0, 0.35, 0.1, 0.05 + 0.1 * k))

