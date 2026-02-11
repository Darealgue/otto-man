extends Node2D
## Köye gelen tüccarı temsil eden sprite. Merkeze yürüyerek girer, merkez civarında çoğunlukla oturur,
## gece geç saatte sabaha kadar uyur. Süre bitince yürüyerek çıkar.

enum State {
	WALKING_IN,
	IDLE,
	WALKING_OUT
}

var trader_id: String = ""
var current_state = State.WALKING_IN
# Tombul kısa boylu karakter → diğer NPC'lerden daha yavaş
var move_speed: float = 46.0
var target_x: float = 0.0
var entry_x: float = 0.0
var center_x: float = 0.0
var exit_x: float = 0.0
# Diğer NPC'lerle aynı dikey alan (cariye/worker: 0..25)
const VERTICAL_RANGE_MAX: float = 25.0
var _target_global_y: float = 0.0

# Merkez civarında gezinme (kamp ateşi etrafı)
const WANDER_RANGE_X: float = 140.0
const WANDER_REACH_THRESHOLD: float = 18.0

# Oturma: hedefe vardığında çoğu zaman oturur, süre bitince tekrar gezer
const SIT_CHANCE: float = 0.75
const SIT_DURATION_MIN: float = 8.0
const SIT_DURATION_MAX: float = 18.0

@onready var idle_sprite: Sprite2D = $IdleSprite
@onready var walk_sprite: Sprite2D = $WalkSprite
@onready var sit_sprite: Sprite2D = $SitSprite
@onready var sleep_sprite: Sprite2D = $SleepSprite

const WALK_FRAME_DURATION: float = 0.08
const IDLE_FRAME_DURATION: float = 0.12
const SIT_FRAME_DURATION: float = 0.12
const SLEEP_FRAME_DURATION: float = 0.15
var _walk_frame_timer: float = 0.0
var _idle_frame_timer: float = 0.0
var _sit_frame_timer: float = 0.0
var _sleep_frame_timer: float = 0.0
const IDLE_HFRAMES: int = 10
const WALK_HFRAMES: int = 14
const SIT_HFRAMES: int = 10
const SLEEP_HFRAMES: int = 10

var _is_sleeping: bool = false
var _is_sitting: bool = false
var _sit_until_time: float = 0.0

const SPRITE_OFFSET_Y: float = 48.0


func _ready() -> void:
	add_to_group("Villagers")
	target_x = center_x
	_show_walk_sprite()
	if idle_sprite:
		idle_sprite.hframes = IDLE_HFRAMES
		idle_sprite.frame = 0
	if walk_sprite:
		walk_sprite.hframes = WALK_HFRAMES
		walk_sprite.frame = 0
	if sit_sprite:
		sit_sprite.hframes = SIT_HFRAMES
		sit_sprite.frame = 0
	if sleep_sprite:
		sleep_sprite.hframes = SLEEP_HFRAMES
		sleep_sprite.frame = 0
	z_index = 6


func setup(p_trader_id: String, p_entry_x: float, p_center_x: float, p_exit_x: float, p_center_y: float = -26.0) -> void:
	trader_id = p_trader_id
	entry_x = p_entry_x
	center_x = p_center_x
	exit_x = p_exit_x
	# Yürüyebildiği alan diğer NPC'lerle aynı: y = 0..VERTICAL_RANGE_MAX
	_target_global_y = randf_range(0.0, VERTICAL_RANGE_MAX)
	global_position = Vector2(entry_x, _target_global_y)
	target_x = center_x
	current_state = State.WALKING_IN
	var dir = 1.0 if center_x >= entry_x else -1.0
	scale.x = dir
	_show_walk_sprite()


func start_leaving() -> void:
	if current_state == State.WALKING_OUT:
		return
	current_state = State.WALKING_OUT
	target_x = exit_x
	_target_global_y = randf_range(0.0, VERTICAL_RANGE_MAX)
	scale.x = -1.0 if exit_x < global_position.x else 1.0
	_show_walk_sprite()


func _show_idle_sprite() -> void:
	if idle_sprite:
		idle_sprite.visible = true
	if walk_sprite:
		walk_sprite.visible = false
	if sit_sprite:
		sit_sprite.visible = false
	if sleep_sprite:
		sleep_sprite.visible = false


func _show_walk_sprite() -> void:
	if walk_sprite:
		walk_sprite.visible = true
	if idle_sprite:
		idle_sprite.visible = false
	if sit_sprite:
		sit_sprite.visible = false
	if sleep_sprite:
		sleep_sprite.visible = false


func _show_sit_sprite() -> void:
	if sit_sprite:
		sit_sprite.visible = true
	if idle_sprite:
		idle_sprite.visible = false
	if walk_sprite:
		walk_sprite.visible = false
	if sleep_sprite:
		sleep_sprite.visible = false


func _show_sleep_sprite() -> void:
	if sleep_sprite:
		sleep_sprite.visible = true
	if idle_sprite:
		idle_sprite.visible = false
	if walk_sprite:
		walk_sprite.visible = false
	if sit_sprite:
		sit_sprite.visible = false


func _pick_wander_target() -> void:
	"""Merkez civarında rastgele bir nokta seç (gezinme hedefi)."""
	target_x = center_x + randf_range(-WANDER_RANGE_X, WANDER_RANGE_X)
	_target_global_y = randf_range(0.0, VERTICAL_RANGE_MAX)


func _handle_idle_wander(delta: float) -> void:
	var time_manager = get_node_or_null("/root/TimeManager")
	var current_hour: float = 12.0
	if time_manager and time_manager.has_method("get_hour"):
		current_hour = time_manager.get_hour()
	var wake_hour: float = 6.0
	var sleep_hour: float = 22.0
	if time_manager:
		wake_hour = float(time_manager.WAKE_UP_HOUR)
		sleep_hour = float(time_manager.SLEEP_HOUR)
	var is_night = current_hour >= sleep_hour or current_hour < wake_hour

	# Gece: sabaha kadar uyu
	if is_night:
		_is_sleeping = true
		_is_sitting = false
		_show_sleep_sprite()
		_sleep_frame_timer += delta
		if _sleep_frame_timer >= SLEEP_FRAME_DURATION:
			_sleep_frame_timer = 0.0
			if sleep_sprite:
				sleep_sprite.frame = (sleep_sprite.frame + 1) % SLEEP_HFRAMES
		return

	# Sabah: uykudan kalk
	if _is_sleeping:
		_is_sleeping = false
		_pick_wander_target()
		_show_walk_sprite()
		return

	# Gündüz: oturuyorsa süre dolana kadar otur
	if _is_sitting:
		_show_sit_sprite()
		_sit_frame_timer += delta
		if _sit_frame_timer >= SIT_FRAME_DURATION:
			_sit_frame_timer = 0.0
			if sit_sprite:
				sit_sprite.frame = (sit_sprite.frame + 1) % SIT_HFRAMES
		var now = Time.get_ticks_msec() / 1000.0
		if now >= _sit_until_time:
			_is_sitting = false
			_pick_wander_target()
		return

	# Gündüz: hedefe vardıysak çoğu zaman otur, bazen yeni hedef seç
	var dist_to_target = Vector2(global_position.x - target_x, global_position.y - _target_global_y).length()
	if dist_to_target < WANDER_REACH_THRESHOLD:
		if randf() < SIT_CHANCE:
			_is_sitting = true
			_sit_until_time = Time.get_ticks_msec() / 1000.0 + randf_range(SIT_DURATION_MIN, SIT_DURATION_MAX)
			_show_sit_sprite()
			return
		else:
			_pick_wander_target()

	_move_toward(target_x, delta)

	var dist_x = abs(global_position.x - target_x)
	var dist_y = abs(global_position.y - _target_global_y)
	var is_moving = dist_x > 3.0 or dist_y > 3.0
	if is_moving:
		_show_walk_sprite()
	else:
		_show_idle_sprite()
		_update_idle_animation(delta)


func _physics_process(delta: float) -> void:
	match current_state:
		State.WALKING_IN:
			_move_toward(target_x, delta)
			if abs(global_position.x - center_x) < 5.0:
				current_state = State.IDLE
				_pick_wander_target()
		State.IDLE:
			_handle_idle_wander(delta)
		State.WALKING_OUT:
			_move_toward(target_x, delta)
			if abs(global_position.x - exit_x) < 10.0:
				queue_free()

	# Köylüler birbirine çok girmesin (cariye/worker/trader arası mesafe)
	if visible:
		_apply_villager_separation()

	# Z-index: cariye/worker ile aynı (ayak Y'ye göre 6..19)
	var foot_y = get_foot_y_position()
	z_index = _calculate_z_index_from_foot_y(foot_y)


func _update_idle_animation(delta: float) -> void:
	if not idle_sprite or not idle_sprite.visible:
		return
	_idle_frame_timer += delta
	if _idle_frame_timer >= IDLE_FRAME_DURATION:
		_idle_frame_timer = 0.0
		idle_sprite.frame = (idle_sprite.frame + 1) % IDLE_HFRAMES


func _move_toward(x_target: float, delta: float) -> void:
	# Tek yerde walk animasyonu: hem giriş/çıkış hem gezerken aynı hızda (WALK_FRAME_DURATION)
	var dist_x = x_target - global_position.x
	var dist_y = _target_global_y - global_position.y
	var moving_x = abs(dist_x) > 2.0
	var moving_y = abs(dist_y) > 1.0

	if moving_x:
		var dir = sign(dist_x)
		global_position.x += dir * move_speed * delta
		scale.x = dir
	if moving_y:
		var y_dir = sign(dist_y)
		global_position.y += y_dir * move_speed * 0.5 * delta

	# Hareket varsa walk kareyi tek yerden ilerlet (giriş/gezinme/çıkış hep aynı hız)
	if (moving_x or moving_y) and walk_sprite and walk_sprite.visible:
		_walk_frame_timer += delta
		if _walk_frame_timer >= WALK_FRAME_DURATION:
			_walk_frame_timer = 0.0
			walk_sprite.frame = (walk_sprite.frame + 1) % WALK_HFRAMES


func _apply_villager_separation() -> void:
	# Çok hafif: sadece neredeyse üst üste gelince hafifçe it, alan dışına çıkmasın
	const MIN_SPACING: float = 10.0
	const STRENGTH: float = 0.06
	var villagers = get_tree().get_nodes_in_group("Villagers")
	var separation = Vector2.ZERO
	for other in villagers:
		if other == self or not is_instance_valid(other):
			continue
		if not other is Node2D:
			continue
		var other_pos = (other as Node2D).global_position
		var dist = global_position.distance_to(other_pos)
		if dist < MIN_SPACING and dist > 0.01:
			var away = (global_position - other_pos).normalized()
			separation += away * (MIN_SPACING - dist)
	if separation.length_squared() > 0.0:
		global_position += separation * STRENGTH

func _get_visible_sprite() -> Sprite2D:
	if walk_sprite and walk_sprite.visible:
		return walk_sprite
	if sit_sprite and sit_sprite.visible:
		return sit_sprite
	if sleep_sprite and sleep_sprite.visible:
		return sleep_sprite
	return idle_sprite if idle_sprite else walk_sprite


func get_foot_y_position() -> float:
	# Cariye/Worker ile aynı: sprite offset (0, -48), ayak = position.y - offset + height/2
	var sprite_height = 96.0
	var ref_sprite = _get_visible_sprite()
	if is_instance_valid(ref_sprite) and ref_sprite.texture:
		var tex = ref_sprite.texture
		if tex is Texture2D:
			sprite_height = tex.get_height()
	return global_position.y - SPRITE_OFFSET_Y + (sprite_height / 2.0)


func _calculate_z_index_from_foot_y(foot_y: float) -> int:
	# Cariye/Worker ile aynı aralık: 6..19
	const CAMPFIRE_Z_INDEX: int = 5
	const WATER_Z_INDEX: int = 20
	const MIN_Z_INDEX: int = CAMPFIRE_Z_INDEX + 1
	const MAX_Z_INDEX: int = WATER_Z_INDEX - 1
	var sprite_height = 96.0
	var ref_sprite = _get_visible_sprite()
	if is_instance_valid(ref_sprite) and ref_sprite.texture:
		var tex = ref_sprite.texture
		if tex is Texture2D:
			sprite_height = tex.get_height()
	var max_foot_y = VERTICAL_RANGE_MAX - SPRITE_OFFSET_Y + (sprite_height / 2.0)
	var min_foot_y = 0.0 - SPRITE_OFFSET_Y + (sprite_height / 2.0)
	var range_foot_y = max_foot_y - min_foot_y
	if range_foot_y <= 0.0:
		return (MIN_Z_INDEX + MAX_Z_INDEX) / 2
	var normalized = clamp((foot_y - min_foot_y) / range_foot_y, 0.0, 1.0)
	return MIN_Z_INDEX + int(normalized * (MAX_Z_INDEX - MIN_Z_INDEX))
