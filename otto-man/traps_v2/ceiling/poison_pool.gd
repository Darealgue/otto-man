extends Area2D
class_name PoisonPoolV2

## Poison pool that remains on the ground where a drop lands.
## Plays an impact animation once, then loops idle.
## Poisons the player when they step on it.

@export var poison_ticks: int = 3
@export var poison_damage_per_tick: float = 2.0

const SLEEP_DISTANCE := 1600.0
const WAKE_DISTANCE := 1400.0
const SLEEP_CHECK_INTERVAL := 0.15

var is_sleeping: bool = true
var _sleep_poll_timer: Timer = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

const ENEMY_TICK_INTERVAL := 1.0
const ENEMY_RADIUS := 24.0
var _enemy_tick_timer: float = 0.0

func _process(delta: float) -> void:
	if is_sleeping:
		return
	# Tuzak Fısıldayan: havuzda duran düşmanlar da zehirlenir
	if not TrapEnemyDamage.is_active():
		return
	_enemy_tick_timer -= delta
	if _enemy_tick_timer > 0.0:
		return
	_enemy_tick_timer = ENEMY_TICK_INTERVAL
	TrapEnemyDamage.damage_enemies_in_radius(get_tree(), global_position, ENEMY_RADIUS, 0.0, "poison")

func _ready() -> void:
	add_to_group("poison_pools")
	body_entered.connect(_on_body_entered)
	_trigger_impact_animation()
	_sleep_poll_timer = Timer.new()
	_sleep_poll_timer.wait_time = SLEEP_CHECK_INTERVAL
	_sleep_poll_timer.timeout.connect(_check_sleep_state)
	add_child(_sleep_poll_timer)
	_sleep_poll_timer.start()
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
	monitoring = false
	monitorable = false
	if sprite:
		sprite.visible = false

func _wake_up() -> void:
	if not is_sleeping:
		return
	is_sleeping = false
	monitoring = true
	monitorable = true
	if sprite:
		sprite.visible = true

func _trigger_impact_animation() -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("impact"):
		if not sprite.animation_finished.is_connected(_on_animation_finished):
			sprite.animation_finished.connect(_on_animation_finished)
		sprite.play("impact")
	elif sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")

func trigger_impact() -> void:
	# Public method so drops can retrigger the impact on an existing pool
	_trigger_impact_animation()

func _on_animation_finished() -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")
		# Disconnect to avoid repeated calls
		sprite.animation_finished.disconnect(_on_animation_finished)

func _on_body_entered(body: Node2D) -> void:
	if is_sleeping:
		return
	if not body.is_in_group("player"):
		return
	# Respect dodge / invincibility like other traps
	if body.is_dodging or (body.invincibility_timer > 0.0):
		return
	var sem: StatusEffectManager = body.get("status_effects") as StatusEffectManager
	if sem:
		sem.apply_poison(poison_ticks, poison_damage_per_tick)
