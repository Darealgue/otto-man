extends CharacterBody2D
## Köy kedisi. Varsayılan: res://village/resources/cat_default_sprite_frames.tres
## Kendi çizimlerin için bu .tres’i editörde düzenle veya sprite_frames_override / AnimatedSprite2D.sprite_frames değiştir.
## Animasyon isimleri: idle, walk, run, jump_up, jump_down, sleep.

enum CatState {
	ROAM,
	IDLE,
	SEEK_ROOF,
	JUMP_TO_ROOF,
	ROOF_ROAM,
	SLEEP,
	## Sosyal oyun: başka kediye doğru kısa süreli koşu.
	CHASE_OTHER,
	## Sosyal oyun: kovalayan kediden uzaklaş.
	FLEE_OTHER,
}

const ANIM_IDLE := "idle"
const ANIM_WALK := "walk"
const ANIM_RUN := "run"
const ANIM_JUMP_UP := "jump_up"
const ANIM_JUMP_DOWN := "jump_down"
const ANIM_SLEEP := "sleep"

const DEFAULT_CAT_SPRITE_FRAMES: SpriteFrames = preload("res://village/resources/cat_default_sprite_frames.tres")
const CAT_SHEET_IDLE := "res://assets/NPC/cat/cat_idle_border.png"
const CAT_SHEET_WALK := "res://assets/NPC/cat/cat_walk_border.png"
const CAT_SHEET_RUN := "res://assets/NPC/cat/cat_run_border.png"
const CAT_SHEET_JUMP_UP := "res://assets/NPC/cat/cat_jump_up_border.png"
const CAT_SHEET_JUMP_DOWN := "res://assets/NPC/cat/cat_jump_down_border.png"
const CAT_SHEET_SLEEP := "res://assets/NPC/cat/cat_sleep_border.png"

@export var sprite_frames_override: SpriteFrames
## Spawn aninda bu listeden rastgele renk secilir; her kedi farkli tona sahip olur.
@export var enable_random_color_variants: bool = true
@export var cat_color_variants: Array[Color] = [
	Color(1.0, 1.0, 1.0, 1.0),    # Acik/orijinal ton
	Color(1.0, 0.90, 0.58, 1.0),  # Sari
	Color(0.78, 0.78, 0.80, 1.0), # Gri
	Color(0.42, 0.42, 0.45, 1.0), # Koyu gri
	Color(0.24, 0.24, 0.26, 1.0), # Kara
]
@export var run_anim_speed_threshold: float = 118.0
@export var roam_speed: float = 30.0
@export var roam_burst_speed: float = 155.0
@export var roam_burst_seconds_min: float = 1.2
@export var roam_burst_seconds_max: float = 3.2
@export var roam_burst_chance_on_new_target: float = 0.12
@export var band_y_wander_accel: float = 220.0
@export var band_y_wander_max_speed: float = 48.0
@export var roof_speed: float = 22.0
@export var gravity_strength: float = 950.0
@export var jump_duration: float = 0.65
@export var min_idle_time: float = 8.0
@export var max_idle_time: float = 26.0
@export var idle_enter_chance_on_arrival: float = 0.2
@export var min_roam_before_idle_seconds: float = 10.0
@export var idle_reentry_cooldown_seconds: float = 8.0
## Varisa bagli olmadan, ROAM suresine gore idle'a girme sansi (saniye bazli).
@export var idle_time_based_chance_per_second: float = 0.07
## Bu kadar uzun ROAM olduysa sonraki firsatta zorunlu idle.
@export var force_idle_after_roam_seconds: float = 24.0
## ROAM'a gireli bu sure gecmeden cati niyeti baslatma (IDLE'a firsat ver).
@export var min_roam_before_roof_seek_seconds: float = 12.0
## Arka arkaya bu kadar varista idle kacirildiysa bir sonrakinde zorunlu idle.
@export var force_idle_after_arrivals_without_idle: int = 2
@export var min_sleep_time: float = 35.0
@export var max_sleep_time: float = 75.0
@export var min_seconds_on_roof_before_sleep_roll: float = 8.0
@export var roof_sleep_chance_on_arrival: float = 0.1
@export var roof_retry_cooldown: float = 8.0
@export var post_roof_ground_cooldown_min: float = 45.0
@export var post_roof_ground_cooldown_max: float = 95.0
## Aynı noktada ilerleme yoksa (duvar, çarpışma) yeni hedef / çatı aramayı bırak.
@export var stuck_repick_after_seconds: float = 4.0
@export var stuck_min_movement_px: float = 0.35
## Çatı altına gidip zıplayamıyorsa ROAM'a dön.
@export var seek_roof_abort_seconds: float = 14.0
## ROOF_ROAM iken vücut çatı segmentinin bu kadar altındaysa yer katına düşmüş sayılır (durum sıkışmasını önler).
@export var roof_roam_fell_px_below_segment: float = 28.0
## Yerdeyken tek zıplamada çıkılabilecek max dikey mesafe (aşağı Y = büyük değer; fark py - seg_y).
@export var roof_first_tier_max_delta_y: float = 170.0
## Catiya inis kabul toleransi (farkli one-way temaslarinda erken fail olmasin).
@export var roof_landing_y_tolerance: float = 42.0
## Hedef Y tutmasa bile bu kadar yukarida zemine bastiysa cati kabul et.
@export var roof_landing_min_height_above_band: float = 20.0
## Üst kata (çatıdayken) bir sonraki segmente max dikey adım (cy - sy).
@export var roof_climb_tier_max_delta_y: float = 128.0
@export var roof_horizontal_pick_range: float = 1100.0
@export var roof_climb_horizontal_tolerance: float = 145.0
@export var upper_roof_cooldown_min: float = 3.5
@export var upper_roof_cooldown_max: float = 9.0
@export var lower_roof_cooldown_min: float = 3.0
@export var lower_roof_cooldown_max: float = 8.0
@export var roof_descend_tier_max_delta_y: float = 150.0
@export var roof_descend_horizontal_tolerance: float = 180.0
## Yeni gezinme hedefi mevcut konuma çok yakınsa X'te zorla uzaklaştır (vel=0 kilitlenmesi).
@export var roam_target_min_dx: float = 52.0
## Cok dar catida jitter olmamasi icin bir sonraki roof hedefine minimum X mesafesi.
@export var roof_target_min_travel_x: float = 42.0
@export var roof_turn_cooldown_min: float = 0.4
@export var roof_turn_cooldown_max: float = 0.85
@export var roof_arrive_distance_x: float = 16.0
@export var roof_turn_accel: float = 980.0
## Köylü bandının dışındayken (ör. çatıdan) Y'yi anında sıkıştırmak yerine bu hızla banda yaklaştırır — ışınlanmayı önler.
@export var float_band_descend_speed: float = 420.0
## Cati/ust katlardan ROAM bandina donuste daha yumusak inis hizi.
@export var float_band_descend_speed_from_roof: float = 170.0
## Catiya cikmadan once ve catidan indikten hemen sonra oyuncu zemin hattinda (y0) kilitli yurume suresi.
@export var ground_line_lock_seconds: float = 0.95
## Catidan indikten sonra Y hedefini kisa sure sabitleyip ani "ust banda zip"i engeller.
@export var post_roof_y_stabilize_seconds: float = 2.2
## Açıkken periyodik log + durum değişiminde tek satır log.
@export var debug_motion: bool = true
## Idle sure analizi: giris hedefi, gerceklesen sure ve cikis nedeni loglanir.
@export var debug_idle_timing: bool = true
## Karar logu: neden idle/roof secildi veya secilmedi.
@export var debug_behavior_decisions: bool = true
## Sprite tabanini collision tabanina hizalamak icin ek ince ayar (px).
@export var sprite_collision_foot_offset: float = 0.0
## Kedi z-index'ini koyluye gore bir tik geriye kaydir (onune gecme hissini azaltir).
@export var depth_sort_z_offset: int = -2
## Depth hesabini dinamik roam_bounds yerine sabit y bandinda tut (bounds dalgalanmasinda z ziplamasin).
@export var depth_sort_min_y: float = 5.0
@export var depth_sort_max_y: float = 30.0
## Rüzgarın yatay itmesi (WeatherManager.wind_strength / wind_direction_angle).
@export var weather_wind_push: float = 38.0
## Saniyede bir (ROAM) ani küçük sıçrama / ürperme.
@export var startle_chance_per_second: float = 0.014
@export var startle_impulse_x: float = 115.0
## Kovalama hızı ve süreleri.
@export var chase_speed: float = 148.0
@export var chase_seconds_min: float = 3.8
@export var chase_seconds_max: float = 7.2
@export var flee_speed: float = 168.0
@export var flee_seconds_min: float = 2.8
@export var flee_seconds_max: float = 5.6
@export var play_cooldown_min: float = 9.0
@export var play_cooldown_max: float = 18.0
@export var chase_catch_distance: float = 34.0
## Yakalama olduktan sonra sosyal oyunun hemen bitmesini engelle.
@export var play_min_after_catch_seconds: float = 4.2

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

var state: CatState = CatState.ROAM
var roam_bounds: Rect2 = Rect2(-3500.0, 5.0, 7000.0, 25.0)
var roam_target: Vector2 = Vector2.ZERO
## Yürünebilir bantta köylü gibi ayrı Y hedefi (saf X hedefli vektör Y'yi unutmasın diye).
var roam_band_y_target: float = 12.0
var roof_target: Dictionary = {}
var roof_target_x: float = 0.0
var state_timer: float = 0.0
var roof_try_timer: float = 0.0
var post_roof_ground_cooldown: float = 0.0
var roof_session_time: float = 0.0
var _was_near_roof_x: bool = false
var _burst_timer: float = 0.0
var _roam_stuck_accum: float = 0.0
var _roam_stuck_last_pos: Vector2 = Vector2(INF, INF)
var _seek_roof_elapsed: float = 0.0
var _play_timer: float = 0.0
var _play_cooldown: float = 0.0
var _play_target_ref = null
var _play_stall_timer: float = 0.0
var _upper_roof_cd: float = 0.0
var _lower_roof_cd: float = 0.0
var _roof_turn_cooldown: float = 0.0
var _roof_waiting_next_target: bool = false
var _is_lower_roof_transition: bool = false
var _roam_before_idle_timer: float = 0.0
var _idle_reentry_cooldown_timer: float = 0.0
var is_gravity_mode: bool = false
var landing_grace_timer: float = 0.0
var _last_anim: StringName = &""
var _debug_physics_tick: int = 0
var _idle_expected_duration: float = 0.0
var _idle_elapsed: float = 0.0
var _roam_state_elapsed: float = 0.0
var _arrivals_without_idle: int = 0
var _force_descend_anim_until_y: float = INF
var _ground_line_lock_timer: float = 0.0
var _post_roof_y_lock_timer: float = 0.0
var _persistent_cat_id: String = ""
var _has_forced_color_variant: bool = false
var _forced_color_variant: Color = Color(1.0, 1.0, 1.0, 1.0)


func _ready() -> void:
	add_to_group("cats")
	# Sahne/save override'lari çok düşük kalmışsa davranışları taban değerlere zorla.
	min_idle_time = maxf(min_idle_time, 8.0)
	max_idle_time = maxf(max_idle_time, 26.0)
	min_roam_before_idle_seconds = maxf(min_roam_before_idle_seconds, 10.0)
	idle_reentry_cooldown_seconds = maxf(idle_reentry_cooldown_seconds, 8.0)
	if max_idle_time <= min_idle_time:
		max_idle_time = min_idle_time + 2.0
	_apply_sprite_frames()
	_apply_spawn_color_variant()
	_pick_new_roam_target()
	roam_band_y_target = randf_range(roam_bounds.position.y, roam_bounds.end.y)
	post_roof_ground_cooldown = randf_range(0.0, 22.0)
	_play_cooldown = randf_range(0.0, 6.0)
	_upper_roof_cd = randf_range(0.0, 4.0)
	_lower_roof_cd = randf_range(0.0, 4.0)
	_roam_before_idle_timer = min_roam_before_idle_seconds
	_roam_state_elapsed = 0.0
	_roam_stuck_last_pos = global_position
	_auto_align_sprite_to_collision_bottom()
	_safe_play(ANIM_IDLE)
	_update_depth_sorting()
	_setup_pet_interactable()


func set_roam_bounds(bounds: Rect2) -> void:
	roam_bounds = bounds
	roam_target = roam_target.clamp(bounds.position, bounds.end)
	roam_band_y_target = clampf(roam_band_y_target, bounds.position.y, bounds.end.y)
	if is_inside_tree():
		_update_depth_sorting()


func set_spawn_position(pos: Vector2) -> void:
	global_position = pos
	roam_target = pos
	roam_band_y_target = clampf(pos.y, roam_bounds.position.y, roam_bounds.end.y)


func try_seek_roof(roof_points: Array[Dictionary]) -> bool:
	if roof_try_timer > 0.0 or post_roof_ground_cooldown > 0.0 or roof_points.is_empty():
		return false
	# IDLE'i erken kesip davranisi hizla degistirmesin.
	if state != CatState.ROAM:
		return false
	var min_roof_seek_elapsed: float = maxf(min_roam_before_roof_seek_seconds, min_roam_before_idle_seconds + 2.0)
	if _roam_state_elapsed < min_roof_seek_elapsed:
		if debug_motion and debug_behavior_decisions:
			pass
		return false
	if _arrivals_without_idle >= max(0, force_idle_after_arrivals_without_idle) and _roam_before_idle_timer <= 0.0 and _idle_reentry_cooldown_timer <= 0.0:
		if debug_motion and debug_behavior_decisions:
			pass
		return false
	var discomfort: float = _get_weather_discomfort()
	if discomfort > 0.22 and randf() < discomfort * 0.35:
		return false
	var candidate: Dictionary = _pick_roof_seek_target(roof_points, false)
	if candidate.is_empty():
		candidate = _pick_fallback_nearest_reachable_roof(roof_points)
	if candidate.is_empty():
		candidate = _pick_any_roof_nearest(roof_points)
	if candidate.is_empty():
		return false
	roof_target = candidate
	_seek_roof_elapsed = 0.0
	state = CatState.SEEK_ROOF
	return true


## Çatıdayken bir üst one-way segmentine tırmanma dene (VillageCatsController tetikler).
func try_seek_upper_roof(roof_points: Array[Dictionary]) -> bool:
	if roof_points.is_empty():
		return false
	if _upper_roof_cd > 0.0:
		return false
	if state != CatState.ROOF_ROAM:
		return false
	if roof_target.is_empty():
		return false
	var discomfort: float = _get_weather_discomfort()
	if discomfort > 0.1 and randf() < discomfort * 0.38:
		return false
	var candidate: Dictionary = _pick_roof_seek_target(roof_points, true)
	if candidate.is_empty():
		return false
	roof_target = candidate
	_seek_roof_elapsed = 0.0
	state = CatState.SEEK_ROOF
	_upper_roof_cd = randf_range(upper_roof_cooldown_min, upper_roof_cooldown_max)
	return true


func try_seek_lower_roof(roof_points: Array[Dictionary]) -> bool:
	if roof_points.is_empty():
		return false
	if _lower_roof_cd > 0.0:
		return false
	if state != CatState.ROOF_ROAM:
		return false
	if roof_target.is_empty():
		return false
	var candidate: Dictionary = _pick_lower_roof_target(roof_points)
	if candidate.is_empty():
		return false
	roof_target = candidate
	# Alt kata inerken once "SEEK'de drift" yerine direkt iniş zıplaması yap.
	_is_lower_roof_transition = true
	_start_roof_jump()
	_lower_roof_cd = randf_range(lower_roof_cooldown_min, lower_roof_cooldown_max)
	return true


func _physics_process(delta: float) -> void:
	roof_try_timer = maxf(0.0, roof_try_timer - delta)
	post_roof_ground_cooldown = maxf(0.0, post_roof_ground_cooldown - delta)
	state_timer = maxf(0.0, state_timer - delta)
	_burst_timer = maxf(0.0, _burst_timer - delta)
	_play_cooldown = maxf(0.0, _play_cooldown - delta)
	_upper_roof_cd = maxf(0.0, _upper_roof_cd - delta)
	_lower_roof_cd = maxf(0.0, _lower_roof_cd - delta)
	_roof_turn_cooldown = maxf(0.0, _roof_turn_cooldown - delta)
	_roam_before_idle_timer = maxf(0.0, _roam_before_idle_timer - delta)
	_idle_reentry_cooldown_timer = maxf(0.0, _idle_reentry_cooldown_timer - delta)
	_ground_line_lock_timer = maxf(0.0, _ground_line_lock_timer - delta)
	_post_roof_y_lock_timer = maxf(0.0, _post_roof_y_lock_timer - delta)
	var state_at_start: CatState = state
	if state == CatState.ROAM:
		_roam_state_elapsed += delta

	match state:
		CatState.ROAM:
			is_gravity_mode = false
			var move_speed: float = roam_burst_speed if _burst_timer > 0.0 else roam_speed
			if _ground_line_lock_timer > 0.0:
				# Oyuncu yürüyüş hattına önce otur, sonra serbest Y dolaşıma geç.
				roam_band_y_target = roam_bounds.end.y
				_move_float_on_ground(roam_target, move_speed, delta, true)
			elif _post_roof_y_lock_timer > 0.0:
				# Catidan inis sonrasi Y hedefini mevcut hatta tut.
				roam_band_y_target = clampf(global_position.y, roam_bounds.position.y, roam_bounds.end.y)
				_move_float_on_ground(roam_target, move_speed, delta, true)
			else:
				_move_float_on_ground(roam_target, move_speed, delta)
			_apply_weather_wind(delta)
			if randf() < startle_chance_per_second * delta:
				velocity.x += randf_range(-startle_impulse_x, startle_impulse_x)
			var discomfort: float = _get_weather_discomfort()
			var idle_roll: float = idle_enter_chance_on_arrival + discomfort * 0.16
			idle_roll = clampf(idle_roll, 0.05, 0.55)
			var can_idle_now: bool = _roam_before_idle_timer <= 0.0 and _idle_reentry_cooldown_timer <= 0.0
			var min_roof_seek_elapsed_local: float = maxf(min_roam_before_roof_seek_seconds, min_roam_before_idle_seconds + 2.0)
			var can_time_idle_now: bool = can_idle_now and _roam_state_elapsed >= min_roof_seek_elapsed_local
			var forced_idle_elapsed: float = maxf(force_idle_after_roam_seconds, min_roof_seek_elapsed_local + 4.0)
			if not can_idle_now:
				idle_roll = 0.0
			var entered_idle: bool = false
			if can_time_idle_now:
				if _roam_state_elapsed >= forced_idle_elapsed:
					if debug_motion and debug_behavior_decisions:
						pass
					_enter_idle()
					entered_idle = true
				elif randf() < idle_time_based_chance_per_second * delta:
					if debug_motion and debug_behavior_decisions:
						pass
					_enter_idle()
					entered_idle = true
			if not entered_idle and absf(global_position.x - roam_target.x) < 22.0 and absf(global_position.y - roam_band_y_target) < 10.0:
				var should_force_idle: bool = _arrivals_without_idle >= max(0, force_idle_after_arrivals_without_idle)
				if should_force_idle or randf() < idle_roll:
					if debug_motion and debug_behavior_decisions:
						pass
					_enter_idle()
				else:
					_arrivals_without_idle += 1
					if debug_motion and debug_behavior_decisions:
						pass
					_pick_new_roam_target()
		CatState.IDLE:
			is_gravity_mode = false
			_idle_elapsed += delta
			velocity = velocity.move_toward(Vector2.ZERO, 380.0 * delta)
			_apply_weather_wind(delta)
			if state_timer <= 0.0:
				if debug_motion and debug_idle_timing:
					pass
				_pick_new_roam_target()
				_enter_roam_state()
		CatState.SEEK_ROOF:
			is_gravity_mode = false
			_seek_roof_elapsed += delta
			if _seek_roof_elapsed >= seek_roof_abort_seconds:
				_abort_seek_roof_to_roam()
			else:
				var prep_target := Vector2(float(roof_target.get("center_x", global_position.x)), roam_bounds.end.y)
				# Cati ustunden yere iniste 45 derece "walk glide" yerine once dikey yumusak inis.
				roam_band_y_target = roam_bounds.end.y
				if global_position.y < roam_bounds.position.y - 6.0:
					velocity.x = move_toward(velocity.x, 0.0, 420.0 * delta)
					velocity.y = move_toward(velocity.y, float_band_descend_speed_from_roof, band_y_wander_accel * delta)
				else:
					# Catiya cikmadan once oyuncu zemin hattina inip orada kosarak ziplasin.
					_move_float_on_ground(prep_target, roam_speed, delta)
				_apply_weather_wind(delta)
				if absf(global_position.x - prep_target.x) < 24.0 and absf(global_position.y - roam_bounds.end.y) < 6.0:
					_start_roof_jump()
		CatState.JUMP_TO_ROOF:
			is_gravity_mode = true
			_apply_gravity(delta)
			if is_on_floor():
				var roof_y := float(roof_target.get("y", global_position.y))
				var landed_near_target: bool = absf(global_position.y - roof_y) < roof_landing_y_tolerance
				var landed_above_ground_band: bool = global_position.y <= (roam_bounds.position.y - roof_landing_min_height_above_band)
				if landed_near_target or landed_above_ground_band:
					_enter_roof_roam()
				else:
					_fail_roof_and_resume()
			elif global_position.y > float(roof_target.get("y", global_position.y)) + 130.0:
				_fail_roof_and_resume()
		CatState.ROOF_ROAM:
			is_gravity_mode = true
			roof_session_time += delta
			_apply_gravity(delta)
			var diff_x: float = roof_target_x - global_position.x
			if _roof_waiting_next_target:
				velocity.x = move_toward(velocity.x, 0.0, roof_turn_accel * delta)
				if _roof_turn_cooldown <= 0.0:
					_pick_new_roof_x_target()
					_roof_waiting_next_target = false
			elif absf(diff_x) <= roof_arrive_distance_x:
				if roof_session_time >= min_seconds_on_roof_before_sleep_roll and randf() < roof_sleep_chance_on_arrival:
					_enter_sleep()
				else:
					_roof_waiting_next_target = true
					_roof_turn_cooldown = randf_range(roof_turn_cooldown_min, roof_turn_cooldown_max)
					velocity.x = 0.0
			else:
				var dir: float = signf(diff_x)
				if dir == 0.0:
					dir = 1.0 if randf() < 0.5 else -1.0
				velocity.x = move_toward(velocity.x, dir * roof_speed, roof_turn_accel * delta)
			if not is_on_floor():
				landing_grace_timer += delta
				if landing_grace_timer > 0.35:
					_fail_roof_and_resume()
			else:
				landing_grace_timer = 0.0
		CatState.SLEEP:
			is_gravity_mode = false
			velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
			if state_timer <= 0.0:
				if not roof_target.is_empty() and randf() < 0.82:
					state = CatState.ROOF_ROAM
					roof_session_time = 0.0
					_was_near_roof_x = false
					_is_lower_roof_transition = false
					_pick_new_roof_x_target()
				else:
					roof_target = {}
					post_roof_ground_cooldown = randf_range(post_roof_ground_cooldown_min, post_roof_ground_cooldown_max)
					_enter_roam_state()
					_pick_new_roam_target()
		CatState.CHASE_OTHER:
			is_gravity_mode = false
			_play_timer -= delta
			var prey: Node2D = _get_play_target_node()
			if prey == null or _play_timer <= 0.0 or not _is_partner_play_active(prey):
				_end_social_play()
			else:
				var tx: float = prey.global_position.x
				var toward := Vector2(tx, global_position.y)
				roam_band_y_target = global_position.y
				_move_float_on_ground(toward, chase_speed, delta, true)
				_apply_weather_wind(delta)
				if global_position.distance_to(prey.global_position) < chase_catch_distance:
					_play_timer = maxf(_play_timer, play_min_after_catch_seconds)
				if absf(tx - global_position.x) < 10.0 and absf(velocity.x) < 14.0:
					_play_stall_timer += delta
					if _play_stall_timer >= 0.75:
						_end_social_play()
				else:
					_play_stall_timer = 0.0
		CatState.FLEE_OTHER:
			is_gravity_mode = false
			_play_timer -= delta
			var threat: Node2D = _get_play_target_node()
			if threat == null or _play_timer <= 0.0 or not _is_partner_play_active(threat):
				_end_social_play()
			else:
				var away_dir: float = signf(global_position.x - threat.global_position.x)
				if away_dir == 0.0:
					away_dir = 1.0 if randf() < 0.5 else -1.0
				var away_x: float = global_position.x + away_dir * 420.0
				var flee_pt := Vector2(away_x, global_position.y)
				roam_band_y_target = global_position.y
				_move_float_on_ground(flee_pt, flee_speed, delta, true)
				_apply_weather_wind(delta)
				if absf(velocity.x) < 14.0:
					_play_stall_timer += delta
					if _play_stall_timer >= 0.75:
						_end_social_play()
				else:
					_play_stall_timer = 0.0

	if debug_motion and state != state_at_start:
		pass

	if _uses_slide_physics_for_state(state):
		move_and_slide()
	else:
		_integrate_float_motion(delta)
	_clamp_float_to_roam_bounds(delta)
	_post_move_fix_roof_roam_if_on_ground()
	_update_roam_seek_stuck_watchdog(delta)
	_update_facing()
	_update_animation()
	_update_depth_sorting()
	_update_fish_icon()
	_update_companion_badge()
	_update_nameplate()
	_debug_log_motion_if_needed()


func _apply_sprite_frames() -> void:
	if sprite_frames_override:
		_sprite.sprite_frames = sprite_frames_override
	elif _has_cat_sheet_assets():
		var generated := _build_sprite_frames_from_sheets()
		if generated != null:
			_sprite.sprite_frames = generated
			return
	elif _sprite.sprite_frames == null or _sprite.sprite_frames.get_animation_names().is_empty():
		_sprite.sprite_frames = DEFAULT_CAT_SPRITE_FRAMES


func _apply_spawn_color_variant() -> void:
	if _sprite == null:
		return
	if _has_forced_color_variant:
		_sprite.self_modulate = _forced_color_variant
		return
	if not enable_random_color_variants:
		_sprite.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
		return
	if cat_color_variants.is_empty():
		return
	var picked: Color = cat_color_variants[randi() % cat_color_variants.size()]
	_sprite.self_modulate = picked


func set_persistent_identity(cat_id: String, color_variant: Color) -> void:
	_persistent_cat_id = cat_id
	_has_forced_color_variant = true
	_forced_color_variant = color_variant
	if _sprite != null:
		_sprite.self_modulate = _forced_color_variant


func get_persistent_cat_id() -> String:
	return _persistent_cat_id


## Kalıcı kayıttaki (CatRoster) adı; kimlik yoksa boş.
func get_cat_name() -> String:
	var roster := get_node_or_null("/root/CatRoster")
	if roster == null or _persistent_cat_id.is_empty():
		return ""
	return String(roster.get_cat_name(_persistent_cat_id))


# ─── Sevme ───────────────────────────────────────────────────────────────────

const PET_IDLE_SECONDS: float = 3.6
const _CatHeartsFx = preload("res://village/scripts/CatHeartsFx.gd")

var _pet_face_x: float = 0.0
var _pet_face_until_msec: int = 0


## Yerdeki (dolaşıyor ya da bekliyor) kedi, kalıcı kimliği olan ve bekleme süresi dolmuşsa sevilebilir.
func can_be_petted() -> bool:
	if state != CatState.ROAM and state != CatState.IDLE:
		return false
	if _persistent_cat_id.is_empty():
		return false
	var roster := get_node_or_null("/root/CatRoster")
	return roster != null and roster.can_pet(_persistent_cat_id)


## Oyuncu kediyle etkileşime girebilir mi: sevilebiliyorsa ya da balık istiyorsa (balık isteği sevme beklemesinden bağımsızdır).
func can_interact() -> bool:
	if wants_fish() or can_be_petted():
		return true
	# Eşlikçi olabilecek kedi: seçim menüsü (Yanıma al / Evde bırak) sevme beklemesinden bağımsız her an açılabilir.
	if state != CatState.ROAM and state != CatState.IDLE:
		return false
	var roster := get_node_or_null("/root/CatRoster")
	return not _fishing_active and roster != null and not _persistent_cat_id.is_empty() and roster.is_companion_eligible(_persistent_cat_id)


# ─── Oyuncunun basılı tutma etkileşimi kancaları (Player._process_village_interaction_hold) ─────────
# Kısa basış arkadaki binayı açıyordu; köylülerdeki gibi kediyle etkileşim de basılı tutmayla olur (halka dolar).
const _ArrowHint = preload("res://ui/InteractArrowHint.gd")
const _CatHoldRing = preload("res://village/scripts/CatHoldRing.gd")

var _hint_arrow: Sprite2D = null
var _hold_ring: Node2D = null


func _on_interact_button_pressed() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		try_interact(player)


func ShowInteractButton() -> void:
	if not is_instance_valid(_hint_arrow):
		_hint_arrow = _ArrowHint.create()
		_hint_arrow.position = Vector2(0.0, -48.0)
		add_child(_hint_arrow)
	if can_interact():
		_hint_arrow.show_hint()
	else:
		_hint_arrow.hide_hint()


func HideInteractButton() -> void:
	if is_instance_valid(_hint_arrow):
		_hint_arrow.hide_hint()
	set_interact_hold_progress(0.0)


func set_interact_hold_progress(ratio: float) -> void:
	if not is_instance_valid(_hold_ring):
		if ratio <= 0.0:
			return
		_hold_ring = _CatHoldRing.new()
		add_child(_hold_ring)
	_hold_ring.set("ratio", ratio)


## Etkileşim: kedi balık istiyorsa balık tutma minigame'i başlar; eşlikçi olabilecek kediyle (yeterince beslenmiş) seçim menüsü
## açılır (Okşa / Yanıma al); diğer durumlarda kedi sevilir.
func try_interact(player: Node2D) -> void:
	if _fishing_active or is_instance_valid(_choice_menu):
		return
	if wants_fish():
		_start_fishing(player)
		return
	var roster := get_node_or_null("/root/CatRoster")
	if roster != null and not _persistent_cat_id.is_empty() and roster.is_companion_eligible(_persistent_cat_id):
		_open_choice_menu(player)
	else:
		try_pet(player)


# ─── Eşlikçi seçim menüsü ────────────────────────────────────────────────────

const _CatChoiceMenu = preload("res://village/scripts/CatChoiceMenu.gd")
const _CatCompanionBadge = preload("res://village/scripts/CatCompanionBadge.gd")

var _choice_menu: CanvasLayer = null
var _choice_player: Node2D = null
var _choice_player_prev_mode: int = Node.PROCESS_MODE_INHERIT
var _companion_badge: Node2D = null


func _open_choice_menu(player: Node2D) -> void:
	if player == null or not is_instance_valid(player):
		return
	_hold_still(60.0, player)
	_choice_player = player
	_choice_player_prev_mode = player.process_mode
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var menu: CanvasLayer = _CatChoiceMenu.new()
	menu.set("cat_id", _persistent_cat_id)
	menu.set("can_pet", can_be_petted())
	menu.connect("chosen", Callable(self, "_on_choice_made"))
	get_tree().root.add_child(menu)
	_choice_menu = menu


func _on_choice_made(choice: String) -> void:
	var player: Node2D = _choice_player
	_choice_player = null
	if is_instance_valid(player):
		player.process_mode = _choice_player_prev_mode as Node.ProcessMode
		# Menüyü açan tuş hâlâ basılıysa tekrar tetiklenmesin.
		if "_suppress_village_interact_until_release" in player:
			player.set("_suppress_village_interact_until_release", true)
	# Menü açıkken kedi 60 sn "oyuncuya bak" modundaydı; kapanınca kısa süre durup bakışı serbest bırak (yoksa yürürken oyuncuya
	# bakıp geri geri yürüyor gibi görünür).
	state_timer = 2.0
	_idle_expected_duration = 2.0
	_idle_elapsed = 0.0
	_pet_face_until_msec = Time.get_ticks_msec() + 2000
	var roster := get_node_or_null("/root/CatRoster")
	match choice:
		"pet":
			try_pet(player)
		"take":
			if roster != null and roster.set_companion(_persistent_cat_id, true):
				var fx: Node2D = _CatHeartsFx.new()
				fx.count = 5
				add_child(fx)
		"leave":
			if roster != null:
				roster.set_companion(_persistent_cat_id, false)


## Eşlikçi seçili kedinin üstünde altın pati işareti görünür (diğer kedilerde yok).
func _update_companion_badge() -> void:
	var roster := get_node_or_null("/root/CatRoster")
	var show_badge: bool = roster != null and not _persistent_cat_id.is_empty() and roster.is_companion(_persistent_cat_id)
	if show_badge and not is_instance_valid(_companion_badge):
		_companion_badge = _CatCompanionBadge.new()
		add_child(_companion_badge)
	elif not show_badge and is_instance_valid(_companion_badge):
		_companion_badge.queue_free()
		_companion_badge = null


## Oyuncu kediyi sever: kedi durur, oyuncuya döner, kalpler çıkar; bağ puanı CatRoster'a işlenir. Ardından kedi balık ister.
func try_pet(player: Node2D) -> void:
	if not can_be_petted():
		return
	var roster := get_node_or_null("/root/CatRoster")
	_hold_still(PET_IDLE_SECONDS, player)
	var result: Dictionary = roster.pet(_persistent_cat_id)
	var fx: Node2D = _CatHeartsFx.new()
	fx.count = 6 if bool(result.get("leveled_up", false)) else 3
	add_child(fx)
	# İlk tanışmada ve bağ seviyesi arttığında kedinin adı balonla görünür.
	if bool(result.get("first_time", false)) or bool(result.get("leveled_up", false)):
		_show_name_bubble()
	# Sevildikten sonra kedi başında balık simgesiyle balık ister (günlük sınır CatRoster'da).
	if roster.can_ask_fish(_persistent_cat_id):
		_fish_wanted_until_msec = Time.get_ticks_msec() + FISH_REQUEST_MSEC


## Kediyi bir süre olduğu yerde tutar ve oyuncuya döndürür.
func _hold_still(seconds: float, player: Node2D) -> void:
	state = CatState.IDLE
	state_timer = seconds
	_idle_expected_duration = seconds
	_idle_elapsed = 0.0
	_idle_reentry_cooldown_timer = idle_reentry_cooldown_seconds
	velocity = Vector2.ZERO
	if player != null and is_instance_valid(player):
		_pet_face_x = player.global_position.x
		_pet_face_until_msec = Time.get_ticks_msec() + int(seconds * 1000.0)


# ─── Balık isteği ve balık tutma ─────────────────────────────────────────────

const FISH_REQUEST_MSEC: int = 120000       # kedi balık isteğini bu süre açık tutar
const _CatFishIcon = preload("res://village/scripts/CatFishIcon.gd")
const _FishingLine = preload("res://village/scripts/show/ShowFishingLine.gd")

var _fish_wanted_until_msec: int = 0
var _slots_visible_until_msec: int = 0
var _fishing_active: bool = false
var _fish_icon: Node2D = null
var _fishing_line: Node2D = null
var _fishing_player: Node2D = null
var _fishing_player_prev_mode: int = Node.PROCESS_MODE_INHERIT
var _fishing_player_home: Vector2 = Vector2.ZERO
var _fishing_hand_y: float = -36.0
var _fishing_difficulty: int = 2

const FISHING_BAIT_FOOD: int = 1             # balık tutmak için harcanan yem (köy yiyecek stoğundan)
const FISHING_BANK_Y: float = 56.0           # oyuncunun ayak y'si: kıyı (çimen kenarı), su yüzeyi y 98
const FISHING_WALK_SECONDS: float = 0.8      # kıyıya gidiş ve dönüş süresi
## Zorluk havuzu (1 kolay, 2 orta, 3 zor): orta daha sık çıksın diye tekrar ile ağırlıklandırılır.
const FISHING_DIFFICULTY_WEIGHTS: Array[int] = [1, 1, 2, 2, 2, 3, 3]


## Kedi şu an balık istiyor mu (simge görünür, yerde ve ulaşılabilir)?
func wants_fish() -> bool:
	if _fishing_active or Time.get_ticks_msec() > _fish_wanted_until_msec:
		return false
	return state == CatState.ROAM or state == CatState.IDLE


const ICON_SHOW_DIST: float = 320.0         # oyuncu bu kadar yakındaysa balık slotları görünür
const ICON_HIDE_DIST: float = 400.0         # bundan uzaklaşınca kaybolur
const NAME_SHOW_DIST: float = 170.0         # tanıdık kedinin ismi bu kadar yakında görünür
const NAME_HIDE_DIST: float = 230.0
var _icon_near: bool = false
var _name_near: bool = false
var _nameplate: Label = null


func _player_distance() -> float:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null or not is_instance_valid(p):
		return INF
	return absf(p.global_position.x - global_position.x) + absf(p.global_position.y - global_position.y) * 0.5


## Tanıdık (bağ seviyesi 1+) kedinin ismi, köylülerde olduğu gibi oyuncu yaklaşınca tepesinde görünür (kutusuz, konturlu).
func _update_nameplate() -> void:
	var roster := get_node_or_null("/root/CatRoster")
	var known: bool = roster != null and not _persistent_cat_id.is_empty() and int(roster.get_level(_persistent_cat_id)) >= 1
	var dist: float = _player_distance()
	_name_near = dist < NAME_SHOW_DIST if not _name_near else dist < NAME_HIDE_DIST
	var want: bool = known and _name_near and state != CatState.SLEEP
	if want and not is_instance_valid(_nameplate):
		_nameplate = Label.new()
		_nameplate.name = "CatNameplate"
		_nameplate.text = get_cat_name()
		_nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_nameplate.z_index = 30
		_nameplate.modulate.a = 0.0
		add_child(_nameplate)
		NpcOverheadUi.apply_nameplate_text_style(_nameplate)
		_nameplate.reset_size()
		_nameplate.position = Vector2(-_nameplate.size.x * 0.5, -88.0)   # balık slotlarının (y ≈ -54) üstünde
	if is_instance_valid(_nameplate):
		var target_a: float = 1.0 if want else 0.0
		_nameplate.modulate.a = move_toward(_nameplate.modulate.a, target_a, 0.08)
		if not want and _nameplate.modulate.a <= 0.0:
			_nameplate.queue_free()
			_nameplate = null


func _update_fish_icon() -> void:
	var asking: bool = wants_fish()
	# Beslendikten sonra slotlar kısa süre görünür kalır; kedi balık istiyorsa sürekli görünür.
	var show_icon: bool = asking or (Time.get_ticks_msec() < _slots_visible_until_msec and not _fishing_active)
	# Oyuncu uzaklaşınca simge kaybolur (yakınlaşınca geri gelir); eşik farkı titremeyi önler.
	var dist: float = _player_distance()
	_icon_near = dist < ICON_SHOW_DIST if not _icon_near else dist < ICON_HIDE_DIST
	if not _icon_near and not _fishing_active:
		show_icon = false
	if show_icon and not is_instance_valid(_fish_icon):
		_fish_icon = _CatFishIcon.new()
		_fish_icon.slots = CatRoster.FISH_PER_DAY_CAP
		add_child(_fish_icon)
	elif not show_icon and is_instance_valid(_fish_icon):
		_fish_icon.queue_free()
		_fish_icon = null
	if is_instance_valid(_fish_icon):
		var roster := get_node_or_null("/root/CatRoster")
		_fish_icon.filled = int(roster.get_fed_today(_persistent_cat_id)) if roster != null else 0
		_fish_icon.asking = asking


## Oyuncu kediyle aynı hizadaki kıyıya yaklaşır, olta atar: çizgi oyuncudan kedinin altındaki suya iner, Stardew tarzı minigame açılır.
## Oyuncu bu sürede dondurulur (girdi ve fizik kapanır); minigame bitince eski yerine döner ve eski haline kavuşur.
func _start_fishing(player: Node2D) -> void:
	if player == null or not is_instance_valid(player):
		return
	var router := get_node_or_null("/root/MinigameRouter")
	if router == null:
		return
	# Yem: balık tutmak köy stokundan 1 yiyecek harcar (tutulsa da kaçsa da). Yiyecek yoksa balık tutulamaz.
	var vm := get_node_or_null("/root/VillageManager")
	if vm != null and vm.has_method("spend_resources"):
		if not bool(vm.call("spend_resources", {"food": FISHING_BAIT_FOOD})):
			_show_player_bubble(player, tr("cat.fish.no_bait"))
			return
		ResourceLossPopup.spawn("food", FISHING_BAIT_FOOD, player.global_position + Vector2(0.0, -90.0))
	_hold_still(90.0, player)
	_fishing_active = true
	_fishing_player = player
	_fishing_player_prev_mode = player.process_mode
	_fishing_player_home = player.global_position
	player.process_mode = Node.PROCESS_MODE_DISABLED
	# Oyuncuyu ayaklarının y'sini kıyıya (FISHING_BANK_Y) getirecek kadar aşağı kaydır (x aynı kalır: "aynı hizadaki sahil").
	var foot_y: float = float(player.call("get_foot_y_position")) if player.has_method("get_foot_y_position") else player.global_position.y
	var shore_pos := Vector2(player.global_position.x, player.global_position.y + (FISHING_BANK_Y - foot_y))
	_fishing_hand_y = (foot_y - player.global_position.y) - 36.0
	await _move_player_to(player, shore_pos, FISHING_WALK_SECONDS)
	if not _fishing_active or not is_instance_valid(player):
		return
	# Olta çizgisi: oyuncunun elinden kedinin x'indeki (aynı hizadaki) suya.
	_fishing_line = _FishingLine.new()
	_fishing_line.set("fisher", player)
	_fishing_line.set("dir", 1.0 if global_position.x >= player.global_position.x else -1.0)
	_fishing_line.set("cast_distance", absf(global_position.x - player.global_position.x))
	_fishing_line.set("hand_offset", Vector2(14.0, _fishing_hand_y))
	get_parent().add_child(_fishing_line)
	var cb := Callable(self, "_on_fishing_finished")
	if router.is_connected("minigame_finished", cb):
		router.disconnect("minigame_finished", cb)
	router.connect("minigame_finished", cb, CONNECT_ONE_SHOT)
	# Zorluk her seferinde rastgele (1 kolay, 2 orta, 3 zor); zor balık daha çok bağ puanı verir.
	_fishing_difficulty = FISHING_DIFFICULTY_WEIGHTS[randi() % FISHING_DIFFICULTY_WEIGHTS.size()]
	var started: bool = bool(router.start_minigame("cat_fishing", {"cat_path": str(get_path()), "difficulty": _fishing_difficulty}))
	if not started:
		router.disconnect("minigame_finished", cb)
		await _move_player_to(player, _fishing_player_home, FISHING_WALK_SECONDS)
		_end_fishing()


## Oyuncuyu (fizik kapalıyken) hedefe yumuşakça kaydırır ve derinlik sırasını (z) günceller.
func _move_player_to(player: Node2D, target: Vector2, seconds: float) -> void:
	var tw := create_tween()
	tw.tween_property(player, "global_position", target, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_method(func(_v: float) -> void:
		if is_instance_valid(player) and player.has_method("_calculate_player_z_index_from_foot_y") and player.has_method("get_foot_y_position"):
			player.z_index = int(player.call("_calculate_player_z_index_from_foot_y", player.call("get_foot_y_position")))
	, 0.0, 1.0, seconds)
	await tw.finished


const FISH_REASK_DELAY: float = 5.0           # kedi yemeği bitirdikten sonra tekrar isteme gecikmesi

func _ask_fish_again() -> void:
	if not is_inside_tree() or _fishing_active:
		return
	var roster := get_node_or_null("/root/CatRoster")
	if roster != null and not _persistent_cat_id.is_empty() and roster.can_ask_fish(_persistent_cat_id):
		_fish_wanted_until_msec = Time.get_ticks_msec() + FISH_REQUEST_MSEC


## Oyuncunun başında kısa bir bilgi balonu (ör. yem harcandı).
func _show_player_bubble(player: Node2D, text: String) -> void:
	if player == null or not is_instance_valid(player):
		return
	# Eşya toplarken çıkan süzülen yazı tarzında (GlobalPlayerData.show_gold_pickup_popup_at ile aynı görünüm).
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var holder := Node2D.new()
	holder.name = "CatBaitPopup"
	holder.z_as_relative = false
	holder.z_index = 1200
	scene.add_child(holder)
	holder.global_position = player.global_position + Vector2(0, -90)
	var lbl := Label.new()
	holder.add_child(lbl)
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ls := LabelSettings.new()
	ls.font_color = Color(1.0, 0.92, 0.2, 1.0)
	ls.font_size = 22
	ls.outline_size = 5
	ls.outline_color = Color.WHITE
	lbl.label_settings = ls
	lbl.reset_size()
	lbl.position = Vector2(-lbl.size.x * 0.5, -lbl.size.y * 0.5)
	var tw: Tween = scene.create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(holder, "global_position", holder.global_position + Vector2(0, -70), 1.1)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.1)
	tw.finished.connect(holder.queue_free)


func _on_fishing_finished(result: Dictionary) -> void:
	var caught: bool = bool(result.get("success", false))
	var player: Node2D = _fishing_player
	if is_instance_valid(_fishing_line):
		_fishing_line.queue_free()
		_fishing_line = null
	var roster := get_node_or_null("/root/CatRoster")
	if caught and roster != null and not _persistent_cat_id.is_empty():
		roster.record_fed(_persistent_cat_id, 1, 5 + (_fishing_difficulty - 1) * 2)
		_fish_wanted_until_msec = 0
		_slots_visible_until_msec = Time.get_ticks_msec() + 7000
		var fx: Node2D = _CatHeartsFx.new()
		fx.count = 8
		add_child(fx)
		_hold_still(4.5, player)
		_show_name_bubble()
		# Günlük sınır dolmadıysa kedi yemeği bitirince yeniden balık ister (art arda besleme için sevmeye gerek kalmaz).
		if roster.can_ask_fish(_persistent_cat_id):
			_fish_wanted_until_msec = Time.get_ticks_msec() + FISH_REQUEST_MSEC
	else:
		# Balık kaçtı: kedi isteğini bir süre daha tutar, oyuncu tekrar deneyebilir.
		_fish_wanted_until_msec = maxi(_fish_wanted_until_msec, Time.get_ticks_msec() + 30000)
	# Oyuncu eski yerine döner, sonra serbest kalır.
	if is_instance_valid(player):
		await _move_player_to(player, _fishing_player_home, FISHING_WALK_SECONDS)
	_end_fishing()


func _end_fishing() -> void:
	_fishing_active = false
	if is_instance_valid(_fishing_line):
		_fishing_line.queue_free()
	_fishing_line = null
	if is_instance_valid(_fishing_player):
		_fishing_player.process_mode = _fishing_player_prev_mode as Node.ProcessMode
	_fishing_player = null


func _exit_tree() -> void:
	# Minigame ya da menü sürerken kedi sahneden çıkarsa oyuncu donuk kalmasın.
	if _fishing_active:
		_end_fishing()
	if is_instance_valid(_choice_menu):
		_choice_menu.queue_free()
	if is_instance_valid(_choice_player):
		_choice_player.process_mode = _choice_player_prev_mode as Node.ProcessMode
		_choice_player = null


func _show_name_bubble() -> void:
	var cat_name: String = get_cat_name()
	if cat_name.is_empty():
		return
	# Köylü isim etiketiyle aynı yazı stili (kutusuz, konturlu); konuşma balonu değil.
	if is_instance_valid(_nameplate):
		return   # kalıcı isim etiketi zaten görünüyor
	var old := get_node_or_null("CatNameLabel")
	if old != null:
		old.queue_free()
	var lbl := Label.new()
	lbl.name = "CatNameLabel"
	lbl.text = cat_name
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 30
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lbl)
	NpcOverheadUi.apply_nameplate_text_style(lbl)
	lbl.reset_size()
	lbl.position = Vector2(-lbl.size.x * 0.5, -88.0)
	var tw := lbl.create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.4)
	tw.tween_callback(lbl.queue_free)


## Oyuncunun etkileşim alanı bu Area2D'yi "interactables" grubundan bulur (köylülerdeki InteractionArea gibi); basılı tutma
## kancaları (_on_interact_button_pressed, can_interact, Show/HideInteractButton, set_interact_hold_progress) bu düğümün sahibindedir.
func _setup_pet_interactable() -> void:
	if get_node_or_null("PetInteractable") != null:
		return
	var area := Area2D.new()
	area.name = "PetInteractable"
	area.add_to_group("interactables")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 36.0
	shape.shape = circle
	shape.position = Vector2(0, -14)
	area.add_child(shape)
	add_child(area)


func get_current_color_variant() -> Color:
	if _sprite == null:
		return Color(1.0, 1.0, 1.0, 1.0)
	return _sprite.self_modulate


func _auto_align_sprite_to_collision_bottom() -> void:
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col == null:
		return
	var rect := col.shape as RectangleShape2D
	if rect == null:
		return
	var sf := _sprite.sprite_frames
	if sf == null:
		return
	var base_anim: String = ANIM_IDLE if sf.has_animation(ANIM_IDLE) else String(sf.get_animation_names()[0])
	var tex := sf.get_frame_texture(base_anim, 0)
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return
	var used: Rect2i = img.get_used_rect()
	if used.size.y <= 0:
		return
	var tex_h: float = float(tex.get_height())
	var used_bottom_rel_to_origin: float = float(used.position.y + used.size.y) - (tex_h * 0.5)
	var collision_bottom: float = col.position.y + (rect.size.y * 0.5)
	_sprite.position.y = collision_bottom - used_bottom_rel_to_origin + sprite_collision_foot_offset


func _has_cat_sheet_assets() -> bool:
	return ResourceLoader.exists(CAT_SHEET_IDLE) \
		and ResourceLoader.exists(CAT_SHEET_WALK) \
		and ResourceLoader.exists(CAT_SHEET_RUN) \
		and ResourceLoader.exists(CAT_SHEET_JUMP_UP) \
		and ResourceLoader.exists(CAT_SHEET_JUMP_DOWN) \
		and ResourceLoader.exists(CAT_SHEET_SLEEP)


func _add_sheet_animation(frames: SpriteFrames, anim_name: String, sheet_path: String, frame_count: int, speed: float, looped: bool) -> bool:
	var tex := load(sheet_path) as Texture2D
	if tex == null or frame_count <= 0:
		return false
	var tw: int = tex.get_width()
	var th: int = tex.get_height()
	if tw <= 0 or th <= 0:
		return false
	var frame_w: int = int(floor(float(tw) / float(frame_count)))
	if frame_w <= 0:
		return false
	frames.add_animation(anim_name)
	frames.set_animation_loop(anim_name, looped)
	frames.set_animation_speed(anim_name, speed)
	for i in range(frame_count):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(Vector2(float(i * frame_w), 0.0), Vector2(float(frame_w), float(th)))
		frames.add_frame(anim_name, at)
	return true


func _build_sprite_frames_from_sheets() -> SpriteFrames:
	var frames := SpriteFrames.new()
	var ok := true
	ok = ok and _add_sheet_animation(frames, ANIM_IDLE, CAT_SHEET_IDLE, 12, 12.0, true)
	ok = ok and _add_sheet_animation(frames, ANIM_WALK, CAT_SHEET_WALK, 8, 10.0, true)
	ok = ok and _add_sheet_animation(frames, ANIM_RUN, CAT_SHEET_RUN, 8, 14.0, true)
	ok = ok and _add_sheet_animation(frames, ANIM_JUMP_UP, CAT_SHEET_JUMP_UP, 4, 9.0, false)
	ok = ok and _add_sheet_animation(frames, ANIM_JUMP_DOWN, CAT_SHEET_JUMP_DOWN, 4, 9.0, false)
	ok = ok and _add_sheet_animation(frames, ANIM_SLEEP, CAT_SHEET_SLEEP, 8, 6.0, true)
	return frames if ok else null


func _get_sorter_sprite_height() -> float:
	var sf := _sprite.sprite_frames
	if sf == null or not sf.has_animation(_sprite.animation):
		return 22.0
	var tex: Texture2D = sf.get_frame_texture(_sprite.animation, _sprite.frame)
	if tex == null:
		return 22.0
	return float(tex.get_height())


func _get_sprite_bottom_local_offset() -> float:
	var sf := _sprite.sprite_frames
	if sf == null or not sf.has_animation(_sprite.animation):
		return _sprite.position.y + (_get_sorter_sprite_height() * 0.5)
	var tex: Texture2D = sf.get_frame_texture(_sprite.animation, _sprite.frame)
	if tex == null:
		return _sprite.position.y + (_get_sorter_sprite_height() * 0.5)
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return _sprite.position.y + (float(tex.get_height()) * 0.5)
	var used: Rect2i = img.get_used_rect()
	if used.size.y <= 0:
		return _sprite.position.y + (float(tex.get_height()) * 0.5)
	var tex_h: float = float(tex.get_height())
	var used_bottom_rel_to_tex_center: float = float(used.position.y + used.size.y) - (tex_h * 0.5)
	return _sprite.position.y + used_bottom_rel_to_tex_center


func _get_foot_y_for_sort() -> float:
	# Worker ile birebir ayni referans: body'nin global Y'si.
	return global_position.y


func _get_collision_bottom_local_offset() -> float:
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col == null:
		return _sprite.position.y + (_get_sorter_sprite_height() * 0.5)
	var rect := col.shape as RectangleShape2D
	if rect == null:
		return _sprite.position.y + (_get_sorter_sprite_height() * 0.5)
	return col.position.y + (rect.size.y * 0.5)


func _calculate_z_index_from_foot_y(foot_y: float) -> int:
	const CAMPFIRE_Z_INDEX: int = 5
	const WATER_Z_INDEX: int = 20
	const MIN_Z_INDEX: int = CAMPFIRE_Z_INDEX + 1
	const MAX_Z_INDEX: int = WATER_Z_INDEX - 1
	var min_foot_y: float = minf(depth_sort_min_y, depth_sort_max_y)
	var max_foot_y: float = maxf(depth_sort_min_y, depth_sort_max_y)
	var range_foot_y: float = max_foot_y - min_foot_y
	if range_foot_y <= 0.0:
		return int((MIN_Z_INDEX + MAX_Z_INDEX) / 2)
	var normalized_foot_y: float = clampf((foot_y - min_foot_y) / range_foot_y, 0.0, 1.0)
	var z_index_range: int = MAX_Z_INDEX - MIN_Z_INDEX
	return MIN_Z_INDEX + int(normalized_foot_y * float(z_index_range))


func _update_depth_sorting() -> void:
	var foot_y: float = _get_foot_y_for_sort()
	var new_z: int = _calculate_z_index_from_foot_y(foot_y)
	new_z += depth_sort_z_offset
	new_z = clampi(new_z, 6, 19)
	if z_index != new_z:
		z_index = new_z


func _post_move_fix_roof_roam_if_on_ground() -> void:
	if state != CatState.ROOF_ROAM:
		return
	if roof_target.is_empty():
		_roof_roam_fell_to_ground()
		return
	var seg_y: float = float(roof_target.get("y", global_position.y))
	if global_position.y > seg_y + roof_roam_fell_px_below_segment:
		_roof_roam_fell_to_ground()


func _roof_roam_fell_to_ground() -> void:
	if debug_motion:
		pass
	velocity = Vector2.ZERO
	roof_target = {}
	_was_near_roof_x = false
	_roof_waiting_next_target = false
	_is_lower_roof_transition = false
	landing_grace_timer = 0.0
	roof_try_timer = maxf(roof_try_timer, roof_retry_cooldown * 0.35)
	post_roof_ground_cooldown = randf_range(post_roof_ground_cooldown_min * 0.22, post_roof_ground_cooldown_max * 0.42)
	_post_roof_y_lock_timer = maxf(_post_roof_y_lock_timer, post_roof_y_stabilize_seconds)
	state = CatState.ROAM
	_enter_ground_line_mode()
	_pick_new_roam_target()


func _update_roam_seek_stuck_watchdog(delta: float) -> void:
	if state != CatState.ROAM and state != CatState.SEEK_ROOF:
		_roam_stuck_accum = 0.0
		return
	var thr: float = stuck_min_movement_px * stuck_min_movement_px
	if global_position.distance_squared_to(_roam_stuck_last_pos) > thr:
		_roam_stuck_accum = 0.0
		_roam_stuck_last_pos = global_position
		return
	_roam_stuck_accum += delta
	if _roam_stuck_accum < stuck_repick_after_seconds:
		return
	_roam_stuck_accum = 0.0
	_roam_stuck_last_pos = global_position
	if state == CatState.SEEK_ROOF:
		if debug_motion:
			pass
		_abort_seek_roof_to_roam()
	else:
		if debug_motion:
			pass
		_pick_new_roam_target()


func _abort_seek_roof_to_roam() -> void:
	roof_target = {}
	_seek_roof_elapsed = 0.0
	roof_try_timer = maxf(roof_try_timer, roof_retry_cooldown * 0.5)
	_post_roof_y_lock_timer = maxf(_post_roof_y_lock_timer, post_roof_y_stabilize_seconds * 0.7)
	_enter_roam_state()
	_pick_new_roam_target()


func _clamp_float_to_roam_bounds(delta: float) -> void:
	match state:
		CatState.JUMP_TO_ROOF, CatState.ROOF_ROAM:
			return
		_:
			pass
	var x0: float = roam_bounds.position.x
	var x1: float = roam_bounds.end.x
	var y0: float = roam_bounds.position.y
	var y1: float = roam_bounds.end.y
	global_position.x = clampf(global_position.x, x0, x1)
	# Çatıda uyku: Y'yi yürüme bandına çekme (yoksa kedi yere "ışınlanır").
	if state == CatState.SLEEP:
		return
	# Üst kata yürürken (yürüme bandının üstünde) Y'yi banda zorlama.
	if state == CatState.SEEK_ROOF and global_position.y < y0 - 6.0:
		global_position.x = clampf(global_position.x, x0, x1)
		return
	# Band sinirina body center ile degil sprite ayagiyla saygi goster.
	var foot_y: float = _get_foot_y_for_sort()
	var target_foot_y: float = clampf(foot_y, y0, y1)
	var dy_needed: float = target_foot_y - foot_y
	var descend_speed: float = float_band_descend_speed
	# Bandin belirgin ustundeyken (catidan inerken) daha yavas indir.
	if foot_y < y0 - 10.0:
		descend_speed = minf(float_band_descend_speed, float_band_descend_speed_from_roof)
	# Delta spike anlarinda 1 framede 5-10+ px snap olmasini engelle.
	var max_step: float = descend_speed * minf(delta, 0.05)
	if absf(dy_needed) > max_step:
		global_position.y += signf(dy_needed) * max_step
	else:
		global_position.y += dy_needed
	if global_position.y >= roam_bounds.position.y - 2.0:
		_force_descend_anim_until_y = INF


func _uses_slide_physics_for_state(s: CatState) -> bool:
	return s == CatState.JUMP_TO_ROOF or s == CatState.ROOF_ROAM


func _integrate_float_motion(delta: float) -> void:
	# Koyluler gibi serbest Y: float durumlarda collision'a takilmadan konum ilerlet.
	global_position += velocity * delta


func _debug_log_motion_if_needed() -> void:
	if not debug_motion:
		return
	_debug_physics_tick += 1
	if _debug_physics_tick % 45 != 0:
		return
	var foot_y: float = _get_foot_y_for_sort()
	var p: Node = get_parent()
	var pname: String = String(p.name) if is_instance_valid(p) else "null"


func _update_facing() -> void:
	# Sevilirken oyuncuya döner.
	if Time.get_ticks_msec() < _pet_face_until_msec and absf(_pet_face_x - global_position.x) > 6.0:
		_sprite.flip_h = _pet_face_x < global_position.x
		return
	var face_x := 0.0
	match state:
		CatState.ROAM, CatState.IDLE:
			face_x = roam_target.x - global_position.x
		CatState.CHASE_OTHER:
			var pt: Node2D = _get_play_target_node()
			if pt != null:
				face_x = pt.global_position.x - global_position.x
			else:
				face_x = velocity.x
		CatState.FLEE_OTHER:
			face_x = velocity.x
		CatState.SEEK_ROOF:
			face_x = float(roof_target.get("center_x", global_position.x)) - global_position.x
		CatState.JUMP_TO_ROOF, CatState.ROOF_ROAM:
			face_x = velocity.x
		CatState.SLEEP:
			return
	if absf(face_x) > 6.0:
		_sprite.flip_h = face_x < 0.0


func _update_animation() -> void:
	var desired := ANIM_IDLE
	match state:
		CatState.ROAM:
			# ROAM float modunda is_on_floor guvenilir degil; sadece bandin ustunde yukseklik farki varsa jump anim kullan.
			var force_descend_anim: bool = _force_descend_anim_until_y < INF and global_position.y < _force_descend_anim_until_y
			if (force_descend_anim or global_position.y < (roam_bounds.position.y - 8.0)) and _has_animation(ANIM_JUMP_DOWN):
				desired = ANIM_JUMP_DOWN if velocity.y >= -20.0 else ANIM_JUMP_UP
			elif absf(velocity.x) > run_anim_speed_threshold and _has_animation(ANIM_RUN):
				desired = ANIM_RUN
			else:
				desired = ANIM_WALK if velocity.length_squared() > 200.0 else ANIM_IDLE
		CatState.CHASE_OTHER, CatState.FLEE_OTHER:
			var speed_x: float = absf(velocity.x)
			if speed_x > run_anim_speed_threshold and _has_animation(ANIM_RUN):
				desired = ANIM_RUN
			elif speed_x > 22.0:
				desired = ANIM_WALK if _has_animation(ANIM_WALK) else ANIM_IDLE
			else:
				desired = ANIM_IDLE
		CatState.IDLE:
			desired = ANIM_IDLE
		CatState.SEEK_ROOF:
			# Cati ustunden inis denemesinde walk yerine jump/fall animasyonu kullan.
			if global_position.y < (roam_bounds.position.y - 6.0) and _has_animation(ANIM_JUMP_DOWN):
				desired = ANIM_JUMP_UP if velocity.y < -18.0 else ANIM_JUMP_DOWN
			else:
				desired = ANIM_WALK
		CatState.JUMP_TO_ROOF:
			if _is_lower_roof_transition and _has_animation(ANIM_JUMP_DOWN):
				desired = ANIM_JUMP_DOWN
			else:
				desired = ANIM_JUMP_UP if velocity.y < -18.0 else ANIM_JUMP_DOWN
		CatState.ROOF_ROAM:
			# Cati uzerinden inerken/fall durumunda walk/run'a dusme.
			if not is_on_floor() and _has_animation(ANIM_JUMP_DOWN):
				desired = ANIM_JUMP_UP if velocity.y < -18.0 else ANIM_JUMP_DOWN
			elif absf(velocity.x) > run_anim_speed_threshold and _has_animation(ANIM_RUN):
				desired = ANIM_RUN
			else:
				desired = ANIM_WALK if absf(velocity.x) > 8.0 else ANIM_IDLE
		CatState.SLEEP:
			desired = ANIM_SLEEP
	_safe_play(desired)


func _has_animation(anim_name: String) -> bool:
	var sf := _sprite.sprite_frames
	return sf != null and sf.has_animation(anim_name)


func _safe_play(anim_name: String) -> void:
	var sf := _sprite.sprite_frames
	if sf == null:
		return
	var names := sf.get_animation_names()
	if names.is_empty():
		return
	var play_name := anim_name
	if not sf.has_animation(play_name):
		play_name = ANIM_IDLE if sf.has_animation(ANIM_IDLE) else String(names[0])
	var sn := StringName(play_name)
	if _last_anim == sn and _sprite.is_playing():
		return
	_last_anim = sn
	_sprite.play(play_name)


func _apply_gravity(delta: float) -> void:
	velocity.y += gravity_strength * delta


func _move_float_toward(target: Vector2, speed: float, delta: float) -> void:
	var dir := (target - global_position).normalized()
	var desired := dir * speed
	velocity = velocity.move_toward(desired, 260.0 * delta)


## Yer / float modunda X hedefe gider, Y'yi band içinde ayrı hedefe sürükler (köylü bandı).
func _move_float_on_ground(target: Vector2, speed: float, delta: float, lock_y: bool = false) -> void:
	var y0: float = roam_bounds.position.y
	var y1: float = roam_bounds.end.y
	roam_band_y_target = clampf(roam_band_y_target, y0, y1)
	var to_x: float = target.x - global_position.x
	var desired_x_v: float = 0.0
	if absf(to_x) > 3.0:
		desired_x_v = signf(to_x) * speed
	velocity.x = move_toward(velocity.x, desired_x_v, 280.0 * delta)
	if lock_y:
		velocity.y = move_toward(velocity.y, 0.0, band_y_wander_accel * delta)
	else:
		var y_err: float = roam_band_y_target - global_position.y
		var desired_y_v: float = clampf(y_err * 2.5, -band_y_wander_max_speed, band_y_wander_max_speed)
		velocity.y = move_toward(velocity.y, desired_y_v, band_y_wander_accel * delta)


func _pick_new_roam_target() -> void:
	_roam_stuck_accum = 0.0
	_roam_stuck_last_pos = global_position
	_roam_before_idle_timer = maxf(_roam_before_idle_timer, min_roam_before_idle_seconds)
	roam_target = Vector2(
		randf_range(roam_bounds.position.x, roam_bounds.end.x),
		randf_range(roam_bounds.position.y, roam_bounds.end.y)
	)
	if _post_roof_y_lock_timer > 0.0:
		roam_band_y_target = clampf(global_position.y, roam_bounds.position.y, roam_bounds.end.y)
	else:
		roam_band_y_target = randf_range(roam_bounds.position.y, roam_bounds.end.y)
	if randf() < roam_burst_chance_on_new_target:
		_burst_timer = randf_range(roam_burst_seconds_min, roam_burst_seconds_max)
	_ensure_roam_target_escape_from_position()


func _ensure_roam_target_escape_from_position() -> void:
	var x0: float = roam_bounds.position.x
	var x1: float = roam_bounds.end.x
	var y0: float = roam_bounds.position.y
	var y1: float = roam_bounds.end.y
	var min_dx: float = roam_target_min_dx
	if absf(roam_target.x - global_position.x) < min_dx:
		var push: float = randf_range(min_dx, 260.0)
		if randf() < 0.5:
			roam_target.x = clampf(global_position.x + push, x0, x1)
		else:
			roam_target.x = clampf(global_position.x - push, x0, x1)
		if absf(roam_target.x - global_position.x) < min_dx * 0.85:
			roam_target.x = clampf(global_position.x + min_dx, x0, x1)
	if _post_roof_y_lock_timer <= 0.0 and absf(roam_band_y_target - global_position.y) < 5.0:
		roam_band_y_target = y1 if randf() < 0.5 else y0
		if absf(roam_band_y_target - global_position.y) < 3.0:
			roam_band_y_target = clampf(global_position.y + 9.0, y0, y1)


func _horizontal_dist_to_segment(px: float, L: float, R: float) -> float:
	if px < L:
		return L - px
	if px > R:
		return px - R
	return 0.0


func _pick_roof_seek_target(roof_points: Array[Dictionary], seek_upper_tier: bool) -> Dictionary:
	var px: float = global_position.x
	var py: float = global_position.y
	var y0: float = roam_bounds.position.y
	var cands: Array[Dictionary] = []
	if seek_upper_tier:
		if roof_target.is_empty():
			return {}
		var cy: float = float(roof_target.get("y", py))
		for roof in roof_points:
			var sy: float = float(roof.get("y", cy))
			if sy >= cy - 10.0:
				continue
			var gap: float = cy - sy
			if gap > roof_climb_tier_max_delta_y or gap < 14.0:
				continue
			var L: float = float(roof.get("left_x", px))
			var R: float = float(roof.get("right_x", px))
			if _horizontal_dist_to_segment(px, L, R) > roof_climb_horizontal_tolerance:
				continue
			cands.append(roof)
	else:
		for roof in roof_points:
			var sy: float = float(roof.get("y", py))
			if sy >= py - 8.0:
				continue
			var vert: float = py - sy
			if vert > roof_first_tier_max_delta_y or vert < 12.0:
				continue
			var L: float = float(roof.get("left_x", px))
			var R: float = float(roof.get("right_x", px))
			if _horizontal_dist_to_segment(px, L, R) > roof_horizontal_pick_range:
				continue
			cands.append(roof)
	return _weighted_random_roof_pick(cands)


func _weighted_random_roof_pick(cands: Array[Dictionary]) -> Dictionary:
	if cands.is_empty():
		return {}
	if cands.size() == 1:
		return cands[0]
	var wsum: float = 0.0
	var weights: Array[float] = []
	for roof in cands:
		var cx: float = float(roof.get("center_x", global_position.x))
		var w: float = 1.0 / (1.0 + absf(global_position.x - cx) * 0.0045)
		w *= 0.65 + randf() * 0.85
		weights.append(w)
		wsum += w
	var r: float = randf() * wsum
	var acc: float = 0.0
	for i in range(cands.size()):
		acc += weights[i]
		if r <= acc:
			return cands[i]
	return cands[cands.size() - 1]


func _pick_lower_roof_target(roof_points: Array[Dictionary]) -> Dictionary:
	if roof_target.is_empty():
		return {}
	var px: float = global_position.x
	var cy: float = float(roof_target.get("y", global_position.y))
	var cands: Array[Dictionary] = []
	for roof in roof_points:
		var sy: float = float(roof.get("y", cy))
		if sy <= cy + 8.0:
			continue
		var drop: float = sy - cy
		if drop < 12.0 or drop > roof_descend_tier_max_delta_y:
			continue
		var L: float = float(roof.get("left_x", px))
		var R: float = float(roof.get("right_x", px))
		if _horizontal_dist_to_segment(px, L, R) > roof_descend_horizontal_tolerance:
			continue
		cands.append(roof)
	return _weighted_random_roof_pick(cands)


func _pick_fallback_nearest_reachable_roof(roof_points: Array[Dictionary]) -> Dictionary:
	var best: Dictionary = {}
	var best_dist: float = INF
	var py: float = global_position.y
	for roof in roof_points:
		var sy: float = float(roof.get("y", py))
		if sy >= py - 4.0:
			continue
		var vert: float = py - sy
		if vert > roof_first_tier_max_delta_y + 28.0:
			continue
		var center := Vector2(float(roof.get("center_x", 0.0)), sy)
		var d: float = global_position.distance_squared_to(center)
		if d < best_dist:
			best_dist = d
			best = roof
	return best


func _pick_any_roof_nearest(roof_points: Array[Dictionary]) -> Dictionary:
	var best: Dictionary = {}
	var best_dist: float = INF
	for roof in roof_points:
		var center := Vector2(float(roof.get("center_x", global_position.x)), float(roof.get("y", global_position.y)))
		var d: float = global_position.distance_squared_to(center)
		if d < best_dist:
			best_dist = d
			best = roof
	return best


func _start_roof_jump() -> void:
	state = CatState.JUMP_TO_ROOF
	var target := Vector2(float(roof_target.get("center_x", global_position.x)), float(roof_target.get("y", global_position.y - 80.0)) - 6.0)
	var t := maxf(0.3, jump_duration)
	velocity.x = (target.x - global_position.x) / t
	velocity.y = (target.y - global_position.y - (0.5 * gravity_strength * t * t)) / t


func _enter_roof_roam() -> void:
	state = CatState.ROOF_ROAM
	landing_grace_timer = 0.0
	roof_session_time = 0.0
	_was_near_roof_x = false
	_roof_waiting_next_target = false
	_is_lower_roof_transition = false
	_pick_new_roof_x_target()
	if debug_motion:
		pass


func _pick_new_roof_x_target() -> void:
	var left := float(roof_target.get("left_x", global_position.x - 40.0))
	var right := float(roof_target.get("right_x", global_position.x + 40.0))
	if right < left:
		var t := left
		left = right
		right = t
	var span: float = right - left
	if span < 10.0:
		roof_target_x = (left + right) * 0.5
	else:
		roof_target_x = randf_range(left, right)
		if absf(roof_target_x - global_position.x) < roof_target_min_travel_x:
			var half := (left + right) * 0.5
			if global_position.x <= half:
				roof_target_x = minf(right, global_position.x + roof_target_min_travel_x)
			else:
				roof_target_x = maxf(left, global_position.x - roof_target_min_travel_x)
			if absf(roof_target_x - global_position.x) < roof_target_min_travel_x * 0.6:
				roof_target_x = left if randf() < 0.5 else right
	_roof_turn_cooldown = randf_range(roof_turn_cooldown_min, roof_turn_cooldown_max)


func _enter_idle() -> void:
	state = CatState.IDLE
	_arrivals_without_idle = 0
	var m: float = _get_weather_discomfort()
	state_timer = randf_range(min_idle_time, max_idle_time) * (1.0 + m * 0.55)
	_idle_expected_duration = state_timer
	_idle_elapsed = 0.0
	_idle_reentry_cooldown_timer = idle_reentry_cooldown_seconds
	if debug_motion and debug_idle_timing:
		pass


func _enter_sleep() -> void:
	state = CatState.SLEEP
	state_timer = randf_range(min_sleep_time, max_sleep_time)


func _fail_roof_and_resume() -> void:
	if debug_motion:
		print("[Cat %s] fail_roof -> ROAM (y bandına yumuşak dönüş) pos=%s vel=%s" % [name, global_position, velocity])
	# Roof fail sonrasi havada asiri hiz birikimiyle run animasyonuna dusmesin.
	velocity.x = clampf(velocity.x, -roam_burst_speed, roam_burst_speed)
	velocity.y = 0.0
	_force_descend_anim_until_y = roam_bounds.position.y - 2.0
	roof_try_timer = roof_retry_cooldown
	post_roof_ground_cooldown = randf_range(post_roof_ground_cooldown_min * 0.45, post_roof_ground_cooldown_max * 0.7)
	roof_target = {}
	_was_near_roof_x = false
	_roof_waiting_next_target = false
	_is_lower_roof_transition = false
	_enter_roam_state()
	_post_roof_y_lock_timer = maxf(_post_roof_y_lock_timer, post_roof_y_stabilize_seconds)
	_enter_ground_line_mode()
	_pick_new_roam_target()


func _enter_roam_state() -> void:
	state = CatState.ROAM
	_roam_state_elapsed = 0.0


func _enter_ground_line_mode() -> void:
	_ground_line_lock_timer = maxf(_ground_line_lock_timer, ground_line_lock_seconds)
	roam_band_y_target = roam_bounds.end.y
	# Cati/ust kat donusunde sert Y snap yapma; clamp fonksiyonu yumusak indirir.


func can_start_social_play() -> bool:
	if _play_cooldown > 0.0:
		return false
	# IDLE suresini korumak icin sosyal oyun sadece ROAM'da baslasin.
	return state == CatState.ROAM


func is_in_play_state() -> bool:
	return state == CatState.CHASE_OTHER or state == CatState.FLEE_OTHER


func begin_chase(other: Node2D) -> void:
	if other == null or other == self:
		return
	if not other.is_in_group("cats"):
		return
	if not can_start_social_play():
		return
	if state == CatState.SLEEP or state == CatState.SEEK_ROOF:
		return
	_play_target_ref = weakref(other)
	_play_timer = randf_range(chase_seconds_min, chase_seconds_max)
	_play_stall_timer = 0.0
	state = CatState.CHASE_OTHER


func begin_flee(from: Node2D) -> void:
	if from == null or from == self:
		return
	if state == CatState.SLEEP or state == CatState.ROOF_ROAM or state == CatState.JUMP_TO_ROOF or state == CatState.SEEK_ROOF:
		return
	if not can_start_social_play():
		return
	_play_target_ref = weakref(from)
	_play_timer = randf_range(flee_seconds_min, flee_seconds_max)
	# Kovalayanla süreyi yakın tut: biri erken bitince diğeri uzun süre tek başına koşmasın.
	if from.has_method("get_play_time_remaining"):
		var partner_left: float = float(from.get_play_time_remaining())
		if partner_left > 0.0:
			_play_timer = clampf(partner_left + randf_range(-0.45, 0.45), flee_seconds_min, flee_seconds_max)
	_play_stall_timer = 0.0
	state = CatState.FLEE_OTHER


func _get_play_target_node() -> Node2D:
	if _play_target_ref == null:
		return null
	var n: Variant = _play_target_ref.get_ref()
	if n is Node2D:
		return n as Node2D
	return null


func _is_partner_play_active(partner: Node2D) -> bool:
	if partner == null:
		return false
	if not is_instance_valid(partner):
		return false
	if not partner.has_method("is_in_play_state"):
		return true
	return bool(partner.is_in_play_state())


func get_play_time_remaining() -> float:
	return _play_timer


func _end_social_play() -> void:
	_play_target_ref = null
	_play_timer = 0.0
	_play_stall_timer = 0.0
	_play_cooldown = randf_range(play_cooldown_min, play_cooldown_max)
	velocity = velocity.lerp(Vector2.ZERO, 0.35)
	_enter_roam_state()
	_pick_new_roam_target()


func _get_weather_discomfort() -> float:
	var wm: Node = get_node_or_null("/root/WeatherManager")
	if wm == null:
		return 0.0
	var r: float = clampf(float(wm.rain_intensity), 0.0, 1.0)
	var storm_bump: float = 0.38 if bool(wm.storm_active) else 0.0
	return clampf(r * 0.88 + storm_bump, 0.0, 1.0)


func _apply_weather_wind(delta: float) -> void:
	var wm: Node = get_node_or_null("/root/WeatherManager")
	if wm == null:
		return
	var ws: float = clampf(float(wm.wind_strength), 0.0, 1.5)
	if ws < 0.02:
		return
	var ang: float = deg_to_rad(float(wm.wind_direction_angle))
	# WeatherManager: 0° = sağa (+X). Y bileşeni hafif serpinti.
	var push_x: float = cos(ang) * ws * weather_wind_push
	var push_y: float = sin(ang) * ws * weather_wind_push * 0.35
	velocity.x += push_x * delta
	velocity.y += push_y * delta
