extends Node
class_name StatusEffectManager

## Manages status effects (burn, poison) on the player.
## Add as a child of the Player node.

var _player: CharacterBody2D
var _burn_timer: Timer
var _poison_timer: Timer

# Burn state
var burn_active: bool = false
var burn_remaining_ticks: int = 0
var burn_damage_per_tick: float = 3.0
const BURN_TICK_INTERVAL: float = 0.5
const BURN_TINT := Color(1.0, 0.4, 0.2, 1.0)

# Poison state
var poison_active: bool = false
var poison_remaining_ticks: int = 0
var poison_damage_per_tick: float = 2.0
const POISON_TICK_INTERVAL: float = 1.0
const POISON_TINT := Color(0.5, 1.0, 0.3, 1.0)

var _original_modulate: Color = Color.WHITE

func _ready() -> void:
	_player = get_parent() as CharacterBody2D
	if not _player:
		push_error("[StatusEffectManager] Must be a child of a CharacterBody2D (Player)")
		return

	var sprite = _player.get_node_or_null("AnimatedSprite2D")
	if sprite:
		_original_modulate = sprite.modulate

	_burn_timer = Timer.new()
	_burn_timer.wait_time = BURN_TICK_INTERVAL
	_burn_timer.timeout.connect(_on_burn_tick)
	add_child(_burn_timer)

	_poison_timer = Timer.new()
	_poison_timer.wait_time = POISON_TICK_INTERVAL
	_poison_timer.timeout.connect(_on_poison_tick)
	add_child(_poison_timer)

func apply_burn(ticks: int = 6, damage_per_tick: float = 3.0) -> void:
	burn_damage_per_tick = damage_per_tick
	burn_remaining_ticks = maxi(burn_remaining_ticks, ticks)
	if not burn_active:
		burn_active = true
		_burn_timer.start()
	_update_visual()

func apply_poison(ticks: int = 5, damage_per_tick: float = 2.0) -> void:
	poison_damage_per_tick = damage_per_tick
	poison_remaining_ticks = maxi(poison_remaining_ticks, ticks)
	if not poison_active:
		poison_active = true
		_poison_timer.start()
	_update_visual()

func clear_all() -> void:
	_clear_burn()
	_clear_poison()

func _on_burn_tick() -> void:
	if burn_remaining_ticks <= 0:
		_clear_burn()
		return
	burn_remaining_ticks -= 1
	if _player and _player.has_method("take_damage"):
		_player.take_damage(burn_damage_per_tick, true, null)
	_flash_tint(BURN_TINT)

func _on_poison_tick() -> void:
	if poison_remaining_ticks <= 0:
		_clear_poison()
		return
	poison_remaining_ticks -= 1
	if _player and _player.has_method("take_damage"):
		_player.take_damage(poison_damage_per_tick, true, null)
	_flash_tint(POISON_TINT)

func _clear_burn() -> void:
	burn_active = false
	burn_remaining_ticks = 0
	_burn_timer.stop()
	_update_visual()

func _clear_poison() -> void:
	poison_active = false
	poison_remaining_ticks = 0
	_poison_timer.stop()
	_update_visual()

func _update_visual() -> void:
	var sprite = _player.get_node_or_null("AnimatedSprite2D") if _player else null
	if not sprite:
		return
	if burn_active:
		sprite.modulate = BURN_TINT
	elif poison_active:
		sprite.modulate = POISON_TINT
	else:
		sprite.modulate = _original_modulate

func _flash_tint(color: Color) -> void:
	var sprite = _player.get_node_or_null("AnimatedSprite2D") if _player else null
	if not sprite:
		return
	sprite.modulate = Color.WHITE
	var tw = create_tween()
	tw.tween_property(sprite, "modulate", color if (burn_active or poison_active) else _original_modulate, 0.15)

func is_burning() -> bool:
	return burn_active

func is_poisoned() -> bool:
	return poison_active
