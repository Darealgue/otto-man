extends Area2D
class_name ArrowProjectileV2

## Arrow projectile fired by ArrowShooterV2.
## Moves in a straight line, destroyed on player or wall hit.

var velocity: Vector2 = Vector2.ZERO
var damage: float = 12.0
var max_distance: float = 600.0 # kept for compatibility, not strictly used
var _traveled: float = 0.0
var _hit: bool = false

const KNOCKBACK_FORCE: float = 420.0
const KNOCKBACK_UP_FORCE: float = 280.0

@onready var anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Point arrow sprite in flight direction (add PI if your arrow art points the other way)
	if velocity.length_squared() > 0:
		rotation = velocity.angle() + PI
	
	if anim and anim.sprite_frames:
		if anim.sprite_frames.has_animation("default"):
			anim.play("default")
		else:
			anim.play()
	elif not sprite or not sprite.texture:
		_create_arrow_placeholder()

func _create_arrow_placeholder() -> void:
	var rect := ColorRect.new()
	rect.color = Color(0.3, 0.6, 1.0)
	rect.size = Vector2(16, 4)
	rect.position = Vector2(-8, -2)
	add_child(rect)

func _physics_process(delta: float) -> void:
	if _hit:
		return
	var step := velocity * delta
	position += step
	_traveled += step.length()
	# No explicit max-distance kill; arrow flies until it hits something

func _play_break_and_free() -> void:
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("break"):
		if not anim.animation_finished.is_connected(_on_animation_finished):
			anim.animation_finished.connect(_on_animation_finished)
		anim.play("break")
	else:
		queue_free()

func _on_animation_finished() -> void:
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if _hit:
		return
	# Ignore other enemies
	if body.is_in_group("enemy"):
		return
	_hit = true
	velocity = Vector2.ZERO
	if body.is_in_group("player"):
		if not body.is_dodging and (not (body.invincibility_timer > 0.0)):
			body.last_hit_position = global_position
			body.last_hit_knockback = { "force": KNOCKBACK_FORCE, "up_force": KNOCKBACK_UP_FORCE }
			if body.has_method("take_damage"):
				body.take_damage(damage)
			if body.get("state_machine") and body.state_machine.has_node("Hurt"):
				body.state_machine.current_state = body.state_machine.get_node("Hurt")
				body.state_machine.current_state.enter()
		_play_break_and_free()
	else:
		# Hit wall or other environment
		_play_break_and_free()
