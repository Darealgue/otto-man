extends Area2D

const KNOCKBACK_FORCE = 300

var direction: int = 1
var speed: float = 500
var max_distance: float = 600
var damage_amount: int = 25
var distance_traveled: float = 0
var start_position: Vector2
var initial_scale: Vector2

@onready var animated_sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D

func _ready() -> void:
	# Set up monitoring
	monitoring = true
	monitorable = true
	
	if collision_shape:
		collision_shape.disabled = false
	
	# Debug output
	print("Shockwave collision setup:")
	print("- Layer: ", collision_layer)
	print("- Mask: ", collision_mask)
	print("- Monitoring: ", monitoring)
	print("- Monitorable: ", monitorable)
	if collision_shape:
		print("- Shape enabled: ", !collision_shape.disabled)
	
	area_entered.connect(_on_area_entered)
	initial_scale = scale
	
	if animated_sprite:
		animated_sprite.play("default")
		if direction < 0:
			animated_sprite.flip_h = true

func _physics_process(delta: float) -> void:
	position.x += direction * speed * delta
	
	distance_traveled = abs(global_position.x - start_position.x)
	
	var scale_factor = 1.0 - (distance_traveled / max_distance)
	scale.y = initial_scale.y * scale_factor
	
	if distance_traveled >= max_distance:
		queue_free()

func initialize(dir: int, spd: float, dist: float, dmg: int) -> void:
	direction = dir
	speed = spd
	max_distance = dist
	damage_amount = dmg
	start_position = global_position
	
	if animated_sprite and direction < 0:
		animated_sprite.flip_h = true

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("hurtbox") and area.get_parent().is_in_group("player"):
		var damage = damage_amount
		var player = area.get_parent()
		# Apply damage
		player.take_damage(damage)
		# Apply knockback separately
		if player is CharacterBody2D:
			var knockback_dir = Vector2(direction, -0.5).normalized()
			player.velocity = knockback_dir * KNOCKBACK_FORCE

func get_damage() -> int:
	return damage_amount

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("hurtbox"):
		var damage = damage_amount
		var knockback_dir = (area.global_position - global_position).normalized()
		
		if area.get_parent().has_method("take_damage"):
			area.get_parent().take_damage(damage)
			
		# Apply knockback separately if needed
		if area.get_parent() is CharacterBody2D:
			area.get_parent().velocity = knockback_dir * KNOCKBACK_FORCE
