extends Node2D
## Tepegöz — boss odasına göre konumlanır: duvarlarda iki el, arkada kafa, göz vulnerable.

const ROCK_SCRIPT := preload("res://boss/tepegoz_falling_rock.gd")
const DAMAGE_NUMBER_SCENE := preload("res://effects/damage_number.tscn")
const DEV_ROOM_SCENE := "res://scenes/boss_rooms/tepegoz_boss_room.tscn"

signal enemy_defeated
signal health_changed(new_health: float, max_health: float)
signal vulnerability_changed(is_vulnerable: bool)

enum BossState { INTRO, ACTIVE, VULNERABLE, DEFEATED }
enum Hand { LEFT, RIGHT }

@export var max_health: float = 260.0
@export var display_name: String = "Tepegöz"
@export var slam_damage: float = 20.0
@export var rock_damage: float = 14.0
@export var rocks_per_slam: int = 9
@export var slams_before_vulnerable: int = 3
@export var vulnerable_duration: float = 4.0
@export var slam_telegraph: float = 0.65
@export var slam_recovery: float = 0.4

@onready var hurtbox: Area2D = $Hurtbox

var health: float = 260.0
var state: BossState = BossState.INTRO
var is_vulnerable: bool = false

var _bounds: Rect2 = Rect2(96.0, 128.0, 1728.0, 820.0)
var _floor_y: float = 920.0
var _ceiling_y: float = 164.0
var _hand_left_x: float = 236.0
var _hand_right_x: float = 1684.0
var _hand_y: float = 852.0

var _hazard_container: Node = null
var _fight_started: bool = false
var _combat_task: int = 0
var _slam_count: int = 0
var _next_hand: Hand = Hand.RIGHT

var _visual: Node2D
var _eye: Polygon2D
var _hand_l: Node2D
var _hand_r: Node2D
var _floor_marker: Polygon2D
var _slam_hitbox: EnemyHitbox


func _ready() -> void:
	if not Engine.is_editor_hint() and get_tree().current_scene == self:
		call_deferred("_go_to_boss_room")
		return
	add_to_group("boss")
	add_to_group("enemies")
	health = max_health
	_setup_hurtbox()
	_build_visuals()
	health_changed.emit(health, max_health)


func _go_to_boss_room() -> void:
	get_tree().change_scene_to_file(DEV_ROOM_SCENE)


func set_hazard_container(container: Node) -> void:
	_hazard_container = container


## Eski API — yalnızca bounds gelirse varsayılan oda değerleri kullanılır.
func setup_arena(bounds: Rect2) -> void:
	setup_boss_room({"bounds": bounds})


## Boss odası controller'dan gelen gerçek oda verisi.
func setup_boss_room(layout: Dictionary) -> void:
	_bounds = layout.get("bounds", _bounds)
	_floor_y = float(layout.get("floor_y", _floor_y))
	_ceiling_y = float(layout.get("ceiling_y", _bounds.position.y + 36.0))
	_hand_left_x = float(layout.get("hand_left_x", _bounds.position.x + 140.0))
	_hand_right_x = float(layout.get("hand_right_x", _bounds.position.x + _bounds.size.x - 140.0))
	_hand_y = float(layout.get("hand_y", _floor_y - 68.0))
	if layout.has("boss_anchor"):
		global_position = layout["boss_anchor"]
	_place_hands()
	_hide_floor_marker()


func start_fight() -> void:
	if _fight_started or state == BossState.DEFEATED:
		return
	if not is_inside_tree():
		call_deferred("start_fight")
		return
	_fight_started = true
	state = BossState.ACTIVE
	_combat_task += 1
	_run_combat(_combat_task)


func _combat_alive(task_id: int) -> bool:
	return is_instance_valid(self) and is_inside_tree() and task_id == _combat_task and state != BossState.DEFEATED


func _wait_frame() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame


func _wait_seconds(seconds: float) -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(seconds).timeout


func _run_combat(task_id: int) -> void:
	while _combat_alive(task_id):
		if state != BossState.ACTIVE:
			await _wait_frame()
			continue
		await _do_slam(_next_hand)
		if not _combat_alive(task_id):
			break
		_next_hand = Hand.LEFT if _next_hand == Hand.RIGHT else Hand.RIGHT
		_slam_count += 1
		if _slam_count >= slams_before_vulnerable:
			_slam_count = 0
			await _enter_vulnerable(vulnerable_duration)
		await _wait_seconds(0.35)


func _do_slam(hand_side: Hand) -> void:
	var hand := _hand_r if hand_side == Hand.RIGHT else _hand_l
	if not is_instance_valid(hand):
		return

	var slam_x := _hand_right_x if hand_side == Hand.RIGHT else _hand_left_x
	var rest := Vector2(slam_x, _hand_y)
	var raised := Vector2(slam_x, _hand_y - 180.0)
	var impact := Vector2(slam_x, _floor_y - 28.0)

	_show_slam_zone(hand_side)
	var windup := create_tween()
	windup.tween_property(hand, "global_position", raised, slam_telegraph * 0.5)
	windup.tween_property(hand, "global_position", impact, 0.11)
	await windup.finished

	_screen_shake(0.22, 9.0)
	_pulse_slam_hitbox(hand_side)
	_spawn_room_rock_rain()
	await _wait_seconds(0.14)
	_hide_slam_hitbox()
	_hide_floor_marker()

	var back := create_tween()
	back.tween_property(hand, "global_position", rest, slam_recovery)
	await back.finished


func _spawn_room_rock_rain() -> void:
	var container := _hazard_container if is_instance_valid(_hazard_container) else null
	if container == null and is_inside_tree():
		container = get_tree().current_scene
	if container == null:
		return

	var x_pad := 72.0
	var x_min := _bounds.position.x + x_pad
	var x_max := _bounds.position.x + _bounds.size.x - x_pad
	var land_y := _floor_y - 10.0
	var count := rocks_per_slam

	for i in range(count):
		var slot := float(i) / float(maxi(count - 1, 1))
		var x := lerpf(x_min, x_max, slot) + randf_range(-48.0, 48.0)
		x = clampf(x, x_min, x_max)
		var delay := randf_range(0.0, 1.0)
		var warn := randf_range(0.32, 0.52)
		var top := _ceiling_y + randf_range(-24.0, 48.0)
		ROCK_SCRIPT.drop(container, x, land_y, top, rock_damage, delay, warn)


func _show_slam_zone(hand_side: Hand) -> void:
	if not is_instance_valid(_floor_marker):
		return
	var half_w := _bounds.size.x * 0.46
	var h := 22.0
	var cx := _bounds.position.x + _bounds.size.x * 0.73 if hand_side == Hand.RIGHT else _bounds.position.x + _bounds.size.x * 0.27
	_floor_marker.polygon = PackedVector2Array([
		Vector2(-half_w * 0.5, -h * 0.5),
		Vector2(half_w * 0.5, -h * 0.5),
		Vector2(half_w * 0.5, h * 0.5),
		Vector2(-half_w * 0.5, h * 0.5),
	])
	_floor_marker.global_position = Vector2(cx, _floor_y - 14.0)
	_floor_marker.visible = true
	_floor_marker.modulate = Color(1.0, 0.35, 0.12, 0.55)


func _hide_floor_marker() -> void:
	if is_instance_valid(_floor_marker):
		_floor_marker.visible = false


func _pulse_slam_hitbox(hand_side: Hand) -> void:
	if not is_instance_valid(_slam_hitbox):
		return
	var half_w := _bounds.size.x * 0.46
	var h := 90.0
	var cx := _bounds.position.x + _bounds.size.x * 0.73 if hand_side == Hand.RIGHT else _bounds.position.x + _bounds.size.x * 0.27
	var shape := _slam_hitbox.get_node("CollisionShape2D").shape as RectangleShape2D
	if shape:
		shape.size = Vector2(half_w, h)
	_slam_hitbox.global_position = Vector2(cx, _floor_y - h * 0.45)
	_slam_hitbox.enable()


func _hide_slam_hitbox() -> void:
	if is_instance_valid(_slam_hitbox):
		_slam_hitbox.disable()


func _enter_vulnerable(duration: float) -> void:
	state = BossState.VULNERABLE
	is_vulnerable = true
	_set_hurtbox(true)
	if is_instance_valid(_eye):
		_eye.color = Color(1.0, 0.95, 0.35)
	vulnerability_changed.emit(true)
	await _wait_seconds(duration)
	if state != BossState.VULNERABLE:
		return
	_exit_vulnerable()


func _exit_vulnerable() -> void:
	state = BossState.ACTIVE
	is_vulnerable = false
	_set_hurtbox(false)
	if is_instance_valid(_eye):
		_eye.color = Color(0.95, 0.75, 0.15)
	vulnerability_changed.emit(false)


func take_damage(amount: float, _kb_f: float = 0.0, _kb_u: float = -1.0, _apply_kb: bool = false) -> void:
	if state != BossState.VULNERABLE:
		return
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	if is_instance_valid(_eye):
		_eye.modulate = Color(1.0, 0.4, 0.4)
		create_tween().tween_property(_eye, "modulate", Color.WHITE, 0.1)
	var num := DAMAGE_NUMBER_SCENE.instantiate()
	var scene_root := get_tree().current_scene if is_inside_tree() else null
	if scene_root:
		scene_root.add_child(num)
		num.global_position = global_position + Vector2(0, 20.0)
		num.setup(int(amount))
	if health <= 0.0:
		_die()


func _on_hurtbox_hurt(hitbox: Area2D) -> void:
	if not is_vulnerable:
		return
	if not hitbox.has_method("get_damage"):
		return
	var dmg: float = hitbox.get_damage_for_target(self) if hitbox.has_method("get_damage_for_target") else hitbox.get_damage()
	var kb: Dictionary = hitbox.get_knockback_data() if hitbox.has_method("get_knockback_data") else {"force": 0.0, "up_force": 0.0}
	take_damage(dmg, kb.get("force", 0.0), kb.get("up_force", -1.0), false)


func _die() -> void:
	state = BossState.DEFEATED
	_combat_task += 1
	is_vulnerable = false
	_set_hurtbox(false)
	_hide_floor_marker()
	_hide_slam_hitbox()
	if is_instance_valid(_visual):
		_visual.modulate = Color(0.45, 0.45, 0.45, 0.75)
	enemy_defeated.emit()


func _setup_hurtbox() -> void:
	if not is_instance_valid(hurtbox):
		return
	if hurtbox.has_signal("hurt") and not hurtbox.hurt.is_connected(_on_hurtbox_hurt):
		hurtbox.hurt.connect(_on_hurtbox_hurt)
	_set_hurtbox(false)


func _set_hurtbox(on: bool) -> void:
	if not is_instance_valid(hurtbox):
		return
	hurtbox.monitoring = on
	hurtbox.monitorable = on
	if hurtbox.has_node("CollisionShape2D"):
		hurtbox.get_node("CollisionShape2D").disabled = not on


func _build_visuals() -> void:
	_visual = $Visual as Node2D
	for c in _visual.get_children():
		c.queue_free()

	var face := Polygon2D.new()
	face.color = Color(0.52, 0.40, 0.30, 1.0)
	face.polygon = PackedVector2Array([
		Vector2(-120, 30), Vector2(-100, -80), Vector2(0, -110),
		Vector2(100, -80), Vector2(120, 30), Vector2(80, 90),
		Vector2(0, 105), Vector2(-80, 90),
	])
	_visual.add_child(face)

	_eye = Polygon2D.new()
	_eye.color = Color(0.95, 0.75, 0.15)
	_eye.polygon = _circle(30.0, 14)
	_eye.position = Vector2(0, 24)
	_visual.add_child(_eye)

	var pupil := Polygon2D.new()
	pupil.color = Color(0.12, 0.05, 0.02)
	pupil.polygon = _circle(12.0, 10)
	pupil.position = Vector2(0, 24)
	_visual.add_child(pupil)

	_hand_l = _make_hand("HandLeft")
	_hand_r = _make_hand("HandRight")
	add_child(_hand_l)
	add_child(_hand_r)
	_hand_l.top_level = true
	_hand_r.top_level = true
	_hand_l.z_index = 10
	_hand_r.z_index = 10

	_floor_marker = Polygon2D.new()
	_floor_marker.visible = false
	_floor_marker.z_index = 2
	_floor_marker.top_level = true
	add_child(_floor_marker)

	_slam_hitbox = EnemyHitbox.new()
	_slam_hitbox.name = "SlamHitbox"
	_slam_hitbox.top_level = true
	_slam_hitbox.damage = slam_damage
	_slam_hitbox.knockback_force = 360.0
	_slam_hitbox.knockback_up_force = -130.0
	var slam_shape := CollisionShape2D.new()
	slam_shape.name = "CollisionShape2D"
	slam_shape.shape = RectangleShape2D.new()
	_slam_hitbox.add_child(slam_shape)
	add_child(_slam_hitbox)
	_slam_hitbox.setup_attack("tepegoz_slam", false, 0.0)
	_slam_hitbox.disable()

	_place_hands()


func _make_hand(hname: String) -> Node2D:
	var hand := Node2D.new()
	hand.name = hname
	var palm := Polygon2D.new()
	palm.color = Color(0.46, 0.34, 0.26)
	palm.polygon = PackedVector2Array([
		Vector2(-58, -32), Vector2(58, -32), Vector2(72, 28),
		Vector2(34, 78), Vector2(-34, 78), Vector2(-72, 28),
	])
	hand.add_child(palm)
	return hand


func _place_hands() -> void:
	if is_instance_valid(_hand_l):
		_hand_l.global_position = Vector2(_hand_left_x, _hand_y)
	if is_instance_valid(_hand_r):
		_hand_r.global_position = Vector2(_hand_right_x, _hand_y)


func _screen_shake(duration: float, strength: float) -> void:
	var sfx := get_node_or_null("/root/ScreenEffects")
	if sfx and sfx.has_method("shake"):
		sfx.shake(duration, strength)


func _circle(r: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n):
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts
