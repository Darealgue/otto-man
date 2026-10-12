class_name ResourceHitHarvest
extends Area2D
## Orman kaynaklarını (ağaç, çalı, kaya) saldırıyla sökme: oyuncunun hafif, ağır ve düşme saldırısı
## (herhangi bir PlayerHitbox) kaynağa her isabet ettiğinde sayaç düşer; her HITS_MIN..HITS_MAX
## isabette 1 kaynak yere düşer. Düğümün bir kapasitesi vardır (varsayılan DEFAULT_CAPACITY düşüş,
## generator host'ta "harvest_capacity" meta'sıyla değiştirebilir); kapasite dolunca düğüm
## "bitti" animasyonunu oynar (ağaç devrilir, çalı meyvesiz görüntüye geçer, kaya kırılır) ve
## bir daha vurulmaz. Düşen kaynak zaman sınırsız yerinde durur (bkz. ResourceDropPickup).
##
## Hex'in hammadde stoğu sınırlıysa (sınırlı bölge) her düşüş stoktan 1 birim alır; stok bitmişse
## düğüm kaynak vermeden bitiş animasyonuna geçer.
##
## Vuruş tespiti kırılabilir dekorla (DecorationSpawner._setup_breakable_decoration) aynıdır:
## ENEMY_HURTBOX katmanında, yalnızca PLAYER_HITBOX maskeli bir Area2D. "hurtbox" grubuna GİRMEZ,
## böylece PlayerHitbox'ın düşman yolu (geri tepme, hitstop) ve düşme saldırısının sekmesi/bekleme
## süresi tetiklenmez; düşme saldırısı kaynağın içinden geçip yine isabet sayar.

const HITS_MIN: int = 3
const HITS_MAX: int = 4
const DEFAULT_CAPACITY: int = 2
## Aynı salınışın birden fazla alanı/şekli yüzünden iki kez sayılmaması için.
const MIN_HIT_INTERVAL_MSEC: int = 140
const DROP_LIFT: float = 110.0
## Bitiş animasyonu sırasında rengin solacağı ton (ağaç/kaya).
const FADE_TINT: Color = Color(0.62, 0.58, 0.52, 1.0)
const FADE_DURATION: float = 1.2

var resource_type: String = "wood"
var area_size: Vector2 = Vector2(240.0, 220.0)

var _host: Node2D = null
var _capacity: int = DEFAULT_CAPACITY
var _drops_done: int = 0
var _hits_until_drop: int = 0
var _finished: bool = false
var _last_hit_msec: int = -100000
var _wobble_tween: Tween = null


## `host`un altına bir vuruş alanı ekler. `offset` host'un yerel koordinatındadır.
static func attach(host: Node2D, type: String, size: Vector2, offset: Vector2) -> ResourceHitHarvest:
	var harvest := ResourceHitHarvest.new()
	harvest.name = "ResourceHitHarvest"
	harvest.resource_type = type
	harvest.area_size = size
	harvest.position = offset
	host.add_child(harvest)
	return harvest


func _ready() -> void:
	_host = get_parent() as Node2D
	if _host != null:
		_capacity = maxi(1, int(_host.get_meta("harvest_capacity", DEFAULT_CAPACITY)))
	collision_layer = CollisionLayers.ENEMY_HURTBOX
	collision_mask = CollisionLayers.PLAYER_HITBOX
	monitoring = true
	monitorable = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = area_size
	shape.shape = rect
	add_child(shape)
	_hits_until_drop = randi_range(HITS_MIN, HITS_MAX)
	area_entered.connect(_on_area_entered)
	_connect_hit_animation_return()


func _on_area_entered(area: Area2D) -> void:
	if _finished:
		return
	if not (area is PlayerHitbox):
		return
	if area.has_method("is_enabled") and not area.is_enabled():
		return
	if _host == null or not is_instance_valid(_host):
		return
	# Eğitimde hedef tamamlanınca (ve herhangi bir sebeple) devre dışı bırakılan kaynak vurulmaz.
	if _host.has_method("is_interactable_enabled") and not _host.is_interactable_enabled():
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_hit_msec < MIN_HIT_INTERVAL_MSEC:
		return
	_last_hit_msec = now
	_register_hit()


func _register_hit() -> void:
	_hits_until_drop -= 1
	if _hits_until_drop > 0:
		_play_hit_feedback()
		return
	_hits_until_drop = randi_range(HITS_MIN, HITS_MAX)
	_drops_done += 1
	var last_drop: bool = _drops_done >= _capacity
	if not last_drop:
		_play_hit_feedback()
	_drop_resource()
	if last_drop:
		_finish_node()


## Stok yoksa kaynak vermez; çağıran yine de düğümü bitirir.
func _drop_resource() -> void:
	var generator: Node = get_tree().get_first_node_in_group("level_generator")
	if generator != null and generator.has_method("zone_try_consume_stock"):
		if not bool(generator.call("zone_try_consume_stock")):
			# Stok bitmiş: bu düğümde artık verecek bir şey kalmadı.
			_drops_done = _capacity
			call_deferred("_finish_node")
			return
	var parent: Node = _host.get_parent() if _host.get_parent() != null else _host
	ResourceDropPickup.spawn(parent, _host.global_position + Vector2(0.0, -DROP_LIFT), resource_type, 1)


func _finish_node() -> void:
	if _finished:
		return
	_finished = true
	set_deferred("monitoring", false)
	if _host == null or not is_instance_valid(_host):
		return
	if _wobble_tween != null and _wobble_tween.is_valid():
		_wobble_tween.kill()
		_host.position.x = float(_host.get_meta("rest_x", _host.position.x))
	if _host.has_method("set_interactable_enabled"):
		_host.call("set_interactable_enabled", false)
	if _host.has_method("play_end_animation"):
		_host.call("play_end_animation")
	_fade_host_color()


func _fade_host_color() -> void:
	# Bitiş görseli kendi içinde solmuşsa (çalının meyvesiz çizimi) renk oynamaz.
	if _host.has_method("wants_end_color_fade") and not bool(_host.call("wants_end_color_fade")):
		return
	var tween := _host.create_tween()
	tween.tween_property(_host, "modulate", FADE_TINT, FADE_DURATION)


func _play_hit_feedback() -> void:
	if _host.has_method("play_hit_animation"):
		_host.call("play_hit_animation")
	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm != null and sm.has_method("play_sfx"):
		sm.play_sfx("hit_light", _host.global_position)
	# Hafif sarsıntı; hit animasyonu olmayan düğümlerde de bir geri bildirim olsun.
	if _wobble_tween != null and _wobble_tween.is_valid():
		_wobble_tween.kill()
		_host.position.x = float(_host.get_meta("rest_x", _host.position.x))
	_host.set_meta("rest_x", _host.position.x)
	var rest_x: float = _host.position.x
	_wobble_tween = _host.create_tween()
	_wobble_tween.tween_property(_host, "position:x", rest_x + 5.0, 0.04)
	_wobble_tween.tween_property(_host, "position:x", rest_x - 4.0, 0.06)
	_wobble_tween.tween_property(_host, "position:x", rest_x, 0.05)


## "hit" animasyonu bitince idle'a dön. Ağaç/çalı/kaya sprite adları farklı; hangisi varsa bağlanır.
func _connect_hit_animation_return() -> void:
	if _host == null:
		return
	for sprite_name in ["TreeIdleSprite", "BushIdleSprite", "RockIdleSprite"]:
		var sprite := _host.get_node_or_null(sprite_name) as AnimatedSprite2D
		if sprite == null:
			continue
		sprite.animation_finished.connect(func() -> void:
			if is_instance_valid(sprite) and sprite.animation == &"hit" and not _finished:
				sprite.play("idle")
		)
