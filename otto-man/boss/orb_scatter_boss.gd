extends Node2D

signal enemy_defeated
signal health_changed(new_health: float, max_health: float)
signal vulnerability_changed(is_vulnerable: bool)

enum BossState { INTRO, ACTIVE, VULNERABLE, DEFEATED }

const BOUNCE_PROJECTILE_SCRIPT := preload("res://boss/boss_bounce_projectile.gd")
const DAMAGE_NUMBER_SCENE := preload("res://effects/damage_number.tscn")
const ENEMY_HITBOX_SCRIPT := preload("res://components/enemy_hitbox.gd")
const SCATTER_ANGLE_OFFSET := PI / 8.0

const SPRITE_DIR := "res://enemy/witch/sprite/"
const FRAME_SIZE := 240
const ANIM_FPS := 12.0

const SHEETS := {
	"intro": "witch_intro_border.png",
	"idle": "witch_idle_border.png",
	"move": "witch_move_border.png",
	"scatter": "witch_scatter_border.png",
	"charge": "witch_charge_border.png",
	"vulnerable": "witch_vulnerable_border.png",
	"hurt": "witch_hurt_border.png",
	"death": "witch_death_border.png",
}

## anim adı -> [sheet anahtarı, ilk kare (0-indeksli), kare sayısı, loop]
const ANIMS := {
	"intro": ["intro", 0, 21, false],
	"idle": ["idle", 0, 6, true],
	"move": ["move", 0, 6, true],
	"scatter_telegraph": ["scatter", 0, 14, false],
	"scatter_fire": ["scatter", 14, 12, false],
	"charge_telegraph": ["charge", 0, 19, false],
	"charge_dash": ["charge", 19, 8, true],
	"charge_recover": ["charge", 27, 2, false],
	# Charge sheet'i minik topta bitiyor, geri açılma çizilmemiş.
	# Scatter sheet'inin kuyruğu (22-26) tam olarak o top -> cadı geçişi.
	"charge_unfurl": ["scatter", 21, 5, false],
	"vulnerable_open": ["vulnerable", 0, 9, false],
	"vulnerable_loop": ["vulnerable", 9, 9, true],
	"vulnerable_close": ["vulnerable", 18, 3, false],
	"hurt": ["hurt", 0, 6, false],
	"death": ["death", 0, 36, false],
}

@export var max_health: float = 200.0
@export var scatter_cycles_before_vulnerable: int = 3
@export var orbs_per_scatter: int = 8
@export var scatter_speed_min: float = 280.0
@export var scatter_speed_max: float = 380.0
@export var orb_max_bounces: int = 3
@export var move_speed: float = 420.0
@export var vulnerable_duration: float = 4.0
## Animasyon uzunluklarına göre ayarlandı (scatter_telegraph 14 kare @ 12fps).
@export var scatter_telegraph_time: float = 1.17
## scatter_fire 12 kare @ 12fps.
@export var pause_after_scatter: float = 1.0
@export var charge_damage: float = 18.0
@export var contact_damage: float = 14.0
@export var charge_speed: float = 900.0
@export var charge_dash_count: int = 4
## charge_telegraph 19 kare @ 12fps.
@export var charge_telegraph_time: float = 1.58
@export var charge_dash_time: float = 0.72
@export var pause_after_charge: float = 0.75

var health: float = 200.0
var state: BossState = BossState.INTRO
var is_vulnerable: bool = false
var arena_bounds: Rect2 = Rect2(80.0, 120.0, 1760.0, 880.0)

@onready var hurtbox: Area2D = $Hurtbox
var visual_root: Node2D = null
var _sprite: AnimatedSprite2D = null
var _danger_aura: CanvasGroup = null
var _aura_sprites: Array[AnimatedSprite2D] = []
var _aura_material: ShaderMaterial = null
var _current_anim: String = ""
var _contact_active: bool = false
var _aura_phase: float = 0.0

## Temas hasarı açıkken cadının arkasında yanıp sönen tehlike halesi.
##
## Ölçekleyerek hale yapılmıyor: cadı 240x240 karenin içinde ortalanmış değil
## (idle merkez y=125, vulnerable y=147) ve ölçekleme kalınlığı merkeze uzaklıkla
## orantılı yaptığı için halka bir kenarda kalın, diğerinde ince çıkıyordu.
## Bunun yerine siluet 8 yöne sabit piksel kaydırılıp çiziliyor -> her yerde eşit kontur.
const AURA_OUTLINE_RADIUS: float = 7.0
const AURA_DIRECTIONS: Array = [
	Vector2(1.0, 0.0), Vector2(-1.0, 0.0), Vector2(0.0, 1.0), Vector2(0.0, -1.0),
	Vector2(0.7071, 0.7071), Vector2(-0.7071, 0.7071),
	Vector2(0.7071, -0.7071), Vector2(-0.7071, -0.7071),
]
const AURA_COLOR: Color = Color(1.0, 0.35, 0.18)
const AURA_COLOR_CHARGE: Color = Color(1.0, 0.12, 0.08)
const AURA_PULSE_SPEED: float = 5.0
const AURA_PULSE_SPEED_CHARGE: float = 13.0
const AURA_ALPHA_MIN: float = 0.20
const AURA_ALPHA_MAX: float = 0.60
const AURA_ALPHA_MIN_CHARGE: float = 0.55
const AURA_ALPHA_MAX_CHARGE: float = 1.0

var _attacks_done: int = 0
var _move_target: Vector2 = Vector2.ZERO
var _is_moving: bool = false
var _attack_busy: bool = false
var _last_anchor_index: int = -1
var _projectile_container: Node = null
var _fight_started: bool = false

var _is_charging: bool = false
var _charge_direction: Vector2 = Vector2.ZERO
var _charge_dashes_remaining: int = 0
var _charge_hitbox: Area2D = null
var _contact_hitbox: Area2D = null

var _anchor_points: Array[Vector2] = [
	Vector2(360.0, 260.0),
	Vector2(960.0, 200.0),
	Vector2(1560.0, 260.0),
	Vector2(1560.0, 460.0),
	Vector2(960.0, 340.0),
	Vector2(360.0, 460.0),
]


func _ready() -> void:
	if has_node("Visual"):
		visual_root = $Visual as Node2D
	add_to_group("boss")
	add_to_group("enemies")
	health = max_health
	_setup_hurtbox()
	_build_sprite_visual()
	_build_contact_hitbox()
	_health_emit_changed()


func set_projectile_container(container: Node) -> void:
	_projectile_container = container


func setup_arena(bounds: Rect2) -> void:
	arena_bounds = bounds


func start_fight() -> void:
	if _fight_started or state == BossState.DEFEATED:
		return
	_fight_started = true
	call_deferred("_start_fight")


func _setup_hurtbox() -> void:
	if not is_instance_valid(hurtbox):
		return
	if hurtbox.has_signal("hurt") and not hurtbox.hurt.is_connected(_on_hurtbox_hurt):
		hurtbox.hurt.connect(_on_hurtbox_hurt)
	_set_hurtbox_active(false)


func _process(delta: float) -> void:
	if state == BossState.DEFEATED:
		_update_danger_aura(delta)
		return
	if state == BossState.ACTIVE:
		_process_active(delta)
	elif state == BossState.VULNERABLE:
		_process_vulnerable(delta)
	_update_danger_aura(delta)


func begin_intro() -> void:
	state = BossState.INTRO
	_play("intro", true)


func finish_intro() -> void:
	if state == BossState.DEFEATED:
		return
	state = BossState.ACTIVE
	_play("idle")
	_update_contact_hitbox()


func enter_vulnerability(duration: float) -> void:
	if state == BossState.DEFEATED:
		return
	_set_contact_hitbox_active(false)
	state = BossState.VULNERABLE
	is_vulnerable = true
	_set_hurtbox_active(true)
	vulnerability_changed.emit(true)
	_play("vulnerable_open", true)

	# Açılış animasyonu bitince savunmasız döngüye geç.
	var open_timer := get_tree().create_timer(_anim_duration("vulnerable_open"))
	open_timer.timeout.connect(_on_vulnerable_open_finished)

	# Kapanış animasyonu, süre dolmadan hemen önce başlasın.
	var close_dur := _anim_duration("vulnerable_close")
	var close_at := maxf(duration - close_dur, 0.0)
	if close_at > 0.0:
		var close_timer := get_tree().create_timer(close_at)
		close_timer.timeout.connect(_on_vulnerable_close_cue)

	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(_on_vulnerability_timeout)


func _on_vulnerable_open_finished() -> void:
	if state != BossState.VULNERABLE:
		return
	if _current_anim == "vulnerable_open":
		_play("vulnerable_loop")


func _on_vulnerable_close_cue() -> void:
	if state != BossState.VULNERABLE:
		return
	_play("vulnerable_close", true)


func _on_vulnerability_timeout() -> void:
	if state != BossState.VULNERABLE:
		return
	exit_vulnerability()


func exit_vulnerability() -> void:
	if state == BossState.DEFEATED:
		return
	is_vulnerable = false
	_set_hurtbox_active(false)
	vulnerability_changed.emit(false)
	state = BossState.ACTIVE
	_play("idle")
	_begin_next_scatter_cycle()


func take_damage(amount: float, _knockback_force: float = 0.0, _knockback_up_force: float = -1.0, _apply_knockback: bool = false) -> void:
	if state == BossState.DEFEATED or not is_vulnerable:
		return

	health = maxf(0.0, health - amount)
	_health_emit_changed()
	_flash_damage()
	if health > 0.0:
		_play("hurt", true)

	var damage_number: Node = DAMAGE_NUMBER_SCENE.instantiate()
	get_tree().current_scene.add_child(damage_number)
	damage_number.global_position = global_position + Vector2(0, -70)
	if damage_number.has_method("setup"):
		damage_number.setup(int(amount))

	if health <= 0.0:
		_die()


func _on_hurtbox_hurt(hitbox: Area2D) -> void:
	if not is_vulnerable or state == BossState.DEFEATED:
		return
	if not hitbox.has_method("get_damage"):
		return

	var damage := 10.0
	if hitbox.has_method("get_damage_for_target"):
		damage = hitbox.get_damage_for_target(self)
	else:
		damage = hitbox.get_damage()

	var knockback_data: Dictionary
	if hitbox.has_method("get_knockback_data"):
		knockback_data = hitbox.get_knockback_data()
	else:
		knockback_data = {"force": 0.0, "up_force": 0.0}
	take_damage(damage, knockback_data.get("force", 0.0), knockback_data.get("up_force", -1.0), false)

	if hitbox.has_method("apply_killing_blow_effects"):
		hitbox.apply_killing_blow_effects(damage, self)


func _die() -> void:
	state = BossState.DEFEATED
	is_vulnerable = false
	_set_hurtbox_active(false)
	_set_contact_hitbox_active(false)
	_apply_vulnerable_visual(false)
	_on_defeated()
	enemy_defeated.emit()


func _health_emit_changed() -> void:
	health_changed.emit(health, max_health)


func _set_hurtbox_active(active: bool) -> void:
	if not is_instance_valid(hurtbox):
		return
	hurtbox.monitoring = active
	hurtbox.monitorable = active
	if hurtbox.has_node("CollisionShape2D"):
		hurtbox.get_node("CollisionShape2D").disabled = not active


## Savunmasızlık artık animasyonla anlatılıyor; tint yalnızca sıfırlanıyor.
func _apply_vulnerable_visual(_vulnerable: bool) -> void:
	if not is_instance_valid(visual_root):
		return
	visual_root.modulate = Color.WHITE


func _flash_damage() -> void:
	if not is_instance_valid(visual_root):
		return
	visual_root.modulate = Color(1.0, 0.4, 0.4)
	var tween := create_tween()
	tween.tween_property(visual_root, "modulate", Color.WHITE, 0.12)


func _build_sprite_visual() -> void:
	if is_instance_valid(visual_root):
		for child in visual_root.get_children():
			child.queue_free()
	else:
		visual_root = Node2D.new()
		visual_root.name = "Visual"
		add_child(visual_root)

	var textures: Dictionary = {}
	for key in SHEETS.keys():
		var tex: Texture2D = load(SPRITE_DIR + String(SHEETS[key])) as Texture2D
		if tex != null:
			textures[key] = tex

	if textures.is_empty():
		push_warning("OrbScatterBoss: witch sprite sheet'leri yüklenemedi (%s)" % SPRITE_DIR)
		return

	var frames := SpriteFrames.new()
	for anim_name in ANIMS.keys():
		var spec: Array = ANIMS[anim_name]
		var sheet_key: String = String(spec[0])
		if not textures.has(sheet_key):
			continue
		var source: Texture2D = textures[sheet_key]
		frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, bool(spec[3]))
		frames.set_animation_speed(anim_name, ANIM_FPS)
		var first: int = int(spec[1])
		for i in range(int(spec[2])):
			var atlas := AtlasTexture.new()
			atlas.atlas = source
			atlas.region = Rect2(
				float((first + i) * FRAME_SIZE), 0.0,
				float(FRAME_SIZE), float(FRAME_SIZE)
			)
			frames.add_frame(anim_name, atlas)

	if frames.has_animation("default"):
		frames.remove_animation("default")

	# modulate çarpma yaptığı için mor sprite'ı kahverengiye çevirirdi.
	# Shader, dokunun yalnızca alfasını kullanıp düz renkli bir siluet basar.
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec4 aura_color : source_color = vec4(1.0, 0.35, 0.18, 1.0);
void fragment() {
	COLOR = vec4(aura_color.rgb, texture(TEXTURE, UV).a);
}
"""
	_aura_material = ShaderMaterial.new()
	_aura_material.shader = shader

	# CanvasGroup şart: 8 kopya üst üste bindiği için normalde alfaları çarpışıp
	# nabız kaybolurdu. CanvasGroup önce hepsini tek tampona çizip modulate'i
	# sonucun tamamına bir kez uyguluyor.
	# Cadıdan ÖNCE eklenir ki arkada kalsın.
	_danger_aura = CanvasGroup.new()
	_danger_aura.name = "DangerAura"
	_danger_aura.visible = false
	visual_root.add_child(_danger_aura)

	_aura_sprites.clear()
	for dir in AURA_DIRECTIONS:
		var aura_part := AnimatedSprite2D.new()
		aura_part.sprite_frames = frames
		aura_part.centered = true
		aura_part.position = (dir as Vector2) * AURA_OUTLINE_RADIUS
		aura_part.material = _aura_material  # paylaşılan: tek parametre hepsini günceller
		_danger_aura.add_child(aura_part)
		_aura_sprites.append(aura_part)

	_sprite = AnimatedSprite2D.new()
	_sprite.name = "WitchSprite"
	_sprite.sprite_frames = frames
	_sprite.centered = true
	visual_root.add_child(_sprite)
	if not _sprite.animation_finished.is_connected(_on_animation_finished):
		_sprite.animation_finished.connect(_on_animation_finished)
	# Her karede kopyalamak haleyi bir kare geriden takip ettiriyordu; sinyalle
	# tam kare değiştiği anda senkronlanıyor.
	if not _sprite.frame_changed.is_connected(_sync_aura_frame):
		_sprite.frame_changed.connect(_sync_aura_frame)
	if not _sprite.animation_changed.is_connected(_sync_aura_frame):
		_sprite.animation_changed.connect(_sync_aura_frame)
	_play("idle")


func _sync_aura_frame() -> void:
	if not is_instance_valid(_sprite):
		return
	for aura_part in _aura_sprites:
		if not is_instance_valid(aura_part):
			continue
		if aura_part.animation != _sprite.animation:
			aura_part.animation = _sprite.animation
		aura_part.frame = _sprite.frame
		aura_part.flip_h = _sprite.flip_h


## Animasyonu oynatır. Aynı animasyon zaten seçiliyse tekrar başlatmaz —
## bu sayede _process içinden her karede güvenle çağrılabilir.
func _play(anim: String, force_restart: bool = false) -> void:
	if not is_instance_valid(_sprite) or _sprite.sprite_frames == null:
		return
	if not _sprite.sprite_frames.has_animation(anim):
		return
	if _current_anim == anim and not force_restart:
		return
	_current_anim = anim
	_sprite.play(anim)


func _anim_duration(anim: String) -> float:
	if not ANIMS.has(anim):
		return 0.0
	var spec: Array = ANIMS[anim]
	return float(int(spec[2])) / ANIM_FPS


func _on_animation_finished() -> void:
	# Hurt bitince savunmasız döngüye geri dön.
	if _current_anim == "hurt" and state == BossState.VULNERABLE:
		_play("vulnerable_loop", true)
		return
	# Top küçüldükten sonra cadı formuna geri açıl.
	if _current_anim == "charge_recover" and state == BossState.ACTIVE:
		_play("charge_unfurl", true)


## Temas hasarı açıkken nabız gibi yanıp sönen hale; charge sırasında daha hızlı ve parlak.
func _update_danger_aura(delta: float) -> void:
	if not is_instance_valid(_danger_aura) or not is_instance_valid(_sprite):
		return

	if not _contact_active:
		if _danger_aura.visible:
			_danger_aura.visible = false
		_aura_phase = 0.0
		return

	if not _danger_aura.visible:
		# Görünür olduğu ilk karede doğru poza otur.
		_sync_aura_frame()
		_danger_aura.visible = true

	_aura_phase += delta * (AURA_PULSE_SPEED_CHARGE if _is_charging else AURA_PULSE_SPEED)
	var t: float = 0.5 + 0.5 * sin(_aura_phase)

	if _aura_material:
		_aura_material.set_shader_parameter(
			"aura_color", AURA_COLOR_CHARGE if _is_charging else AURA_COLOR
		)

	# Nabız alfası CanvasGroup'un tamamına uygulanıyor, tek tek kopyalara değil.
	_danger_aura.self_modulate.a = lerpf(
		AURA_ALPHA_MIN_CHARGE if _is_charging else AURA_ALPHA_MIN,
		AURA_ALPHA_MAX_CHARGE if _is_charging else AURA_ALPHA_MAX,
		t
	)


func _face_player() -> void:
	if not is_instance_valid(_sprite):
		return
	var player_pos := _get_player_position()
	if player_pos == Vector2.INF:
		return
	if absf(player_pos.x - global_position.x) < 12.0:
		return
	_sprite.flip_h = player_pos.x < global_position.x


func _build_contact_hitbox() -> void:
	_contact_hitbox = Area2D.new()
	_contact_hitbox.set_script(ENEMY_HITBOX_SCRIPT)
	_contact_hitbox.name = "ContactHitbox"
	_contact_hitbox.damage = contact_damage
	_contact_hitbox.knockback_force = 260.0
	_contact_hitbox.knockback_up_force = 120.0
	add_child(_contact_hitbox)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 78.0
	shape.shape = circle
	_contact_hitbox.add_child(shape)
	_contact_hitbox.setup_attack("boss_contact", false, 0.0)
	_set_contact_hitbox_active(false)

	# Charge dash sırasında biraz daha geniş hitbox (aynı düğüm, boyut güncellenir).
	_charge_hitbox = _contact_hitbox


func _set_contact_hitbox_active(active: bool, use_charge_damage: bool = false) -> void:
	if not is_instance_valid(_contact_hitbox):
		return
	_contact_active = active
	if active:
		_contact_hitbox.damage = charge_damage if use_charge_damage else contact_damage
		_contact_hitbox.enable()
	else:
		_contact_hitbox.disable()


func _update_contact_hitbox() -> void:
	if state != BossState.ACTIVE or is_vulnerable:
		_set_contact_hitbox_active(false)
		return
	_set_contact_hitbox_active(true, _is_charging)


func _set_charge_hitbox_active(active: bool) -> void:
	if not is_instance_valid(_contact_hitbox):
		return
	if active:
		_contact_hitbox.damage = charge_damage
		_contact_hitbox.enable()
	else:
		_update_contact_hitbox()


func _start_fight() -> void:
	begin_intro()
	global_position = _anchor_points[2]
	var intro_timer := get_tree().create_timer(maxf(_anim_duration("intro"), 0.1))
	intro_timer.timeout.connect(_on_intro_complete)


func _on_intro_complete() -> void:
	finish_intro()
	_begin_next_scatter_cycle()


func _process_active(delta: float) -> void:
	_update_contact_hitbox()

	if _is_charging:
		return

	if _is_moving:
		global_position = global_position.move_toward(_move_target, move_speed * delta)
		if global_position.distance_to(_move_target) <= 8.0:
			global_position = _move_target
			_is_moving = false
			_on_arrived_at_anchor()

	if _attack_busy:
		return

	_face_player()
	_play("move" if _is_moving else "idle")


func _process_vulnerable(_delta: float) -> void:
	_face_player()


func _begin_next_scatter_cycle() -> void:
	if state != BossState.ACTIVE or _attack_busy:
		return
	_move_target = _pick_next_anchor()
	_is_moving = true


func _pick_next_anchor() -> Vector2:
	var index := _last_anchor_index
	while index == _last_anchor_index:
		index = randi() % _anchor_points.size()
	_last_anchor_index = index
	return _anchor_points[index]


func _on_arrived_at_anchor() -> void:
	if state != BossState.ACTIVE or _attack_busy:
		return
	if _attacks_done == 1:
		_start_charge_telegraph()
	else:
		_start_scatter_telegraph()


func _start_scatter_telegraph() -> void:
	if state != BossState.ACTIVE or _attack_busy:
		return
	_attack_busy = true
	_face_player()
	_play("scatter_telegraph", true)
	var telegraph_timer := get_tree().create_timer(scatter_telegraph_time)
	telegraph_timer.timeout.connect(_do_scatter)


func _do_scatter() -> void:
	if state != BossState.ACTIVE:
		_attack_busy = false
		return

	_play("scatter_fire", true)

	for i in range(orbs_per_scatter):
		var angle := SCATTER_ANGLE_OFFSET + TAU * float(i) / float(orbs_per_scatter)
		var direction := Vector2(cos(angle), sin(angle))
		var speed := randf_range(scatter_speed_min, scatter_speed_max)
		_spawn_orb(direction, speed)

	var pause_timer := get_tree().create_timer(pause_after_scatter)
	pause_timer.timeout.connect(_finish_attack)


func _spawn_orb(direction: Vector2, speed: float) -> void:
	var parent: Node = _projectile_container if is_instance_valid(_projectile_container) else get_tree().current_scene
	var orb: CharacterBody2D = BOUNCE_PROJECTILE_SCRIPT.new()
	parent.add_child(orb)
	orb.global_position = global_position
	if orb.has_method("setup"):
		orb.setup(direction, speed, arena_bounds, -1.0, orb_max_bounces)


func _start_charge_telegraph() -> void:
	if state != BossState.ACTIVE or _attack_busy:
		return
	_attack_busy = true
	_is_charging = true
	_charge_dashes_remaining = charge_dash_count
	_charge_direction = Vector2.ZERO

	_face_player()
	_play("charge_telegraph", true)

	var telegraph_timer := get_tree().create_timer(charge_telegraph_time)
	telegraph_timer.timeout.connect(_do_charge_dash)


func _do_charge_dash() -> void:
	if state != BossState.ACTIVE:
		_end_charge_sequence()
		return

	_charge_direction = _pick_charge_direction()
	_set_charge_hitbox_active(true)
	_play("charge_dash")

	var dash_distance := charge_speed * charge_dash_time
	var target := global_position + _charge_direction * dash_distance
	target = _clamp_to_arena(target, 72.0)

	var tween := create_tween()
	tween.tween_property(self, "global_position", target, charge_dash_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(_on_charge_dash_finished)


func _on_charge_dash_finished() -> void:
	_set_charge_hitbox_active(false)
	_charge_dashes_remaining -= 1

	if _charge_dashes_remaining <= 0 or state != BossState.ACTIVE:
		_end_charge_sequence()
		return

	# Dash'ler arasında top formunda kalır, animasyon dönmeye devam eder.
	var pause_timer := get_tree().create_timer(0.12)
	pause_timer.timeout.connect(_do_charge_dash)


func _end_charge_sequence() -> void:
	_is_charging = false
	_set_charge_hitbox_active(false)
	_play("charge_recover", true)

	# charge_recover bitince _on_animation_finished charge_unfurl'e zincirliyor;
	# bekleme ikisini birden kapsamalı, yoksa yarıda kesilip idle'a atlar.
	var return_time := _anim_duration("charge_recover") + _anim_duration("charge_unfurl")
	var pause_timer := get_tree().create_timer(maxf(pause_after_charge, return_time))
	pause_timer.timeout.connect(_finish_attack)


func _get_player_position() -> Vector2:
	for node in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(node):
			continue
		if node.has_method("is_decoy") and node.is_decoy():
			continue
		return node.global_position
	return Vector2.INF


func _pick_charge_direction() -> Vector2:
	var player_pos := _get_player_position()
	if player_pos == Vector2.INF:
		return _pick_random_cardinal_direction()

	var to_player := player_pos - global_position
	if to_player.length_squared() < 64.0:
		return _pick_random_cardinal_direction()

	var to_player_norm := to_player.normalized()
	var candidates: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	candidates.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return a.dot(to_player_norm) > b.dot(to_player_norm)
	)

	var min_travel := charge_speed * charge_dash_time * 0.3
	for dir in candidates:
		if _charge_direction != Vector2.ZERO and dir.is_equal_approx(-_charge_direction):
			continue
		if _estimate_charge_travel(dir) >= min_travel:
			return dir

	for dir in candidates:
		if _charge_direction != Vector2.ZERO and dir.is_equal_approx(-_charge_direction):
			continue
		return dir

	return _pick_random_cardinal_direction()


func _pick_random_cardinal_direction() -> Vector2:
	var options: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	if _charge_direction != Vector2.ZERO:
		options.erase(-_charge_direction)
	return options[randi() % options.size()]


func _estimate_charge_travel(dir: Vector2) -> float:
	var target := global_position + dir * charge_speed * charge_dash_time
	target = _clamp_to_arena(target, 72.0)
	return global_position.distance_to(target)


func _clamp_to_arena(point: Vector2, margin: float) -> Vector2:
	var min_x := arena_bounds.position.x + margin
	var max_x := arena_bounds.position.x + arena_bounds.size.x - margin
	var min_y := arena_bounds.position.y + margin
	var max_y := arena_bounds.position.y + arena_bounds.size.y - margin
	return Vector2(
		clampf(point.x, min_x, max_x),
		clampf(point.y, min_y, max_y)
	)


func _finish_attack() -> void:
	if state != BossState.ACTIVE:
		_attack_busy = false
		return

	_attacks_done += 1
	_attack_busy = false

	if _attacks_done >= scatter_cycles_before_vulnerable:
		_attacks_done = 0
		enter_vulnerability(vulnerable_duration)
	else:
		_begin_next_scatter_cycle()


func _on_defeated() -> void:
	_clear_projectiles()
	if is_instance_valid(visual_root):
		visual_root.modulate = Color.WHITE
		visual_root.scale = Vector2.ONE
	_play("death", true)


func _clear_projectiles() -> void:
	for node in get_tree().get_nodes_in_group("boss_projectile"):
		if is_instance_valid(node):
			node.queue_free()


