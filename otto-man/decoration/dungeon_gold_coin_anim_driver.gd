extends Node
## Havuz / breakable altını: uçarken sadece 0. kare (fizik taklası görünsün); durunca 8 kare animasyon + dünya uzayında dik.

const ANIM_FPS: float = 10.0
## Bu altında hızlı sayılır “durdu”; biraz üstünde hâlâ yuvarlanıyor sayılır.
const REST_SPEED_SQ: float = 55.0
const REST_ANG_SPD: float = 0.45
## Ardışık bu kadar süre dinlenince animasyon başlar (mikro sekmede titreme olmasın).
const REST_STABLE_SEC: float = 0.2

var _accum: float = 0.0
var _stable_timer: float = 0.0
var _anim_started: bool = false


func _loot_body_at_rest(rb: RigidBody2D) -> bool:
	return rb.linear_velocity.length_squared() <= REST_SPEED_SQ and absf(rb.angular_velocity) <= REST_ANG_SPD


func _process(delta: float) -> void:
	var host := get_parent()
	if not is_instance_valid(host):
		return
	var spr := host.get_node_or_null("Sprite") as Sprite2D
	if not spr or spr.texture == null:
		return
	var n: int = maxi(1, spr.hframes * spr.vframes)
	if n < 2:
		return

	var rb := host as RigidBody2D
	var is_pooled_coin: bool = rb != null

	if is_pooled_coin:
		var moving := not _loot_body_at_rest(rb)
		if moving:
			_stable_timer = 0.0
			_anim_started = false
			_accum = 0.0
			spr.frame = 0
			return
		_stable_timer += delta
		if _stable_timer < REST_STABLE_SEC:
			_accum = 0.0
			spr.frame = 0
			return
		if not _anim_started:
			_anim_started = true
			_accum = 0.0
	else:
		# Zemindeki statik altın: baştan animasyon
		if not _anim_started:
			_anim_started = true
			_accum = 0.0

	_accum += delta
	spr.frame = int(floorf(_accum * ANIM_FPS)) % n
	if is_pooled_coin:
		spr.global_rotation = 0.0
