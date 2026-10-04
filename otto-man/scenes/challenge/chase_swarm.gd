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
## Sürü merkezi (baş) en az ekranın sol kenarından bu kadar içeride görünür; kuyruk geride kalan alana uzanır
const VISIBLE_EDGE_MARGIN: float = 560.0
## Giriş: süre (sn) ve sürünün başlangıçta sol dışarıda durduğu uzaklık (px)
const ENTRY_TIME: float = 1.8
const ENTRY_OFFSET: float = 1500.0
## Sürü şekli: başa düşen kuş oranı ve kuyruk uzunluğu (px)
const HEAD_FRACTION: float = 0.5
const TAIL_LENGTH: float = 900.0
const CATCH_DISTANCE: float = 110.0
const CATCH_COOLDOWN: float = 2.0
## Yakalamadan sonra sürü bu kadar geri çekilir (oyuncuya nefes); süre boyunca yavaşlayarak ve daireler çizerek
const RECOIL: float = 420.0
const RETREAT_TIME: float = 1.5
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
## Kuş başına kuyruk konumu: 0 = baş, (0,1] = kuyruk üzerindeki yer
var _tail_t: Array[float] = []
var _retreat_left: float = 0.0
## Giriş animasyonu ilerlemesi (0 -> 1); 1 = tamamlandı
var _entry: float = 1.0
## Yükseklik geçmişi (halka tampon, 60 Hz) ve kuş başına gecikme (kare)
const HIST_SIZE: int = 128
var _y_hist: PackedFloat32Array = PackedFloat32Array()
var _hist_i: int = 0
var _delay_frames: Array[int] = []
## Geri çekilirken kuş başına daire yarıçapı ve hızı
var _loop_radius: Array[float] = []
var _loop_speed: Array[float] = []
var _time: float = 0.0
var _run_time: float = 0.0
var _prev_target_x: float = 0.0
var _player_vx: float = 0.0
var _flying_off: bool = false
var _engulfing: bool = false
## Kaplama yörüngesi, kuş başına (yarıçap, açı, açısal hız)
var _orbit: Array[Vector3] = []


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
		# Spermatozoa biçimi: önde yoğun yuvarlak bir "baş", arkada giderek incelen dalgalı bir "kuyruk".
		# Baş kuşların %55'i; kuyruk kuşlarında t (0 = başa yakın, 1 = uç) boyunca genişlik azalır.
		var tail_t: float = 0.0
		var ox: float
		var oy: float
		if rng.randf() < HEAD_FRACTION:
			ox = rng.randfn(-70.0, 85.0)
			oy = rng.randfn(-150.0, 105.0)
		else:
			tail_t = rng.randf()
			ox = -190.0 - tail_t * TAIL_LENGTH
			# Kuyruk ekseni: başın merkezinden geriye, dalga genliği uca doğru büyür; genişlik uca doğru daralır
			var width: float = lerpf(55.0, 4.0, pow(tail_t, 0.7))
			oy = -150.0 + rng.randfn(0.0, width)
		_tail_t.append(tail_t)
		# Gecikme grupları: kuşların üçte biri 0.5 sn, üçte biri 1.0 sn, üçte biri 1.5 sn geriden takip eder (+-0.1 sn)
		var group: int = i % 3
		var delay_s: float = 0.5 + 0.5 * float(group) + rng.randf_range(-0.1, 0.1)
		_delay_frames.append(clampi(int(delay_s * 60.0), 0, HIST_SIZE - 1))
		_loop_radius.append(rng.randf_range(140.0, 380.0))
		_loop_speed.append(rng.randf_range(2.0, 3.6) * (1.0 if rng.randf() < 0.5 else -1.0))
		oy = clampf(oy, -430.0, 90.0)
		_bird_offsets.append(Vector2(ox, oy))
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
	# Kuşlar şu an ekranda göründükleri yerden kalkar: görsel kaymayı (sol kenarda tutan) ofsetlere işle,
	# yoksa kayma sıfırlanınca sürü ileriye "ışınlanmış" gibi görünür.
	var shift: float = _visual_shift()
	for i in range(_birds.size()):
		_bird_offsets[i] += Vector2(shift, 0.0)
	_flying_off = true


## Oyuncu öldü: sürü oyuncunun üstüne çöker, etrafında dönerek onu kaplar.
func engulf() -> void:
	running = false
	_engulfing = true
	z_index = 9   # bu sefer oyuncunun üstünde: kuşlar karakteri örter
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_orbit.clear()
	for i in range(_birds.size()):
		# (yarıçap, açı, açısal hız): yakın yarıçaplar sık, bir kısmı geniş dolanır
		_orbit.append(Vector3(rng.randf_range(15.0, 110.0) * (1.0 + 0.6 * rng.randf()), rng.randf_range(0.0, TAU), rng.randf_range(2.5, 6.0) * (1.0 if rng.randf() < 0.5 else -1.0)))


func _physics_process(delta: float) -> void:
	_time += delta
	_record_height()
	if _engulfing:
		_update_engulf(delta)
		return
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
	if _retreat_left > 0.0:
		# Yakalama sonrası geri çekilme: yavaşlayarak (ease-out) toplam RECOIL kadar geriler; bu sürede takip yok
		var left_ratio: float = _retreat_left / RETREAT_TIME
		global_position.x -= RECOIL * 2.0 * left_ratio / RETREAT_TIME * delta
		_retreat_left = maxf(0.0, _retreat_left - delta)
		global_position.y = lerpf(global_position.y, clampf(target.global_position.y - 90.0, floor_y - 330.0, floor_y + 40.0), 3.0 * delta)
		if _cooldown > 0.0:
			_cooldown -= delta
		return
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
		_retreat_left = RETREAT_TIME   # ışınlanma yok: yumuşakça geri çekilir, kuşlar geniş daireler çizer
		caught.emit(catch_count)


func _update_engulf(delta: float) -> void:
	if is_instance_valid(target):
		# Sürü merkezi oyuncunun gövdesine akar
		global_position = global_position.lerp(target.global_position + Vector2(0.0, -26.0), minf(1.0, 6.0 * delta))
	for i in range(_birds.size()):
		var o: Vector3 = _orbit[i]
		o.y += o.z * delta
		_orbit[i] = o
		var want := Vector2(cos(o.y) * o.x, sin(o.y) * o.x * 0.7)
		# Mevcut konumdan yörüngeye yumuşakça girer (uzaktaki kuşlar çekilip gelir)
		_birds[i].position = _birds[i].position.lerp(want, minf(1.0, 5.0 * delta))
		# Dönüş yönüne bakarlar
		_birds[i].flip_h = sin(o.y) * o.z < 0.0


## Sürünün yüksekliğini her karede halka tamponuna yazar. Kuşlar yukarı/aşağı takibi farklı gecikmelerle
## (0.5 / 1.0 / 1.5 sn) yapar: oyuncu zıplayıp inince sürü anında değil, kademe kademe tepki verir.
func _record_height() -> void:
	if _y_hist.is_empty():
		_y_hist.resize(HIST_SIZE)
		_y_hist.fill(global_position.y)
	_hist_i = (_hist_i + 1) % HIST_SIZE
	_y_hist[_hist_i] = global_position.y


## i. kuşun gecikmeli yüksekliği ile sürü merkezinin şu anki yüksekliği arasındaki fark.
func _delay_offset_y(i: int) -> float:
	if _y_hist.is_empty():
		return 0.0
	var idx: int = posmod(_hist_i - _delay_frames[i], HIST_SIZE)
	return _y_hist[idx] - global_position.y


## Sürü gerçekte ekranın solundan uzaktaysa bile kuşlar ekranın sol kenarında uçarak görünür kalır
## (yakalanma gerçek konuma göre; görsel kayma gerçek konum kenara varınca sıfırlanır, sıçrama olmaz).
func _visual_shift() -> float:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return 0.0
	var edge: float = cam.get_screen_center_position().x - 960.0 + VISIBLE_EDGE_MARGIN
	var want_x: float = edge
	if is_instance_valid(target):
		want_x = minf(edge, target.global_position.x - 220.0)   # baş asla oyuncunun önüne geçmesin
	return maxf(0.0, want_x - global_position.x)


## Kovalamaca başlar: sürü görünür olur ve ekranın solundan içeri süzülür (oyuncu koşmaya başlayınca çağrılır).
func begin() -> void:
	visible = true
	_entry = 0.0
	running = true


func _animate_birds() -> void:
	var shift: float = 0.0 if _flying_off else _visual_shift()
	# Giriş: sürü başta ekranın solunun dışında, sağa doğru süzülerek yerine gelir
	if _entry < 1.0:
		_entry = minf(1.0, _entry + get_physics_process_delta_time() / ENTRY_TIME)
		var e: float = _entry * _entry * (3.0 - 2.0 * _entry)
		shift -= (1.0 - e) * ENTRY_OFFSET
	# Yakalamadan sonra kuşlar geniş daireler çizerek açılır, sonra toparlanır (0 -> 1 -> 0)
	var loop: float = 0.0
	if _retreat_left > 0.0:
		loop = sin(PI * (1.0 - _retreat_left / RETREAT_TIME))
	for i in range(_birds.size()):
		var d: Vector4 = _bird_drift[i]
		var tt: float = _tail_t[i]
		var wobble := Vector2(sin(_time * d.z + d.w) * d.x, cos(_time * d.z * 1.3 + d.w) * d.y)
		if tt > 0.0:
			# Kuyruk: bireysel salınım azalır, yerine sperm kuyruğu gibi ilerleyen dalga gelir (uca doğru genlik büyür)
			wobble *= 0.25
			wobble.y += sin(_time * 4.0 - tt * 9.0) * (14.0 + 70.0 * tt)
		var bob: float = sin(_time * 6.0 + float(i) * 1.7) * 8.0
		var circle := Vector2.ZERO
		if loop > 0.0:
			var a: float = _time * _loop_speed[i] + d.w
			# Daireler zeminin altına inmesin: dikey bileşen hep yukarı (üst yarım daire yayları)
			circle = Vector2(cos(a), -absf(sin(a)) * 0.8) * _loop_radius[i] * loop
		_birds[i].position = _bird_offsets[i] + Vector2(shift, bob + _delay_offset_y(i)) + wobble + circle
		_birds[i].flip_h = false
