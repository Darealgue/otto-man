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
			print("[Cat %s] roof seek skip: roam too short %.2f/%.2f" % [name, _roam_state_elapsed, min_roof_seek_elapsed])
		return false
	if _arrivals_without_idle >= max(0, force_idle_after_arrivals_without_idle) and _roam_before_idle_timer <= 0.0 and _idle_reentry_cooldown_timer <= 0.0:
		if debug_motion and debug_behavior_decisions:
			print("[Cat %s] roof seek skip: pending forced idle (arrivals_without_idle=%d)" % [name, _arrivals_without_idle])
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
						print("[Cat %s] ROAM -> IDLE (forced by roam duration %.2fs)" % [name, _roam_state_elapsed])
					_enter_idle()
					entered_idle = true
				elif randf() < idle_time_based_chance_per_second * delta:
					if debug_motion and debug_behavior_decisions:
						print("[Cat %s] ROAM -> IDLE (time chance, roam_elapsed=%.2fs)" % [name, _roam_state_elapsed])
					_enter_idle()
					entered_idle = true
			if not entered_idle and absf(global_position.x - roam_target.x) < 22.0 and absf(global_position.y - roam_band_y_target) < 10.0:
				var should_force_idle: bool = _arrivals_without_idle >= max(0, force_idle_after_arrivals_without_idle)
				if should_force_idle or randf() < idle_roll:
					if debug_motion and debug_behavior_decisions:
						print("[Cat %s] ROAM arrival -> IDLE (forced=%s idle_roll=%.2f arrivals_without_idle=%d)" % [
							name, str(should_force_idle), idle_roll, _arrivals_without_idle
						])
					_enter_idle()
				else:
					_arrivals_without_idle += 1
					if debug_motion and debug_behavior_decisions:
						print("[Cat %s] ROAM arrival -> new target (idle_roll miss, arrivals_without_idle=%d)" % [
							name, _arrivals_without_idle
						])
					_pick_new_roam_target()
		CatState.IDLE:
			is_gravity_mode = false
			_idle_elapsed += delta
			velocity = velocity.move_toward(Vector2.ZERO, 380.0 * delta)
			_apply_weather_wind(delta)
			if state_timer <= 0.0:
				if debug_motion and debug_idle_timing:
					print("[Cat %s] IDLE bitti (timer) elapsed=%.2fs expected=%.2fs delta=%.3f pos=%s" % [
						name, _idle_elapsed, _idle_expected_duration, delta, global_position
					])
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
		print("[Cat %s] state %d -> %d pos=%s vel=%s on_floor=%s" % [
			name, int(state_at_start), int(state), global_position, velocity, is_on_floor()
		])

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
		print("[Cat %s] ROOF_ROAM -> ROAM (yer katı, seg_y=%s) pos=%s" % [name, roof_target.get("y", "?"), global_position])
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
			print("[Cat %s] stuck watchdog: abort SEEK_ROOF pos=%s" % [name, global_position])
		_abort_seek_roof_to_roam()
	else:
		if debug_motion:
			print("[Cat %s] stuck watchdog: new roam target pos=%s" % [name, global_position])
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
	print("[Cat %s] state=%d pos=%s vel=%s floor=%s roam_y=[%.1f,%.1f] foot_y=%.1f z=%d parent=%s" % [
		name, int(state), global_position, velocity, is_on_floor(),
		roam_bounds.position.y, roam_bounds.end.y, foot_y, z_index, pname
	])


func _update_facing() -> void:
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
		print("[Cat %s] enter ROOF_ROAM pos=%s roof_y=%s" % [name, global_position, roof_target.get("y", "?")])


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
		print("[Cat %s] IDLE basladi expected=%.2fs (min=%.2f max=%.2f weather=%.2f) pos=%s" % [
			name, _idle_expected_duration, min_idle_time, max_idle_time, m, global_position
		])


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
