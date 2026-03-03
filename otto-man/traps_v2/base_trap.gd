extends Node2D
class_name BaseTrapV2

## Minimal base class for all tile-based traps.
## Each trap is 1 tile (32x32) and placed via TileTrapSpawner.
## Includes sleep/freeze system: traps pause when player is far away.

const TILE_SIZE := 32
const SLEEP_DISTANCE := 1600.0
const WAKE_DISTANCE := 1400.0
const SLEEP_CHECK_INTERVAL := 0.15

@export var base_damage: float = 10.0
@export var damage_scale_per_level: float = 0.25

var current_level: int = 1
var surface_type: TrapConfigV2.SurfaceType = TrapConfigV2.SurfaceType.FLOOR
var _damage: float = 10.0
var _placeholder: ColorRect = null
var is_sleeping: bool = true  # Start asleep, wake when player is close
var _sleep_check_timer: float = 0.0
var _initialized: bool = false

signal player_damaged(player: Node2D, damage: float)

func initialize(level: int, surface: TrapConfigV2.SurfaceType) -> void:
	current_level = level
	surface_type = surface
	_damage = base_damage * (1.0 + damage_scale_per_level * (level - 1))
	z_index = 4
	visible = false
	_initialized = true
	_on_initialized()
	_check_sleep_state()

## Override in subclass for trap-specific setup after initialize.
func _on_initialized() -> void:
	pass

func _physics_process(delta: float) -> void:
	if not _initialized:
		return
	_sleep_check_timer -= delta
	if _sleep_check_timer <= 0.0:
		_sleep_check_timer = SLEEP_CHECK_INTERVAL
		_check_sleep_state()

func _check_sleep_state() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		if not is_sleeping:
			_go_to_sleep()
		return
	var dist := global_position.distance_to(player.global_position)
	if is_sleeping and dist <= WAKE_DISTANCE:
		_wake_up()
	elif not is_sleeping and dist >= SLEEP_DISTANCE:
		_go_to_sleep()

func _go_to_sleep() -> void:
	if is_sleeping:
		return
	is_sleeping = true
	_on_sleep()

func _wake_up() -> void:
	if not is_sleeping:
		return
	is_sleeping = false
	_on_wake()

## Override in subclass to pause timers, animations etc.
func _on_sleep() -> void:
	visible = false
	set_process(false)

## Override in subclass to resume timers, animations etc.
func _on_wake() -> void:
	visible = true
	set_process(true)

func get_damage() -> float:
	return _damage

func deal_damage(player: Node2D) -> void:
	if not player or not player.has_method("take_damage"):
		return
	if player.get("is_dodging"):
		return
	if player.get("invincibility_timer") != null and player.invincibility_timer > 0:
		return
	player.take_damage(_damage)
	player_damaged.emit(player, _damage)

## Same as deal_damage but sets knockback and transitions player to Hurt state (like enemy hits).
func apply_damage_with_knockback(player: Node2D, knockback_force: float, knockback_up_force: float) -> void:
	if not player or not player.is_in_group("player"):
		return
	player.last_hit_position = global_position
	player.last_hit_knockback = { "force": knockback_force, "up_force": knockback_up_force }
	deal_damage(player)
	if player.get("state_machine") and player.state_machine.has_node("Hurt"):
		player.state_machine.current_state = player.state_machine.get_node("Hurt")
		player.state_machine.current_state.enter()

func get_status_effect_manager(player: Node2D) -> StatusEffectManager:
	if not player:
		return null
	return player.get("status_effects") as StatusEffectManager

func _create_placeholder(color: Color, label_text: String = "") -> void:
	_placeholder = ColorRect.new()
	_placeholder.color = color
	_placeholder.size = Vector2(TILE_SIZE, TILE_SIZE)
	_placeholder.position = Vector2(-TILE_SIZE / 2.0, -TILE_SIZE / 2.0)
	add_child(_placeholder)
	if label_text != "":
		var lbl := Label.new()
		lbl.text = label_text
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.size = Vector2(TILE_SIZE, TILE_SIZE)
		lbl.position = Vector2.ZERO
		lbl.add_theme_font_size_override("font_size", 8)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		_placeholder.add_child(lbl)

func _set_placeholder_active(active: bool) -> void:
	if _placeholder:
		_placeholder.modulate.a = 1.0 if active else 0.4
