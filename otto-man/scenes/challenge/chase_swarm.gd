class_name ChaseSwarm
extends Node2D

## Kovalamaca kuş sürüsü: oyuncunun hemen ensesinde kalmaya çalışır (gerilim modeli): uzaktayken hızlı,
## hedef mesafeye yaklaştıkça yavaşlar, oyuncu duraksayınca yetişip yakalar. Sürü fiziksel değildir;
## yakalama mesafe kontrolüyle yapılır ve ChallengeRoom'a sinyalle bildirilir.

signal caught(count: int)

const BIRD_SCENE_PATH := "res://enemy/flying/flying_enemy.tscn"
## Kuşlar yalnızca görsel (AnimatedSprite2D): fizik/çarpışma yok, yakalama tek mesafe kontrolü; bu yüzden
## yüzlercesi bile ucuz. 264 = ilk haline (33) göre 8 kat.
const BIRD_COUNT: int = 264
## Kazanınca kuşlar sağ üste (45 derece) doğru bu hızla uçup ekrandan çıkar
const FLY_OFF_SPEED: float = 750.0
## Sürü merkezi en az ekranın sol kenarından bu kadar içeride görünür
const VISIBLE_EDGE_MARGIN: float = 260.0
const CATCH_DISTANCE: float = 110.0
const CATCH_COOLDOWN: float = 2.0
## Yakalamadan sonra sürü bu kadar geri çekilir (oyuncuya nefes)
const RECOIL: float = 420.0
## Gerilim modeli sabitleri (bkz. _physics_process)
const FOLLOW_GAIN: float = 1.4              # mesafe farkının hıza etkisi (1/sn)
const MIN_SPEED: float = 260.0              # sürü en yavaş bu hızla ilerler (duran oyuncuya yetişir)
const MAX_SPEED: float = 1100.0             # çok uzakta kalınca en çok bu hız
const TENSION_SHRINK_PER_SECOND: float = 0.005
const TENSION_SHRINK_MAX: float = 0.3

## Sürünün oyuncunun arkasında tutmaya çalıştığı yatay mesafe (px); zorlukla azalır, ChallengeRoom ayarlar
var tension_gap: float = 420.0
var speed: float = 340.0
var target: Node2D = null
var running: bool = false
var catch_count: int = 0
var floor_y: float = 928.0
var _cooldown: float = 0.0
var _birds: Array[AnimatedSprite2D] = []
var _bird_offsets: Array[Vector2] = []
## Kuş başına salınım: (x genliği, y genliği, hız, faz)
var _bird_drift: Array[Vector4] = []
var _time: float = 0.0
var _run_time: float = 0.0
var _prev_target_x: float = 0.0
var _player_vx: float = 0.0
var _flying_off: bool = false


func _ready() -> void:
	# Oyuncunun (z 7) altında kalsın: kalabalık sürü karakteri örtmesin
	z_index = 5
	var frames: SpriteFrames = _load_bird_frames()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(BIRD_COUNT):
		var bird := AnimatedSprite2D.new()
		bird.sprite_frames = frames
		if frames != null:
			var anim: StringName = &"fly" if frames.has_animation(&"fly") else &"chase"
			bird.play(anim)
			bird.frame = rng.randi() % maxi(1, frames.get_frame_count(anim))
		# Boyut ve ton çeşidi: yakın kuşlar iri/koyu, uzaktakiler küçük/soluk (derinlik hissi)
		var depth: float = rng.randf()
		var s: float = lerpf(1.0, 1.8, depth)
		bird.scale = Vector2(s, s)
		bird.modulate = Color(0.55, 0.4, 0.4).lerp(Color(0.8, 0.6, 0.55), 1.0 - depth)
		bird.speed_scale = rng.randf_range(0.8, 1.3)
		bird.z_index = int(depth * 1.9)
		add_child(bird)
		_birds.append(bird)
		# Organik sürü: öne doğru sivri, arkaya doğru dağılan gözyaşı/komet biçimi (kare kutu değil).
		# Yatay: ön uçta yoğun, arkaya seyrelen üstel dağılım; dikey sapma arkaya gittikçe açılır.
		var back: float = minf(-log(maxf(rng.randf(), 0.0001)) * 230.0, 1100.0)
		var spread_y: float = 60.0 + 0.22 * back
		var oy: float = clampf(rng.randfn(-150.0, spread_y), -430.0, 90.0)
		_bird_offsets.append(Vector2(40.0 - back, oy))
		# Her kuşun kendi salınımı: sürü akışkan görünsün (sabit konumda dizilmesin)
		_bird_drift.append(Vector4(rng.randf_range(18.0, 70.0), rng.randf_range(18.0, 60.0),
				rng.randf_range(0.6, 1.8), rng.randf_range(0.0, TAU)))


func _load_bird_frames() -> SpriteFrames:
	var scene := load(BIRD_SCENE_PATH) as PackedScene
	if scene == null:
		return null
	var inst: Node = scene.instantiate()
	var frames: SpriteFrames = null
	var sprite := inst.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null:
		frames = sprite.sprite_frames
	inst.free()
	return frames


## Oyuncuyla sürü merkezi arasındaki yatay mesafe (pozitifse oyuncu önde).
func gap() -> float:
	return target.global_position.x - global_position.x if is_instance_valid(target) else 9999.0


## Bölüm kazanıldı: kovalamayı bırakıp sağ üste doğru (45 derece) uçarak ekrandan çıkar.
func fly_off() -> void:
	running = false
	_flying_off = true
	# Sürü oyuncunun hemen solunda toplanır; oradan çaprazlama sağ üste uçup ekranı geçer
	if is_instance_valid(target):
		global_position = target.global_position + Vector2(-420.0, -120.0)


func _physics_process(delta: float) -> void:
	_time += delta
	_animate_birds()
	if _flying_off:
		var dir := Vector2(1.0, -1.0).normalized()
		for i in range(_birds.size()):
			# Her kuş biraz farklı hızda: dağınık bir sürü olarak çıkarlar
			_bird_offsets[i] += dir * FLY_OFF_SPEED * (0.85 + 0.3 * float(i % 5) / 4.0) * delta
		return
	if not is_instance_valid(target):
		return
	# Oyuncunun ileri hızı (yumuşatılmış): bekleyen/yavaşlayan oyuncuyu sürü fark eder.
	# Sürü koşmasa da izlenir ki ilk kare büyük sıçrama göstermesin.
	var px: float = target.global_position.x
	var inst_vx: float = (px - _prev_target_x) / maxf(delta, 0.0001)
	_prev_target_x = px
	_player_vx = lerpf(_player_vx, clampf(inst_vx, 0.0, 900.0), minf(1.0, 6.0 * delta))
	if not running:
		return
	_run_time += delta
	var g: float = gap()
	# Gerilim modeli: sürü oyuncunun hemen ensesinde (tension_gap) kalmaya çalışır. Uzaktayken
	# hızla yaklaşır, hedef mesafeye gelince oyuncunun hızına uyar (yavaşlar). Oyuncu duraksar ya da
	# hata yaparsa mesafe kapanır ve yakalar; kusursuz koşan mesafeyi korur ama rahatlayamaz.
	# Koşu ilerledikçe hedef mesafe daralır (en çok %30).
	var want_gap: float = tension_gap * maxf(1.0 - TENSION_SHRINK_PER_SECOND * _run_time, 1.0 - TENSION_SHRINK_MAX)
	want_gap = maxf(want_gap, CATCH_DISTANCE + 70.0)   # yakalama mesafesine fazla yaklaşıp sürekli yakalamasın
	var v: float = _player_vx + FOLLOW_GAIN * (g - want_gap)
	v = clampf(v, MIN_SPEED, MAX_SPEED)
	global_position.x += v * delta
	# Yükseklik: oyuncunun yüksekliğini yumuşak izler (çukura inerse sürü de iner)
	var want_y: float = clampf(target.global_position.y - 90.0, floor_y - 330.0, floor_y + 40.0)
	global_position.y = lerpf(global_position.y, want_y, 3.0 * delta)
	if _cooldown > 0.0:
		_cooldown -= delta
	elif g < CATCH_DISTANCE:
		_cooldown = CATCH_COOLDOWN
		catch_count += 1
		global_position.x -= RECOIL
		caught.emit(catch_count)


func _animate_birds() -> void:
	# Sürü gerçekte ekranın solundan uzaktaysa bile kuşlar ekranın sol kenarında uçarak görünür kalır
	# (yakalanma gerçek konuma göre; görsel kayma gerçek konum kenara varınca sıfırlanır, sıçrama olmaz)
	var shift: float = 0.0
	var cam := get_viewport().get_camera_2d()
	if cam != null and not _flying_off:
		var edge: float = cam.get_screen_center_position().x - 960.0 + VISIBLE_EDGE_MARGIN
		shift = maxf(0.0, edge - global_position.x)
	for i in range(_birds.size()):
		var d: Vector4 = _bird_drift[i]
		var wobble := Vector2(sin(_time * d.z + d.w) * d.x, cos(_time * d.z * 1.3 + d.w) * d.y)
		var bob: float = sin(_time * 6.0 + float(i) * 1.7) * 8.0
		_birds[i].position = _bird_offsets[i] + Vector2(shift, bob) + wobble
		_birds[i].flip_h = false
