class_name HunterEnemy
extends "res://enemy/base_enemy.gd"

## Avcı: oyuncuyu gören, tile ve one-way platformları tanıyıp zıplayarak/atlayarak/inerek peşinden giden,
## yeterince hızlı kaçılırsa izini kaybeden akıllı takipçi. Gezinme HunterNav'dadır (bkz. hunter_nav.gd).

const NavScript = preload("res://enemy/hunter/hunter_nav.gd")

@export var default_stats: EnemyStats = preload("res://enemy/hunter/hunter_enemy_stats.tres")

@onready var terrain_detection = $TerrainDetection
@onready var wall_ray_left = $TerrainDetection/WallRayCastLeft
@onready var wall_ray_right = $TerrainDetection/WallRayCastRight
@onready var ledge_ray_left = $TerrainDetection/LedgeRayCastLeft
@onready var ledge_ray_right = $TerrainDetection/LedgeRayCastRight

# Hareket (HunterNav ile aynı sayılar: simüle edilen yaylar bunlarla yürütülür)
const GRAV := 1960.0
const MAX_FALL := 900.0
const JUMP_SPEED := 920.0
const AIR_MAX := 340.0
const FEET_OFF := 26.0   # orijin ile ayak arası (kapsül yüksekliği/2 - ofset)
const BASE_MASK := 517   # dünya + düşman + platform

# Algı
const NEAR_NOTICE := 150.0
const LOSE_DISTANCE_MULT := 1.6
const LOSE_TIME_BLIND := 4.5
const SEARCH_LINGER := 2.6
const SEARCH_MAX := 9.0

# Saldırı (atılma)
const LUNGE_TRIGGER_X := 170.0
const LUNGE_TRIGGER_Y := 90.0
const WINDUP_TIME := 0.3
const LUNGE_SPEED := 520.0
const LUNGE_UP := 340.0
const LUNGE_MAX_TIME := 0.9
const RECOVER_TIME := 0.55
const LUNGE_COOLDOWN := 1.6
const LUNGE_DAMAGE_MULT := 1.1

# Taktikler: blok, geri adım, geri koşup atılma
const GUARD_TIME := 0.65
const GUARD_COOLDOWN := 2.2
const GUARD_REACT_CHANCE := 0.55
const GUARD_CONTACT_RANGE := 210.0
const BACKSTEP_SPEED := 300.0
const BACKSTEP_UP := 330.0
const BACKSTEP_COOLDOWN := 2.4
const RETREAT_TIME := 0.8
const RETREAT_MIN_TIME := 0.35
const FAR_LEAP_UP := 520.0
const FAR_LEAP_SPEED := 640.0
const TACTIC_COOLDOWN := 3.0
const TACTIC_ROLL_INTERVAL := 0.4

const WALK := 0
const JUMP := 1
const DROP := 2
const DROPTHRU := 3

var nav: RefCounted = null
var path: Array = []
var path_i: int = 0
var nav_cd: float = 0.0
var move_state: String = "ground"   # ground | air
var air_t: float = 0.0
var air_edge: Dictionary = {}
var jump_cd: float = 0.0
var lunge_cd: float = 0.0
var patrol_origin: Vector2 = Vector2.ZERO
var patrol_dir: float = 1.0
var patrol_pause: float = 0.0
var last_known_pos: Vector2 = Vector2.ZERO
var lose_timer: float = 0.0
var search_timer: float = 0.0
var search_arrived: bool = false
var target_cache_t: float = 0.0
var stuck_t: float = 0.0
var stuck_ref: Vector2 = Vector2.ZERO
var stuck_count: int = 0
var _thru_active: bool = false
var _thru_y: float = 0.0
var _thru_t: float = 0.0
var _lunge_dir: float = 1.0
var _windup_time: float = WINDUP_TIME
var _far_next: bool = false
var guard_cd: float = 0.0
var tactic_cd: float = 0.0
var tactic_roll_t: float = 0.0
var counter_ready: bool = false
var guard_blocked_at: float = -1.0
var _player_was_attacking: bool = false
var _shape_radius: float = 13.0
var _shape_height: float = 56.0


func _ready() -> void:
	sleep_distance = 1700.0
	wake_distance = 1600.0
	if not stats:
		stats = default_stats
	super._ready()
	_ensure_extra_animations()
	collision_layer = 4
	collision_mask = BASE_MASK
	for ray in $TerrainDetection.get_children():
		if ray is RayCast2D:
			ray.collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM
			ray.enabled = true
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs and cs.shape is CapsuleShape2D:
		_shape_radius = (cs.shape as CapsuleShape2D).radius
		_shape_height = (cs.shape as CapsuleShape2D).height
	if hitbox:
		if not hitbox.is_in_group("hitbox"):
			hitbox.add_to_group("hitbox")
		if hitbox.has_method("disable"):
			hitbox.disable()
	patrol_origin = global_position
	stuck_ref = global_position
	if sprite:
		sprite.play("idle")
	current_behavior = "idle"


## Sahnede olmayan animasyonlar: base die()/hurt bunları çağırır, eksikse hata basar.
func _ensure_extra_animations() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var sf: SpriteFrames = sprite.sprite_frames
	for nm in ["death", "hurt"]:
		if sf.has_animation(nm):
			continue
		sf.add_animation(nm)
		sf.set_animation_loop(nm, false)
		sf.set_animation_speed(nm, 8.0)
		if sf.get_frame_count("fall") > 0:
			sf.add_frame(nm, sf.get_frame_texture("fall", 0))


func _ensure_nav() -> void:
	if nav == null:
		nav = NavScript.new(self, GRAV, JUMP_SPEED, AIR_MAX, maxf(stats.chase_speed, 120.0),
				FEET_OFF, _shape_radius, _shape_height)


# --- Fizik döngüsü ----------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if global_position == Vector2.ZERO:
		return
	if current_behavior == "dead":
		super._physics_process(delta)
		return
	if _stun_lock_reset_timer > 0.0:
		_stun_lock_reset_timer = maxf(0.0, _stun_lock_reset_timer - delta)
		if _stun_lock_reset_timer <= 0.0:
			_stun_lock_hit_count = 0
	jump_cd = maxf(0.0, jump_cd - delta)
	lunge_cd = maxf(0.0, lunge_cd - delta)
	guard_cd = maxf(0.0, guard_cd - delta)
	tactic_cd = maxf(0.0, tactic_cd - delta)
	_update_thru(delta)
	if not is_on_floor():
		var g_scale := 1.0
		if current_behavior == "hurt" and air_float_timer > 0.0:
			g_scale = air_float_gravity_scale
			air_float_timer = maxf(0.0, air_float_timer - delta)
		velocity.y = minf(velocity.y + GRAV * g_scale * delta, MAX_FALL)
	if frost_stacks > 0:
		velocity.x *= get_frost_speed_multiplier()
	move_and_slide()
	if not is_sleeping:
		handle_behavior(delta)


func _update_thru(delta: float) -> void:
	if not _thru_active:
		return
	_thru_t += delta
	if global_position.y + FEET_OFF > _thru_y or _thru_t > 0.6:
		_thru_active = false
		collision_mask = BASE_MASK


func handle_behavior(delta: float) -> void:
	if is_sleeping:
		return
	if faint_timer > 0.0:
		_process_faint(delta)
		return
	behavior_timer += delta
	_refresh_target(delta)
	match current_behavior:
		"idle":
			_tick_idle(delta)
		"patrol":
			_tick_patrol(delta)
		"chase":
			_tick_chase(delta)
		"search":
			_tick_search(delta)
		"guard":
			_tick_guard(delta)
		"backstep":
			_tick_backstep(delta)
		"retreat":
			_tick_retreat(delta)
		"windup":
			_tick_windup(delta)
		"lunge":
			_tick_lunge(delta)
		"recover":
			_tick_recover(delta)
		"hurt":
			_tick_hurt(delta)
	_update_anim()


func change_behavior(new_behavior: String, force: bool = false) -> void:
	if current_behavior == "dead" and not force:
		return
	if current_behavior == "guard" and new_behavior != "guard" and sprite:
		sprite.modulate = Color(1, 1, 1, 1)
	if (current_behavior == "lunge" or current_behavior == "windup") and new_behavior != "lunge" \
			and hitbox and hitbox.has_method("disable"):
		hitbox.disable()
	current_behavior = new_behavior
	behavior_timer = 0.0


# --- Algı ---------------------------------------------------------------------------------------

func _refresh_target(delta: float) -> void:
	target_cache_t -= delta
	if target_cache_t > 0.0 and target != null and is_instance_valid(target):
		return
	target_cache_t = 0.15
	target = get_nearest_player()


func _aggro_forced() -> bool:
	return has_meta("always_aggro")


func _eye_pos() -> Vector2:
	return global_position + Vector2(0.0, -22.0)


func _has_los(to: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(_eye_pos(), to)
	q.collision_mask = CollisionLayers.WORLD
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _can_notice(p: Node2D) -> bool:
	if _aggro_forced():
		return true
	var d: float = global_position.distance_to(p.global_position)
	if d > stats.detection_range:
		return false
	if d <= NEAR_NOTICE:
		return true
	return _has_los(p.global_position + Vector2(0.0, -20.0))


func _notice_check() -> bool:
	if target != null and is_instance_valid(target) and _can_notice(target):
		last_known_pos = target.global_position
		lose_timer = 0.0
		change_behavior("chase")
		path.clear()
		nav_cd = 0.0
		return true
	return false


# --- Boşta / devriye / arama --------------------------------------------------------------------

func _tick_idle(delta: float) -> void:
	_brake(delta)
	if _notice_check():
		return
	if behavior_timer > 1.0:
		change_behavior("patrol")
		patrol_dir = -patrol_dir if randf() < 0.5 else patrol_dir


func _tick_patrol(delta: float) -> void:
	if _notice_check():
		return
	if patrol_pause > 0.0:
		patrol_pause -= delta
		_brake(delta)
		return
	if not is_on_floor():
		return
	var dist_from_origin: float = global_position.x - patrol_origin.x
	if absf(dist_from_origin) > 260.0 and signf(dist_from_origin) == patrol_dir:
		patrol_dir = -patrol_dir
		patrol_pause = 0.8
	var wall: bool = wall_ray_right.is_colliding() if patrol_dir > 0.0 else wall_ray_left.is_colliding()
	var ledge: bool = (not ledge_ray_right.is_colliding()) if patrol_dir > 0.0 else (not ledge_ray_left.is_colliding())
	if wall or ledge:
		patrol_dir = -patrol_dir
		patrol_pause = 0.7
		return
	_walk_dir(patrol_dir, stats.movement_speed)


func _tick_search(delta: float) -> void:
	if _notice_check():
		return
	search_timer += delta
	if search_timer > SEARCH_MAX:
		_give_up()
		return
	if not search_arrived:
		var arrived: bool = absf(global_position.x - last_known_pos.x) < 40.0 and absf(global_position.y - last_known_pos.y) < 120.0
		if arrived:
			search_arrived = true
			behavior_timer = 0.0
		else:
			_navigate_to(last_known_pos, delta)
			return
	_brake(delta)
	if behavior_timer > SEARCH_LINGER:
		_give_up()


func _give_up() -> void:
	patrol_origin = global_position
	path.clear()
	change_behavior("patrol")
	patrol_pause = 1.0


func _brake(delta: float) -> void:
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, 1800.0 * delta)


# --- Takip ---------------------------------------------------------------------------------------

func _tick_chase(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		_start_search()
		return
	var tp: Vector2 = target.global_position
	var dist: float = global_position.distance_to(tp)
	if not _aggro_forced():
		var visible: bool = dist <= NEAR_NOTICE or _has_los(tp + Vector2(0.0, -20.0))
		if visible and dist <= stats.detection_range * LOSE_DISTANCE_MULT:
			last_known_pos = tp
			lose_timer = 0.0
		else:
			lose_timer += delta
			if dist > stats.detection_range * LOSE_DISTANCE_MULT:
				lose_timer += delta * 1.5
		if lose_timer > LOSE_TIME_BLIND:
			_start_search()
			return
	else:
		last_known_pos = tp
	if move_state == "ground" and _combat_tactics(tp, delta):
		return
	if move_state == "ground" and _can_lunge(tp):
		_start_windup(tp)
		return
	_navigate_to(_goal_surface(), delta)


func _start_search() -> void:
	search_timer = 0.0
	search_arrived = false
	path.clear()
	nav_cd = 0.0
	change_behavior("search")


func _can_lunge(tp: Vector2) -> bool:
	if lunge_cd > 0.0 or not is_on_floor() or _thru_active:
		return false
	var dx: float = tp.x - global_position.x
	var dy: float = tp.y - global_position.y
	if absf(dx) > LUNGE_TRIGGER_X or absf(dy) > LUNGE_TRIGGER_Y:
		return false
	return _has_los(tp + Vector2(0.0, -20.0))


## Hedefin ayağının bastığı yüzey; oyuncu koşuyorsa biraz ilerisine nişan alır (yolunu kesmeye çalışır).
func _goal_surface() -> Vector2:
	var p: Vector2 = target.global_position
	var lead: float = 0.0
	if target is CharacterBody2D:
		var tb := target as CharacterBody2D
		if tb.is_on_floor():
			lead = clampf(tb.velocity.x * 0.45, -180.0, 180.0)
	for off in [lead, 0.0]:
		var hit: Variant = _ray_down(Vector2(p.x + off, p.y - 10.0), 700.0)
		if hit != null:
			return hit
	return p


func _ray_down(from: Vector2, length: float) -> Variant:
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, length))
	q.collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM
	var r: Dictionary = get_world_2d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return null
	return r["position"]


## Hedef yüzeye gitmek için gezinme grafiğini günceller ve rotayı yürütür.
func _navigate_to(goal_surf: Vector2, delta: float) -> void:
	_ensure_nav()
	var feet: Vector2 = global_position + Vector2(0.0, FEET_OFF)
	nav_cd -= delta
	var x0: float = minf(feet.x, goal_surf.x)
	var x1: float = maxf(feet.x, goal_surf.x)
	var y0: float = minf(feet.y, goal_surf.y)
	var y1: float = maxf(feet.y, goal_surf.y)
	var ready: bool = nav.ensure_columns(x0 - 480.0, x1 + 480.0, y0 - 620.0, y1 + 620.0, 30)
	if nav.search_state == NavScript.Search.SEARCHING:
		nav.step(1500)
	if nav.search_state == NavScript.Search.FOUND:
		_adopt_path(nav.result_path)
		nav.search_state = NavScript.Search.IDLE
	elif nav.search_state == NavScript.Search.FAILED:
		nav.search_state = NavScript.Search.IDLE
		path.clear()
	elif nav.search_state == NavScript.Search.IDLE and nav_cd <= 0.0 and ready and move_state == "ground":
		var start = nav.nearest_node(feet, 48.0)
		var goal = nav.nearest_node(goal_surf, 96.0)
		if start != null and goal != null:
			nav.begin_search(start, goal)
			nav_cd = 0.4
	_stuck_tick(delta)
	if move_state == "air":
		_tick_air(delta)
		return
	if not _follow_path(delta):
		_simple_chase(goal_surf, delta)


func _adopt_path(edges: Array) -> void:
	# Ardışık yürü kenarlarını tek hamlede birleştir
	var merged: Array = []
	for e in edges:
		if int(e["kind"]) == WALK and not merged.is_empty() and int(merged.back()["kind"]) == WALK:
			var m: Dictionary = merged.back().duplicate()
			m["to"] = e["to"]
			merged[merged.size() - 1] = m
		else:
			merged.append(e)
	path = merged
	_resync_path()


## Rota içinde şu anki konuma en yakın hamleden devam et.
func _resync_path() -> void:
	path_i = 0
	if path.is_empty():
		return
	var feet: Vector2 = global_position + Vector2(0.0, FEET_OFF)
	var best_d: float = INF
	for i in path.size():
		var d: float = feet.distance_to(path[i]["from"].surf)
		if d < best_d:
			best_d = d
			path_i = i


func _follow_path(delta: float) -> bool:
	if path_i >= path.size():
		return false
	var e: Dictionary = path[path_i]
	var to = e["to"]
	var from = e["from"]
	var speed: float = stats.chase_speed
	match int(e["kind"]):
		WALK:
			var dx: float = to.pos.x - global_position.x
			if absf(dx) <= 6.0:
				path_i += 1
				return _follow_path(delta)
			_walk_dir(signf(dx), speed)
		JUMP:
			var dxj: float = from.pos.x - global_position.x
			if absf(dxj) > 5.0:
				_walk_dir(signf(dxj), clampf(absf(dxj) * 10.0, 40.0, speed))
			elif is_on_floor() and jump_cd <= 0.0:
				_launch(e, Vector2(float(e["vx"]), -JUMP_SPEED))
		DROP:
			var dxd: float = from.pos.x - global_position.x
			var out_dir: float = signf(float(e["vx"]))
			if absf(dxd) > 5.0 and signf(dxd) != out_dir:
				_walk_dir(signf(dxd), clampf(absf(dxd) * 10.0, 40.0, speed))
			else:
				_walk_dir(out_dir, maxf(absf(float(e["vx"])), 80.0))
				if not is_on_floor():
					_enter_air(e)
		DROPTHRU:
			var dxt: float = from.pos.x - global_position.x
			if absf(dxt) > 5.0:
				_walk_dir(signf(dxt), clampf(absf(dxt) * 10.0, 40.0, speed))
			elif is_on_floor():
				_thru_active = true
				_thru_t = 0.0
				_thru_y = from.surf.y + 34.0
				collision_mask = BASE_MASK & ~CollisionLayers.WORLD
				velocity = Vector2(float(e["vx"]), 120.0)
				_enter_air(e)
	return true


func _launch(e: Dictionary, v: Vector2) -> void:
	velocity = v
	jump_cd = 0.25
	_enter_air(e)
	_face(signf(v.x))


func _enter_air(e: Dictionary) -> void:
	move_state = "air"
	air_t = 0.0
	air_edge = e


func _tick_air(delta: float) -> void:
	air_t += delta
	if air_edge.is_empty():
		move_state = "ground"
		return
	var to = air_edge["to"]
	var t_total: float = float(air_edge["t"])
	if velocity.y > 0.0 or int(air_edge["kind"]) != JUMP:
		var t_left: float = maxf(t_total - air_t, 0.12)
		velocity.x = clampf((to.pos.x - global_position.x) / t_left, -AIR_MAX, AIR_MAX)
	if absf(velocity.x) > 10.0:
		_face(signf(velocity.x))
	if is_on_floor() and air_t > 0.12:
		_land()
	elif air_t > 3.0:
		_land()


func _land() -> void:
	move_state = "ground"
	var e: Dictionary = air_edge
	air_edge = {}
	velocity.x = 0.0
	var feet: Vector2 = global_position + Vector2(0.0, FEET_OFF)
	var node = nav.nearest_node(feet, 40.0) if nav != null else null
	if not e.is_empty() and node != null and nav.same_run(node, e["to"]):
		_resync_path()
		# Yeni konumdan sonraki hamle: inilen koşunun to'su ile eşleşen kenarın ardı
		for i in path.size():
			if path[i] == e:
				path_i = i + 1
				break
	else:
		path.clear()
		nav_cd = 0.0


## Rota yokken ya da bitince: hedefe doğru basit yürüyüş (duvarda zıpla, uçuruma kendini atma).
func _simple_chase(goal_surf: Vector2, delta: float) -> void:
	if target == null or not is_instance_valid(target):
		_brake(delta)
		return
	var dx: float = goal_surf.x - global_position.x
	if absf(dx) < 30.0:
		_brake(delta)
		return
	var dir: float = signf(dx)
	var wall: bool = wall_ray_right.is_colliding() if dir > 0.0 else wall_ray_left.is_colliding()
	var ledge: bool = (not ledge_ray_right.is_colliding()) if dir > 0.0 else (not ledge_ray_left.is_colliding())
	if ledge and goal_surf.y < global_position.y + FEET_OFF + 60.0 and is_on_floor():
		velocity.x = 0.0
		_face(dir)
		return
	_walk_dir(dir, stats.chase_speed * 0.9)
	if wall and is_on_floor() and jump_cd <= 0.0:
		velocity.y = -JUMP_SPEED * 0.9
		jump_cd = 0.5


func _stuck_tick(delta: float) -> void:
	stuck_t += delta
	if stuck_t < 0.5:
		return
	stuck_t = 0.0
	var moved: float = global_position.distance_to(stuck_ref)
	stuck_ref = global_position
	if move_state == "ground" and moved < 8.0 and current_behavior in ["chase", "search"]:
		stuck_count += 1
	else:
		stuck_count = 0
	if stuck_count >= 2:
		stuck_count = 0
		path.clear()
		nav_cd = 0.0
		if is_on_floor():
			velocity.y = -JUMP_SPEED * 0.8
			velocity.x = patrol_dir * AIR_MAX * 0.5
			patrol_dir = -patrol_dir


# --- Atılma saldırısı -------------------------------------------------------------------------------

# --- Dövüş taktikleri: blok, geri adım, geri koşup atılma ---------------------------------------

func _player_attacking(p: Node) -> bool:
	var sm: Node = p.get_node_or_null("StateMachine")
	if sm == null or sm.get("current_state") == null:
		return false
	return String(sm.current_state.name).containsn("attack")


func _clear_behind(dir: float) -> bool:
	# dir: gitmek istenen yön; önünde zemin var, duvar yok
	var wall: bool = wall_ray_right.is_colliding() if dir > 0.0 else wall_ray_left.is_colliding()
	var ground: bool = ledge_ray_right.is_colliding() if dir > 0.0 else ledge_ray_left.is_colliding()
	return ground and not wall


## Yakın dövüşte taktik seçer; bir taktik başlattıysa true döner.
func _combat_tactics(tp: Vector2, delta: float) -> bool:
	if not is_on_floor() or _thru_active:
		return false
	var dx: float = tp.x - global_position.x
	var adx: float = absf(dx)
	var dy: float = absf(tp.y - global_position.y)
	if dy > LUNGE_TRIGGER_Y + 20.0 or adx > 330.0:
		_player_was_attacking = false
		return false
	var atk: bool = _player_attacking(target)
	var atk_started: bool = atk and not _player_was_attacking
	_player_was_attacking = atk
	var away: float = -signf(dx) if dx != 0.0 else -float(direction)
	# 1) Oyuncu saldırıya geçti: blokla ya da geri adımla kaç
	if atk_started and adx <= GUARD_CONTACT_RANGE:
		if guard_cd <= 0.0 and randf() < GUARD_REACT_CHANCE:
			_start_guard(dx)
			return true
		if tactic_cd <= 0.0 and adx <= 150.0 and _clear_behind(away) and randf() < 0.45:
			_start_backstep(away, dx)
			return true
	# 2) Sakin anlarda arada bir geri adım ya da geri koşup atılma
	tactic_roll_t -= delta
	if tactic_roll_t <= 0.0:
		tactic_roll_t = TACTIC_ROLL_INTERVAL
		if tactic_cd <= 0.0 and _has_los(tp + Vector2(0.0, -20.0)):
			if adx <= 140.0 and _clear_behind(away) and randf() < 0.22:
				_start_backstep(away, dx)
				return true
			if adx > 100.0 and adx <= 330.0 and _clear_behind(away) and randf() < 0.3:
				_start_retreat(away)
				return true
	return false


func _start_guard(dx: float) -> void:
	_face(signf(dx))
	velocity.x = 0.0
	guard_blocked_at = -1.0
	counter_ready = false
	change_behavior("guard")
	if sprite:
		sprite.modulate = Color(0.75, 0.9, 1.25, 1.0)


func _tick_guard(delta: float) -> void:
	_brake(delta)
	if target != null and is_instance_valid(target):
		_face(signf(target.global_position.x - global_position.x))
	var done: bool = behavior_timer >= GUARD_TIME
	if guard_blocked_at >= 0.0 and behavior_timer >= guard_blocked_at + 0.25:
		done = true
	if done:
		_end_guard()


func _end_guard() -> void:
	guard_cd = GUARD_COOLDOWN
	if sprite:
		sprite.modulate = Color(1, 1, 1, 1)
	var counter: bool = counter_ready
	counter_ready = false
	if counter and target != null and is_instance_valid(target) \
			and absf(target.global_position.x - global_position.x) <= 240.0:
		lunge_cd = 0.0
		_start_windup(target.global_position, 0.14)
	else:
		change_behavior("chase")


## Önden gelen hafif vuruşu bloklar; ağır vuruş korumayı kırar (azaltılmış hasar), arkadan vuruş geçer.
func take_damage(amount: float, knockback_force: float = 200.0, knockback_up_force: float = -1.0, apply_knockback: bool = true) -> void:
	if current_behavior == "guard" and apply_knockback and target != null and is_instance_valid(target):
		var in_front: bool = signf(target.global_position.x - global_position.x) == float(direction)
		if in_front:
			if _is_heavy_attack_name(_pending_attack_name):
				amount *= 0.6
				if sprite:
					sprite.modulate = Color(1, 1, 1, 1)
				change_behavior("chase")
				guard_cd = GUARD_COOLDOWN
			else:
				_pending_attack_name = ""
				velocity.x = -float(direction) * 150.0
				guard_blocked_at = behavior_timer
				counter_ready = true
				if sprite:
					sprite.modulate = Color(1.6, 1.6, 2.0, 1.0)
					create_tween().tween_property(sprite, "modulate", Color(0.75, 0.9, 1.25, 1.0), 0.15)
				_play_enemy_sfx("enemy_hurt")
				return
	super.take_damage(amount, knockback_force, knockback_up_force, apply_knockback)


func _start_backstep(away: float, dx: float) -> void:
	tactic_cd = BACKSTEP_COOLDOWN
	_face(-away)   # oyuncuya bakarak geri sıçrar
	velocity = Vector2(away * BACKSTEP_SPEED, -BACKSTEP_UP)
	change_behavior("backstep")


func _tick_backstep(_delta: float) -> void:
	if target != null and is_instance_valid(target):
		_face(signf(target.global_position.x - global_position.x))
	if is_on_floor() and behavior_timer > 0.12:
		velocity.x = 0.0
		if target != null and is_instance_valid(target) and randf() < 0.6:
			lunge_cd = 0.0
			_start_windup(target.global_position, 0.12)
		else:
			change_behavior("chase")


func _start_retreat(away: float) -> void:
	tactic_cd = TACTIC_COOLDOWN
	_walk_dir(away, stats.chase_speed)
	change_behavior("retreat")


func _tick_retreat(_delta: float) -> void:
	if target == null or not is_instance_valid(target):
		change_behavior("chase")
		return
	var dx: float = target.global_position.x - global_position.x
	var away: float = -signf(dx) if dx != 0.0 else -float(direction)
	var blocked: bool = not _clear_behind(away)
	if blocked or behavior_timer >= RETREAT_TIME or (behavior_timer >= RETREAT_MIN_TIME and absf(dx) > 330.0):
		# Dön ve uzun bir sıçrayışla atıl
		if absf(dx) <= 520.0 and is_on_floor():
			lunge_cd = 0.0
			_start_windup(target.global_position, 0.16, true)
		else:
			change_behavior("chase")
		return
	_walk_dir(away, stats.chase_speed)


func _start_windup(tp: Vector2, wind: float = WINDUP_TIME, far: bool = false) -> void:
	_windup_time = wind
	_far_next = far
	_lunge_dir = signf(tp.x - global_position.x)
	if _lunge_dir == 0.0:
		_lunge_dir = 1.0
	_face(_lunge_dir)
	velocity.x = 0.0
	change_behavior("windup")
	if sprite:
		create_tween().tween_property(sprite, "scale:y", 0.82, _windup_time * 0.9)


func _tick_windup(delta: float) -> void:
	_brake(delta)
	if target != null and is_instance_valid(target):
		var d: float = signf(target.global_position.x - global_position.x)
		if d != 0.0:
			_lunge_dir = d
			_face(d)
	if behavior_timer >= _windup_time:
		if sprite:
			sprite.scale.y = 1.0
		_start_lunge()


func _start_lunge() -> void:
	change_behavior("lunge")
	# Havada kalma süresine göre hedefi çok aşmayacak yatay hız (hedefin biraz ötesine iner)
	var reach: float = LUNGE_TRIGGER_X * 0.6
	if target != null and is_instance_valid(target):
		reach = absf(target.global_position.x - global_position.x) + 50.0
	var up: float = FAR_LEAP_UP if _far_next else LUNGE_UP
	var max_speed: float = FAR_LEAP_SPEED if _far_next else LUNGE_SPEED
	var air_time: float = 2.0 * up / GRAV
	velocity = Vector2(_lunge_dir * clampf(reach / air_time, 220.0, max_speed), -up)
	if hitbox:
		if hitbox.has_method("setup_attack"):
			hitbox.setup_attack("hunter_lunge", true, 0.0)
		hitbox.damage = stats.attack_damage * LUNGE_DAMAGE_MULT * (1.2 if _far_next else 1.0)
		_far_next = false
		hitbox.knockback_force = 330.0
		hitbox.knockback_up_force = 160.0
		hitbox.set("is_parried", false)
		hitbox.set_meta("owner_id", get_instance_id())
		hitbox.enable()
	_play_enemy_sfx("enemy_attack")


func _tick_lunge(_delta: float) -> void:
	_apply_overlap_hit()
	if current_behavior != "lunge":
		return
	if (is_on_floor() and behavior_timer > 0.15) or behavior_timer > LUNGE_MAX_TIME:
		velocity.x = 0.0
		_end_lunge()


func _apply_overlap_hit() -> void:
	if hitbox == null or not hitbox.has_method("is_enabled") or not hitbox.is_enabled():
		return
	for a in hitbox.get_overlapping_areas():
		if a is PlayerHurtbox and (a as Area2D).is_in_group("player_hurtbox"):
			var hb := a as PlayerHurtbox
			if not hb.is_on_cooldown(hitbox) and hb.invincibility_timer <= 0.0:
				hb._on_area_entered(hitbox)
				velocity = Vector2(-_lunge_dir * 200.0, -240.0)
				_end_lunge()
				return


func _end_lunge() -> void:
	lunge_cd = LUNGE_COOLDOWN
	change_behavior("recover")


func _tick_recover(delta: float) -> void:
	_brake(delta)
	if behavior_timer >= RECOVER_TIME and is_on_floor():
		change_behavior("chase")
		path.clear()
		nav_cd = 0.0


# --- Hasar / ölüm --------------------------------------------------------------------------------

func _tick_hurt(delta: float) -> void:
	handle_hurt_behavior(delta)
	move_state = "ground" if is_on_floor() else move_state
	if current_behavior == "chase":
		path.clear()
		nav_cd = 0.0
		air_edge = {}
		move_state = "ground"


func _on_hurtbox_hurt(hb: Area2D) -> void:
	super._on_hurtbox_hurt(hb)
	# Vurulan avcı, vuranı fark eder (görüş menzili dışında olsa bile)
	if current_behavior in ["idle", "patrol", "search"] and target != null and is_instance_valid(target):
		last_known_pos = target.global_position
		lose_timer = 0.0
		change_behavior("chase")


func die() -> void:
	if current_behavior == "dead":
		return
	_thru_active = false
	collision_mask = BASE_MASK
	super.die()
	if sprite:
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(sprite, "rotation", 1.4 * (1.0 if randf() < 0.5 else -1.0), 0.8)
		tw.tween_property(sprite, "modulate:a", 0.0, 1.0).set_delay(0.5)
		tw.chain().tween_callback(queue_free)


# --- Yardımcılar --------------------------------------------------------------------------------

func _walk_dir(dir: float, speed: float) -> void:
	velocity.x = dir * speed
	_face(dir)


func _face(dir: float) -> void:
	if dir == 0.0:
		return
	direction = 1 if dir > 0.0 else -1
	if sprite:
		sprite.flip_h = dir < 0.0


func _update_anim() -> void:
	if sprite == null or current_behavior == "dead":
		return
	var want: String = "idle"
	if not is_on_floor():
		want = "jump" if velocity.y < -40.0 else "fall"
	elif current_behavior in ["windup", "recover", "hurt", "guard"]:
		want = "idle"
	elif absf(velocity.x) > 20.0:
		want = "patrol" if current_behavior == "patrol" else "chase"
	if sprite.animation != want:
		sprite.play(want)
