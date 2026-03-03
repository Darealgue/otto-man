extends Area2D
class_name PoisonPoolV2

## Poison pool that remains on the ground where a drop lands.
## Plays an impact animation once, then loops idle.
## Poisons the player when they step on it.

@export var poison_ticks: int = 3
@export var poison_damage_per_tick: float = 2.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("poison_pools")
	body_entered.connect(_on_body_entered)
	_trigger_impact_animation()

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
	if not body.is_in_group("player"):
		return
	# Respect dodge / invincibility like other traps
	if body.is_dodging or (body.invincibility_timer > 0.0):
		return
	var sem: StatusEffectManager = body.get("status_effects") as StatusEffectManager
	if sem:
		sem.apply_poison(poison_ticks, poison_damage_per_tick)
