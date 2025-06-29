extends Area2D
class_name ArrowProjectile

var velocity: Vector2 = Vector2.ZERO
var damage: float = 20.0
var max_distance: float = 500.0
var traveled_distance: float = 0.0
var start_position: Vector2
var has_hit_target: bool = false  # Prevent double damage

func _ready():
	start_position = global_position
	body_entered.connect(_on_body_entered)
	# area_entered.connect(_on_area_entered)  # Disabled to prevent double collision
	
	# Set collision layers for arrow
	collision_layer = 0  # Arrow doesn't need to be detected by others
	collision_mask = 2   # Detect player (layer 2)
	
	print("[Arrow] Arrow created with collision_mask: " + str(collision_mask))
	
func set_velocity(vel: Vector2):
	velocity = vel
	
func set_direction_and_speed(direction: Vector2, speed: float):
	velocity = direction * speed
	
func set_damage(dmg: float):
	damage = dmg
	
func set_range(range_val: float):
	max_distance = range_val

func _physics_process(delta):
	if velocity != Vector2.ZERO:
		var movement = velocity * delta
		global_position += movement
		traveled_distance += movement.length()
		
		# Remove arrow if it traveled too far
		if traveled_distance >= max_distance:
			queue_free()

func _on_body_entered(body):
	print("[Arrow] Body collision detected with: " + str(body.name))
	print("[Arrow] Body groups: " + str(body.get_groups()))
	_handle_collision(body)

func _on_area_entered(area):
	print("[Arrow] Area collision detected with: " + str(area.name))
	print("[Arrow] Area groups: " + str(area.get_groups()))
	
	# Check if area belongs to player
	var parent = area.get_parent()
	if parent:
		print("[Arrow] Area parent: " + str(parent.name))
		_handle_collision(parent)

func _handle_collision(node):
	# Prevent double damage
	if has_hit_target:
		print("[Arrow] Already hit target, ignoring collision")
		return
	
	if node.is_in_group("player"):
		print("[Arrow] Player detected!")
		if node.has_method("take_damage"):
			print("[Arrow] Player has take_damage method - dealing " + str(damage) + " damage")
			has_hit_target = true  # Mark as hit
			node.take_damage(damage)
		else:
			print("[Arrow] Player does NOT have take_damage method!")
		queue_free()
	elif node.is_in_group("enemy"):
		print("[Arrow] Enemy detected - ignoring")
		# Arrows don't hit enemies
		pass
	else:
		# Hit wall or obstacle
		print("[Arrow] Hit obstacle: " + str(node.name) + " - destroying arrow")
		has_hit_target = true  # Mark as hit
		queue_free() 
 
