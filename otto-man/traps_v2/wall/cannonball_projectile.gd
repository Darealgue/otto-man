extends Area2D
class_name CannonballProjectileV2

## Cannonball projectile fired by CannonTrapV2.
## Moves straight, explodes on player hit or wall hit (AoE damage).
## Uses AnimatedSprite2D: "default" while flying, "break" on impact then freed.

var velocity: Vector2 = Vector2.ZERO
var damage: float = 20.0
var explosion_radius: float = 48.0
var _hit: bool = false

## Strong knockback when player is in explosion (wall or direct hit).
const KNOCKBACK_FORCE: float = 700.0
const KNOCKBACK_UP_FORCE: float = 420.0

@onready var anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("trap_projectile")
	if velocity.length_squared() > 0:
		rotation = velocity.angle()
	if anim and anim.sprite_frames:
		if anim.sprite_frames.has_animation("default"):
			anim.play("default")
		else:
			anim.play()

func _physics_process(delta: float) -> void:
	if _hit:
		return
	position += velocity * delta
	# Tuzak Fısıldayan: yoluna çıkan ilk düşmana da çarpar (collision mask düşmanları görmüyor,
	# bu yüzden manuel mesafe taraması kullanılıyor — bkz. trap_enemy_damage.gd)
	if TrapEnemyDamage.is_active():
		var tree := get_tree()
		if tree:
			for node in tree.get_nodes_in_group("enemies"):
				if not is_instance_valid(node) or node.get("current_behavior") == "dead":
					continue
				if global_position.distance_to(node.global_position) <= explosion_radius * 0.5:
					_hit = true
					velocity = Vector2.ZERO
					_play_break_and_explode()
					return

func _on_body_entered(body: Node2D) -> void:
	if _hit:
		return
	if body.is_in_group("enemy"):
		return
	_hit = true
	velocity = Vector2.ZERO
	_play_break_and_explode()

func _play_break_and_explode() -> void:
	_hit = true
	velocity = Vector2.ZERO
	_apply_explosion_damage()
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("break"):
		if not anim.animation_finished.is_connected(_on_break_finished):
			anim.animation_finished.connect(_on_break_finished)
		anim.play("break")
	else:
		queue_free()

func _on_break_finished() -> void:
	queue_free()

func _apply_explosion_damage() -> void:
	if TrapEnemyDamage.is_active():
		TrapEnemyDamage.damage_enemies_in_radius(get_tree(), global_position, explosion_radius, damage)
	var space := get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = explosion_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, global_position)
	query.collision_mask = CollisionLayers.PLAYER
	query.collide_with_bodies = true
	var results := space.intersect_shape(query, 8)
	for r in results:
		var col := r.collider as Node2D
		if not col or not col.is_in_group("player") or not col.has_method("take_damage"):
			continue
		if col.get("is_dodging") or (col.get("invincibility_timer") != null and col.invincibility_timer > 0.0):
			continue
		# Set knockback so Hurt state applies strong push
		col.last_hit_position = global_position
		col.last_hit_knockback = { "force": KNOCKBACK_FORCE, "up_force": KNOCKBACK_UP_FORCE }
		col.take_damage(damage)
		# Transition to Hurt state for knockback + invincibility
		if col.get("state_machine") and col.state_machine.has_node("Hurt"):
			# transition_to kullan — doğrudan atama eski state'in exit()'ini atlayıp
			# crouch/slide collision shape'inin geri büyümemesine yol açıyordu.
			col.state_machine.transition_to("Hurt", true)
