extends Node2D

signal enemy_defeated
signal health_changed(new_health: float, max_health: float)
signal vulnerability_changed(is_vulnerable: bool)

enum BossState { INTRO, ACTIVE, VULNERABLE, DEFEATED }

const BOUNCE_PROJECTILE_SCRIPT := preload("res://boss/boss_bounce_projectile.gd")
const DAMAGE_NUMBER_SCENE := preload("res://effects/damage_number.tscn")
const ENEMY_HITBOX_SCRIPT := preload("res://components/enemy_hitbox.gd")
const SCATTER_ANGLE_OFFSET := PI / 8.0

@export var max_health: float = 500.0
@export var scatter_cycles_before_vulnerable: int = 3
@export var orbs_per_scatter: int = 8
@export var scatter_speed_min: float = 280.0
@export var scatter_speed_max: float = 380.0
@export var orb_max_bounces: int = 3
@export var move_speed: float = 420.0
@export var vulnerable_duration: float = 4.0
@export var scatter_telegraph_time: float = 0.55
@export var pause_after_scatter: float = 0.9
@export var charge_damage: float = 18.0
@export var charge_speed: float = 900.0
@export var charge_dash_count: int = 4
@export var charge_telegraph_time: float = 0.28
@export var charge_dash_time: float = 0.36
@export var pause_after_charge: float = 0.75

var health: float = 500.0
var state: BossState = BossState.INTRO
var is_vulnerable: bool = false
var arena_bounds: Rect2 = Rect2(80.0, 120.0, 1760.0, 880.0)

@onready var hurtbox: Area2D = $Hurtbox
var visual_root: Node2D = null

var _base_color: Color = Color(0.85, 0.25, 0.35, 1.0)
var _vulnerable_color: Color = Color(1.0, 0.92, 0.35, 1.0)
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
	_build_placeholder_visual()
	_build_charge_hitbox()
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
		return
	if state == BossState.ACTIVE:
		_process_active(delta)
	elif state == BossState.VULNERABLE:
		_process_vulnerable(delta)


func begin_intro() -> void:
	state = BossState.INTRO


func finish_intro() -> void:
	if state == BossState.DEFEATED:
		return
	state = BossState.ACTIVE


func enter_vulnerability(duration: float) -> void:
	if state == BossState.DEFEATED:
		return
	state = BossState.VULNERABLE
	is_vulnerable = true
	_set_hurtbox_active(true)
	_apply_vulnerable_visual(true)
	vulnerability_changed.emit(true)
	if is_instance_valid(visual_root):
		visual_root.rotation = 0.0
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(_on_vulnerability_timeout)


func _on_vulnerability_timeout() -> void:
	if state != BossState.VULNERABLE:
		return
	exit_vulnerability()


func exit_vulnerability() -> void:
	if state == BossState.DEFEATED:
		return
	is_vulnerable = false
	_set_hurtbox_active(false)
	_apply_vulnerable_visual(false)
	vulnerability_changed.emit(false)
	state = BossState.ACTIVE
	if is_instance_valid(visual_root):
		visual_root.scale = Vector2.ONE
	_begin_next_scatter_cycle()


func take_damage(amount: float, _knockback_force: float = 0.0, _knockback_up_force: float = -1.0, _apply_knockback: bool = false) -> void:
	if state == BossState.DEFEATED or not is_vulnerable:
		return

	health = maxf(0.0, health - amount)
	_health_emit_changed()
	_flash_damage()

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
		hitbox.apply_killing_blow_effects(damage)


func _die() -> void:
	state = BossState.DEFEATED
	is_vulnerable = false
	_set_hurtbox_active(false)
	_set_charge_hitbox_active(false)
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


func _apply_vulnerable_visual(vulnerable: bool) -> void:
	if not is_instance_valid(visual_root):
		return
	visual_root.modulate = _vulnerable_color if vulnerable else Color.WHITE


func _flash_damage() -> void:
	if not is_instance_valid(visual_root):
		return
	visual_root.modulate = Color(1.0, 0.4, 0.4)
	var tween := create_tween()
	tween.tween_property(visual_root, "modulate", _vulnerable_color if is_vulnerable else Color.WHITE, 0.12)


func _build_placeholder_visual() -> void:
	if is_instance_valid(visual_root):
		for child in visual_root.get_children():
			child.queue_free()
	else:
		visual_root = Node2D.new()
		visual_root.name = "Visual"
		add_child(visual_root)

	var ring := Polygon2D.new()
	ring.name = "Ring"
	ring.color = Color(0.55, 0.15, 0.55, 0.85)
	ring.polygon = _make_ring_points(72.0, 52.0, 24)
	visual_root.add_child(ring)

	var core := Polygon2D.new()
	core.name = "Core"
	core.color = _base_color
	core.polygon = _make_circle_points(38.0, 12)
	visual_root.add_child(core)

	var eye_l := Polygon2D.new()
	eye_l.color = Color(0.95, 0.95, 0.95, 1.0)
	eye_l.polygon = _make_circle_points(7.0, 8)
	eye_l.position = Vector2(-16.0, -8.0)
	visual_root.add_child(eye_l)

	var eye_r := Polygon2D.new()
	eye_r.color = Color(0.95, 0.95, 0.95, 1.0)
	eye_r.polygon = _make_circle_points(7.0, 8)
	eye_r.position = Vector2(16.0, -8.0)
	visual_root.add_child(eye_r)


func _build_charge_hitbox() -> void:
	_charge_hitbox = Area2D.new()
	_charge_hitbox.set_script(ENEMY_HITBOX_SCRIPT)
	_charge_hitbox.name = "ChargeHitbox"
	_charge_hitbox.damage = charge_damage
	_charge_hitbox.knockback_force = 300.0
	_charge_hitbox.knockback_up_force = 140.0
	add_child(_charge_hitbox)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(112.0, 96.0)
	shape.shape = rect
	_charge_hitbox.add_child(shape)
	_charge_hitbox.setup_attack("boss_charge", false, 0.0)
	_set_charge_hitbox_active(false)


func _set_charge_hitbox_active(active: bool) -> void:
	if not is_instance_valid(_charge_hitbox):
		return
	if active:
		_charge_hitbox.enable()
	else:
		_charge_hitbox.disable()


func _start_fight() -> void:
	begin_intro()
	global_position = _anchor_points[2]
	var intro_timer := get_tree().create_timer(1.0)
	intro_timer.timeout.connect(_on_intro_complete)


func _on_intro_complete() -> void:
	finish_intro()
	_begin_next_scatter_cycle()


func _process_active(delta: float) -> void:
	if _is_charging:
		return

	if _is_moving:
		global_position = global_position.move_toward(_move_target, move_speed * delta)
		if global_position.distance_to(_move_target) <= 8.0:
			global_position = _move_target
			_is_moving = false
			_on_arrived_at_anchor()

	if is_instance_valid(visual_root) and not is_vulnerable and not _attack_busy:
		visual_root.rotation += delta * 0.8


func _process_vulnerable(delta: float) -> void:
	if is_instance_valid(visual_root):
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.012) * 0.08
		visual_root.scale = Vector2(pulse, pulse)


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
	if is_instance_valid(visual_root):
		var tween := create_tween()
		tween.tween_property(visual_root, "scale", Vector2(1.25, 1.25), scatter_telegraph_time * 0.5)
		tween.tween_property(visual_root, "scale", Vector2.ONE, scatter_telegraph_time * 0.5)
	var telegraph_timer := get_tree().create_timer(scatter_telegraph_time)
	telegraph_timer.timeout.connect(_do_scatter)


func _do_scatter() -> void:
	if state != BossState.ACTIVE:
		_attack_busy = false
		return

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

	if is_instance_valid(visual_root):
		visual_root.modulate = Color(1.0, 0.45, 0.45)
		var tween := create_tween()
		tween.tween_property(visual_root, "scale", Vector2(1.35, 1.35), charge_telegraph_time * 0.5)
		tween.tween_property(visual_root, "scale", Vector2.ONE, charge_telegraph_time * 0.5)

	var telegraph_timer := get_tree().create_timer(charge_telegraph_time)
	telegraph_timer.timeout.connect(_do_charge_dash)


func _do_charge_dash() -> void:
	if state != BossState.ACTIVE:
		_end_charge_sequence()
		return

	_charge_direction = _pick_charge_direction()
	_set_charge_hitbox_active(true)

	if is_instance_valid(visual_root):
		visual_root.modulate = Color(1.0, 0.25, 0.25)
		if _charge_direction.x != 0.0:
			visual_root.scale = Vector2(1.45, 0.85)
		else:
			visual_root.scale = Vector2(0.85, 1.45)

	var dash_distance := charge_speed * charge_dash_time
	var target := global_position + _charge_direction * dash_distance
	target = _clamp_to_arena(target, 72.0)

	var tween := create_tween()
	tween.tween_property(self, "global_position", target, charge_dash_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(_on_charge_dash_finished)


func _on_charge_dash_finished() -> void:
	_set_charge_hitbox_active(false)
	_charge_dashes_remaining -= 1

	if is_instance_valid(visual_root):
		visual_root.scale = Vector2.ONE
		visual_root.modulate = Color.WHITE

	if _charge_dashes_remaining <= 0 or state != BossState.ACTIVE:
		_end_charge_sequence()
		return

	var pause_timer := get_tree().create_timer(0.12)
	pause_timer.timeout.connect(_do_charge_dash)


func _end_charge_sequence() -> void:
	_is_charging = false
	_set_charge_hitbox_active(false)
	if is_instance_valid(visual_root):
		visual_root.scale = Vector2.ONE
		visual_root.modulate = Color.WHITE

	var pause_timer := get_tree().create_timer(pause_after_charge)
	pause_timer.timeout.connect(_finish_attack)


func _pick_charge_direction() -> Vector2:
	var options: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	if _charge_direction != Vector2.ZERO:
		options.erase(-_charge_direction)
	return options[randi() % options.size()]


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
		var tween := create_tween()
		tween.tween_property(visual_root, "modulate:a", 0.0, 0.8)
		tween.parallel().tween_property(visual_root, "scale", Vector2(0.2, 0.2), 0.8)


func _clear_projectiles() -> void:
	for node in get_tree().get_nodes_in_group("boss_projectile"):
		if is_instance_valid(node):
			node.queue_free()


static func _make_circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


static func _make_ring_points(outer_radius: float, inner_radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments + 1):
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * outer_radius)
	for i in range(segments, -1, -1):
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * inner_radius)
	return points
