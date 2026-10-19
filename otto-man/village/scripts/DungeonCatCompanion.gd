extends Node2D

## Zindanda oyuncuyla gezen eşlikçi kedi: kendi başına yürür, koşar, zıplar, düşer ve uyur (görsel arkadaş; oyuncuyla çarpışmaz).
## Oyuncunun yakınında (aynı seviyede) serbestçe dolaşır; uzaklaşırsa ya da farklı seviyede kalırsa oyuncunun bastığı yerleri
## (iz) sırayla izler, yükseğe kendi zıplayarak çıkar. Takılırsa (ya da çok uzakta kalırsa) solarak kaybolup oyuncunun yakınında belirir.
## Tek özelliği (trait) küçük bir avantaj verir; "hunter" (Avcı) özelliği aralıklarla yakındaki bir düşmana küçük hasar vurur.
## Diğer özellikler (stat ve altın) CatCompanion autoload'u tarafından uygulanır. Kediler ölmez ve hasar almaz.

# Hareket
const GRAVITY: float = 1900.0
const WALK_SPEED: float = 150.0
const TROT_SPEED: float = 300.0
const RUN_SPEED: float = 540.0
const GROUND_ACCEL: float = 1400.0
const AIR_ACCEL: float = 500.0
const MAX_FALL: float = 1100.0
const JUMP_MAX_SPEED: float = 980.0
const STEP_JUMP_SPEED: float = 560.0          # küçük engel / boşluk için sabit zıplama
const NEAR_DX: float = 260.0                  # bu kadar yakın + aynı seviyede: serbest dolaşma
const NEAR_DY: float = 55.0
const WANDER_RANGE: float = 170.0             # oyuncunun etrafında dolaşma yarıçapı (x)
const WANDER_RETARGET_MIN: float = 2.5
const WANDER_RETARGET_MAX: float = 6.0
const WANDER_PAUSE_CHANCE: float = 0.35       # hedefe varınca bekleme ihtimali (otururken uyuyabilir)
const COME_BACK_AFTER: float = 1.2            # oyuncu bu kadar durursa kedi yanına yaklaşır
const SLEEP_AFTER_SECONDS: float = 7.0

# İz (oyuncunun yere bastığı noktalar)
const TRAIL_STEP: float = 10.0
const TRAIL_MAX: int = 160
const TRAIL_WINDOW: float = 420.0             # kedi, oyuncuya en fazla bu kadar iz uzunluğu geriden başlar (kısayol)
const REACH_DIST: float = 16.0

# Takılma ve ışınlanma
const STUCK_SECONDS: float = 2.6
const FAR_TELEPORT: float = 760.0
const FAR_DY_TELEPORT: float = 520.0
const FADE_TIME: float = 0.22

# Avcı özelliği
const HUNTER_INTERVAL_MIN: float = 6.0
const HUNTER_INTERVAL_MAX: float = 9.0
const HUNTER_RANGE: float = 190.0
const HUNTER_DAMAGE: float = 6.0
const HUNTER_KNOCKBACK: float = 90.0

var player: Node2D = null
var cat_id: String = ""
var trait_id: String = ""
## Kamp sahnesinde kedi oyuncuyu izlemez: camp_home konumunda uyur.
var camp_mode: bool = false
var camp_home: Vector2 = Vector2.ZERO

var _sprite: AnimatedSprite2D = null
var _idle_time: float = 0.0
var _hunt_timer: float = 6.0
var _hunting: bool = false
var _face: float = 1.0

var _vel: Vector2 = Vector2.ZERO
var _grounded: bool = false
var _mask: int = 1
var _trail: Array[Vector2] = []
var _wander_off: float = -60.0
var _wander_timer: float = 2.0
var _pause_left: float = 0.0
var _still_time: float = 0.0
var _last_player_pos: Vector2 = Vector2.ZERO
var _stuck_time: float = 0.0
var _best_dist: float = 0.0
var _fading: bool = false


func _ready() -> void:
	z_index = 4   # oyuncunun (z 5) hemen arkasında
	_sprite = AnimatedSprite2D.new()
	var frames: SpriteFrames = CatSpriteFrames.get_frames()
	_sprite.sprite_frames = frames
	# Çizimin görünen alt kenarı y=0'da (ayaklar zeminde) dursun; köy kedisindeki hizalamayla aynı.
	_sprite.position = Vector2(0.0, -CatSpriteFrames.visible_bottom_offset(frames))
	var roster := get_node_or_null("/root/CatRoster")
	if roster != null and roster.has_color(cat_id):
		_sprite.self_modulate = roster.get_color(cat_id)
	add_child(_sprite)
	_hunt_timer = randf_range(HUNTER_INTERVAL_MIN, HUNTER_INTERVAL_MAX)
	if camp_mode:
		global_position = camp_home
		_sprite.flip_h = camp_home.x > (player.global_position.x if player != null else camp_home.x)
		_sprite.play("sleep")
		set_physics_process(false)
		return
	_sprite.play("idle")
	_snap_to_player()


## Oyuncunun yanına yerleşir (bölüm değişince / ilk doğuşta).
func _snap_to_player() -> void:
	if player == null or not is_instance_valid(player):
		return
	_mask = int(player.get("collision_mask")) if player.get("collision_mask") != null else 1
	if _mask == 0:
		_mask = 1
	_trail.clear()
	_vel = Vector2.ZERO
	_stuck_time = 0.0
	_best_dist = 0.0
	global_position = player.global_position + Vector2(-_facing() * 40.0, 0.0)
	_last_player_pos = player.global_position
	_grounded = false


func _facing() -> float:
	if player != null and "facing_direction" in player:
		return 1.0 if float(player.get("facing_direction")) >= 0.0 else -1.0
	return 1.0


# ─── Fizik yardımcıları ─────────────────────────────────────────────────────

## Dünya çarpışmalarına ışın (oyuncunun çarpışma maskesiyle; oyuncu ve karakter gövdeleri yok sayılır).
func _ray(from: Vector2, to: Vector2) -> Dictionary:
	var q := PhysicsRayQueryParameters2D.create(from, to, _mask)
	if player is CollisionObject2D:
		q.exclude = [(player as CollisionObject2D).get_rid()]
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and hit.get("collider") is CharacterBody2D:
		return {}
	return hit


func _player_grounded() -> bool:
	if player is CharacterBody2D:
		return (player as CharacterBody2D).is_on_floor()
	return true


func _record_trail() -> void:
	if not _player_grounded():
		return
	var p: Vector2 = player.global_position
	if _trail.is_empty() or p.distance_to(_trail[_trail.size() - 1]) >= TRAIL_STEP:
		_trail.append(p)
		if _trail.size() > TRAIL_MAX:
			_trail.remove_at(0)


## İz penceresi: oyuncudan TRAIL_WINDOW iz uzunluğundan uzak eski noktalar atılır (kedi tüm yolu değil kısayolu izler).
func _trim_trail_window() -> void:
	var total: float = 0.0
	var cur: Vector2 = player.global_position
	var keep_from: int = 0
	for i in range(_trail.size() - 1, -1, -1):
		total += cur.distance_to(_trail[i])
		cur = _trail[i]
		if total > TRAIL_WINDOW:
			keep_from = i
			break
	if keep_from > 0:
		_trail = _trail.slice(keep_from)


# ─── Ana döngü ──────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		queue_free()
		return
	_record_trail()
	_update_still(delta)
	if _hunting or _fading:
		return
	var pp: Vector2 = player.global_position
	var to_player: Vector2 = pp - global_position
	# Çok uzak ya da çok farklı yükseklikte: doğal yetişilemez, solarak yanına git.
	if to_player.length() > FAR_TELEPORT or absf(to_player.y) > FAR_DY_TELEPORT:
		_fade_teleport()
		return

	var goal_x: float = global_position.x
	var goal_y: float = global_position.y
	var speed: float = WALK_SPEED
	var near: bool = absf(to_player.x) < NEAR_DX and absf(to_player.y) < NEAR_DY
	if near:
		_trail.clear()
		_update_wander(delta)
		goal_x = pp.x + _wander_off
		speed = TROT_SPEED if absf(goal_x - global_position.x) > 120.0 else WALK_SPEED
		if _pause_left > 0.0:
			_pause_left -= delta
			goal_x = global_position.x
	else:
		_trim_trail_window()
		var wp: Vector2 = _next_waypoint(pp)
		goal_x = wp.x
		goal_y = wp.y
		speed = RUN_SPEED if to_player.length() > 220.0 else TROT_SPEED

	_step_movement(delta, goal_x, goal_y, speed)
	_update_animation(delta)
	_check_stuck(delta, near)
	_update_hunter(delta)


func _update_still(delta: float) -> void:
	var p: Vector2 = player.global_position
	if p.distance_to(_last_player_pos) > 1.5:
		_still_time = 0.0
	else:
		_still_time += delta
	_last_player_pos = p


func _update_wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer > 0.0:
		return
	_wander_timer = randf_range(WANDER_RETARGET_MIN, WANDER_RETARGET_MAX)
	if _still_time > COME_BACK_AFTER:
		_wander_off = (1.0 if randf() < 0.5 else -1.0) * randf_range(50.0, 95.0)   # oyuncu durunca yakına gelir
	else:
		_wander_off = (1.0 if randf() < 0.5 else -1.0) * randf_range(40.0, WANDER_RANGE)
	if randf() < WANDER_PAUSE_CHANCE:
		_pause_left = randf_range(0.8, 2.2)


## İzde, kedinin henüz varmadığı ilk nokta; iz bittiyse oyuncunun kendisi.
func _next_waypoint(pp: Vector2) -> Vector2:
	while not _trail.is_empty() and global_position.distance_to(_trail[0]) < REACH_DIST:
		_trail.remove_at(0)
	if _trail.is_empty():
		return pp
	return _trail[0]


func _step_movement(delta: float, goal_x: float, goal_y: float, speed: float) -> void:
	var pos: Vector2 = global_position
	var dx: float = goal_x - pos.x
	var want_vx: float = 0.0
	if absf(dx) > 8.0:
		want_vx = signf(dx) * speed * clampf(absf(dx) / 40.0, 0.25, 1.0)
	var accel: float = GROUND_ACCEL if _grounded else AIR_ACCEL
	_vel.x = move_toward(_vel.x, want_vx, accel * delta)

	var dir: float = signf(_vel.x) if absf(_vel.x) > 5.0 else signf(dx)
	if _grounded and absf(want_vx) > 0.0:
		var blocked_low: bool = not _ray(pos + Vector2(0, -8), pos + Vector2(dir * 16.0, -8)).is_empty()
		var blocked_high: bool = not _ray(pos + Vector2(0, -44), pos + Vector2(dir * 16.0, -44)).is_empty()
		var ground_ahead: bool = not _ray(pos + Vector2(dir * 18.0, -6), pos + Vector2(dir * 18.0, 70)).is_empty()
		var higher: float = pos.y - goal_y   # > 0: hedef daha yukarıda
		if blocked_low and not blocked_high:
			_jump(STEP_JUMP_SPEED)                       # küçük basamak / engel
		elif blocked_low and blocked_high:
			if higher > 24.0:
				_jump(minf(sqrt(2.0 * GRAVITY * (higher + 50.0)), JUMP_MAX_SPEED))   # yüksek duvar: hedef yukarıdaysa zıpla
			else:
				_vel.x = 0.0
		elif not ground_ahead and higher > -30.0:
			_jump(minf(STEP_JUMP_SPEED + maxf(higher, 0.0) * 1.2, JUMP_MAX_SPEED))   # boşluk: karşıya zıpla
	# Hedef tam üstteyse (yatay yakın, yukarıda): zıpla.
	var ceiling_free: bool = _ray(pos + Vector2(0, -30), pos + Vector2(0, -150)).is_empty()
	if _grounded and ceiling_free and goal_y < pos.y - 28.0 and absf(dx) < 110.0:
		_jump(minf(sqrt(2.0 * GRAVITY * (pos.y - goal_y + 50.0)), JUMP_MAX_SPEED))

	_vel.y = minf(_vel.y + GRAVITY * delta, MAX_FALL)
	var new_pos: Vector2 = pos + _vel * delta

	# Yatay engel
	if absf(_vel.x) > 1.0:
		var side: float = signf(_vel.x)
		if not _ray(pos + Vector2(0, -10), Vector2(new_pos.x + side * 8.0, pos.y - 10.0)).is_empty():
			new_pos.x = pos.x
			_vel.x = 0.0
	# Tavan
	if _vel.y < 0.0 and not _ray(pos + Vector2(0, -30), Vector2(new_pos.x, new_pos.y - 34.0)).is_empty():
		_vel.y = 0.0
		new_pos.y = pos.y
	# Zemin
	_grounded = false
	if _vel.y >= 0.0:
		var hit: Dictionary = _ray(Vector2(new_pos.x, pos.y - 8.0), Vector2(new_pos.x, new_pos.y + 2.0))
		if not hit.is_empty():
			new_pos.y = float((hit["position"] as Vector2).y)
			_vel.y = 0.0
			_grounded = true
	global_position = new_pos


func _jump(v: float) -> void:
	if not _grounded:
		return
	_vel.y = -v
	_grounded = false


func _check_stuck(delta: float, near: bool) -> void:
	# Hedefe doğru hareket etmiyorsa (yakın dolaşmada beklemek normal) takılmış sayılır.
	if near:
		_stuck_time = 0.0
		_best_dist = 0.0
		return
	# İlerleme = oyuncuya yaklaşma; zıplayıp aynı yerde dönmek (örn. tavan altında) ilerleme sayılmaz.
	var d: float = global_position.distance_to(player.global_position)
	if d < _best_dist - 30.0 or _best_dist <= 0.0:
		_best_dist = d
		_stuck_time = 0.0
		return
	_stuck_time += delta
	if _stuck_time > STUCK_SECONDS:
		_fade_teleport()


## Solarak kaybol, oyuncunun yakınındaki yere basılmış bir noktada solarak belir (havada ışınlanma görünmez).
func _fade_teleport() -> void:
	if _fading:
		return
	_fading = true
	var dest: Vector2 = player.global_position + Vector2(-_facing() * 44.0, 0.0)
	var hit: Dictionary = _ray(dest + Vector2(0, -30), dest + Vector2(0, 90))
	if hit.is_empty():
		dest = player.global_position   # yan nokta havadaysa oyuncunun tam yeri
	else:
		dest = hit["position"]
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate:a", 0.0, FADE_TIME)
	tw.tween_callback(func() -> void:
		global_position = dest
		_vel = Vector2.ZERO
		_trail.clear()
		_stuck_time = 0.0
		_best_dist = 0.0
		_grounded = false
	)
	tw.tween_property(_sprite, "modulate:a", 1.0, FADE_TIME)
	tw.tween_callback(func() -> void: _fading = false)


func _update_animation(delta: float) -> void:
	var speed_x: float = absf(_vel.x)
	if speed_x > 6.0:
		_face = signf(_vel.x)
	elif player != null and is_instance_valid(player):
		var d: float = player.global_position.x - global_position.x
		if absf(d) > 6.0:
			_face = signf(d)
	_sprite.flip_h = _face < 0.0
	var anim: StringName = &"idle"
	if not _grounded:
		anim = &"jump_up" if _vel.y < 0.0 else &"jump_down"
	elif speed_x > 250.0:
		anim = &"run"
	elif speed_x > 20.0:
		anim = &"walk"
	else:
		_idle_time += delta
		if _idle_time > SLEEP_AFTER_SECONDS:
			anim = &"sleep"
	if speed_x > 20.0 or not _grounded:
		_idle_time = 0.0
	if _sprite.sprite_frames.has_animation(anim) and _sprite.animation != anim:
		_sprite.play(anim)


# ─── Avcı özelliği ───────────────────────────────────────────────────────────

func _update_hunter(delta: float) -> void:
	if trait_id != "hunter":
		return
	_hunt_timer -= delta
	if _hunt_timer > 0.0:
		return
	_hunt_timer = randf_range(HUNTER_INTERVAL_MIN, HUNTER_INTERVAL_MAX)
	var enemy: Node2D = _nearest_enemy()
	if enemy != null:
		_pounce(enemy)


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d: float = HUNTER_RANGE
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node2D) or not is_instance_valid(e) or not (e as Node2D).visible:
			continue
		if not e.has_method("take_damage"):
			continue
		var d: float = global_position.distance_to((e as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


## Düşmana atılır, küçük hasar vurur ve olduğu yere döner.
func _pounce(enemy: Node2D) -> void:
	_hunting = true
	_sprite.play("run" if _sprite.sprite_frames.has_animation("run") else "walk")
	var start: Vector2 = global_position
	var hit_pos: Vector2 = enemy.global_position + Vector2(-signf(enemy.global_position.x - start.x) * 14.0, 0.0)
	_sprite.flip_h = enemy.global_position.x < start.x
	var tw := create_tween()
	tw.tween_property(self, "global_position", hit_pos, 0.16)
	tw.tween_callback(func() -> void:
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			enemy.call("take_damage", HUNTER_DAMAGE, HUNTER_KNOCKBACK)
	)
	tw.tween_property(self, "global_position", start, 0.22)
	tw.tween_callback(func() -> void:
		_hunting = false
		_vel = Vector2.ZERO
	)
