extends Node2D

signal enemy_defeated
signal health_changed(new_health: float, max_health: float)
signal vulnerability_changed(is_vulnerable: bool)

enum BossState { INTRO, ACTIVE, VULNERABLE, DEFEATED }

@export var max_health: float = 200.0
@export var display_name: String = "Boss"

var health: float = 200.0
var state: BossState = BossState.INTRO
var is_vulnerable: bool = false
var arena_bounds: Rect2 = Rect2(80.0, 120.0, 1760.0, 880.0)

@onready var hurtbox: Area2D = $Hurtbox
var visual_root: Node2D = null

var _base_color: Color = Color(0.85, 0.25, 0.35, 1.0)
var _vulnerable_color: Color = Color(1.0, 0.92, 0.35, 1.0)


func _ready() -> void:
	if has_node("Visual"):
		visual_root = $Visual as Node2D
	add_to_group("boss")
	add_to_group("enemies")
	health = max_health
	_setup_hurtbox()
	_on_boss_ready()
	_health_emit_changed()


func _setup_hurtbox() -> void:
	if not is_instance_valid(hurtbox):
		return
	if hurtbox.has_signal("hurt") and not hurtbox.hurt.is_connected(_on_hurtbox_hurt):
		hurtbox.hurt.connect(_on_hurtbox_hurt)
	_set_hurtbox_active(false)


func setup_arena(bounds: Rect2) -> void:
	arena_bounds = bounds


func _on_boss_ready() -> void:
	pass


func _process_active(_delta: float) -> void:
	pass


func _process(_delta: float) -> void:
	if state == BossState.DEFEATED:
		return
	if state == BossState.ACTIVE:
		_process_active(_delta)
	elif state == BossState.VULNERABLE:
		_process_vulnerable(_delta)


func _process_vulnerable(_delta: float) -> void:
	pass


func begin_intro() -> void:
	state = BossState.INTRO
	_on_intro_started()


func finish_intro() -> void:
	if state == BossState.DEFEATED:
		return
	state = BossState.ACTIVE
	_on_active_started()


func enter_vulnerability(duration: float) -> void:
	if state == BossState.DEFEATED:
		return
	state = BossState.VULNERABLE
	is_vulnerable = true
	_set_hurtbox_active(true)
	_apply_vulnerable_visual(true)
	vulnerability_changed.emit(true)
	_on_vulnerability_started(duration)
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
	_on_vulnerability_ended()


func take_damage(amount: float, _knockback_force: float = 0.0, _knockback_up_force: float = -1.0, apply_knockback: bool = false) -> void:
	if state == BossState.DEFEATED:
		return
	if not is_vulnerable:
		return

	health = maxf(0.0, health - amount)
	_health_emit_changed()
	_flash_damage()

	var damage_number := preload("res://effects/damage_number.tscn").instantiate()
	get_tree().current_scene.add_child(damage_number)
	damage_number.global_position = global_position + Vector2(0, -70)
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

	var knockback_data := hitbox.get_knockback_data() if hitbox.has_method("get_knockback_data") else {"force": 0.0, "up_force": 0.0}
	take_damage(damage, knockback_data.get("force", 0.0), knockback_data.get("up_force", -1.0), false)

	if hitbox.has_method("apply_killing_blow_effects"):
		hitbox.apply_killing_blow_effects(damage)


func _die() -> void:
	state = BossState.DEFEATED
	is_vulnerable = false
	_set_hurtbox_active(false)
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


func _on_intro_started() -> void:
	pass


func _on_active_started() -> void:
	pass


func _on_vulnerability_started(_duration: float) -> void:
	pass


func _on_vulnerability_ended() -> void:
	pass


func _on_defeated() -> void:
	pass
