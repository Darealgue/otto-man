class_name ChaseSwarm
extends Node2D

## Kovalamaca kuş sürüsü: soldan sağa sabit hızla ilerler, oyuncuya yetişirse yakalar.
## Oyuncudan biraz yavaştır; engelde/çukurda duraksayan oyuncu mesafeyi kaybeder. Çok açılırsa
## sürü hızlanır (kauçuk bant) ki kovalamaca gerilimi bitmesin. Sürü fiziksel değildir; yakalama
## mesafe kontrolüyle yapılır ve ChallengeRoom'a sinyalle bildirilir.

signal caught(count: int)

const BIRD_SCENE_PATH := "res://enemy/flying/flying_enemy.tscn"
const BIRD_COUNT: int = 33
## Kazanınca kuşlar sağ üste (45 derece) doğru bu hızla uçup ekrandan çıkar
const FLY_OFF_SPEED: float = 750.0
const CATCH_DISTANCE: float = 110.0
const CATCH_COOLDOWN: float = 2.0
## Yakalamadan sonra sürü bu kadar geri çekilir (oyuncuya nefes)
const RECOIL: float = 420.0
## Oyuncu bu kadar açarsa sürü hızlanıp yetişir (kauçuk bant); çarpan oyuncudan hızlı olmasın diye ılımlı
const RUBBER_GAP: float = 900.0
## Koşu boyunca sürü yavaş yavaş hızlanır
const RAMP_PER_SECOND: float = 0.004
const RAMP_MAX: float = 1.08

var speed: float = 340.0
var target: Node2D = null
var running: bool = false
var catch_count: int = 0
var floor_y: float = 928.0
var _cooldown: float = 0.0
var _birds: Array[AnimatedSprite2D] = []
var _bird_offsets: Array[Vector2] = []
var _time: float = 0.0
var _run_time: float = 0.0
var _flying_off: bool = false


func _ready() -> void:
	z_index = 6
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
		bird.scale = Vector2(1.5, 1.5)
		bird.modulate = Color(0.55, 0.4, 0.4)
		add_child(bird)
		_birds.append(bird)
		_bird_offsets.append(Vector2(rng.randf_range(-320.0, 80.0), rng.randf_range(-300.0, 60.0)))


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
	if not running or not is_instance_valid(target):
		return
	_run_time += delta
	var g: float = gap()
	var v: float = speed * minf(1.0 + RAMP_PER_SECOND * _run_time, RAMP_MAX)
	if g > RUBBER_GAP:
		v *= 1.15
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
	for i in range(_birds.size()):
		var bob: float = sin(_time * 6.0 + float(i) * 1.7) * 14.0
		_birds[i].position = _bird_offsets[i] + Vector2(0.0, bob)
		_birds[i].flip_h = false
