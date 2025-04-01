extends BaseHitbox
class_name PlayerHitbox

signal hit_enemy(enemy: Node)

# Player-specific properties
var combo_multiplier: float = 1.0
var is_combo_hit: bool = false
var current_attack_name: String = ""
var has_hit_enemy: bool = false  # Track if we've hit during this attack
var base_damage: float = 15.0  # Base damage value
var combo_enabled: bool = false  # Added missing property

@onready var attack_manager = get_node("/root/AttackManager")

func _ready():
	super._ready()
	collision_layer = 16  # Layer 5 (Player hitbox)
	collision_mask = 32   # Layer 6 (Enemy hurtbox)
	# Ensure hitbox starts inactive but visible for debugging
	monitoring = false
	monitorable = false
	is_active = false
	if has_node("CollisionShape2D"):
		var shape = get_node("CollisionShape2D")
		# Keep the shape visible but disabled for debugging
		shape.set_deferred("disabled", true)
		shape.debug_color = Color(1, 0, 0, 0.5)  # Red with 50% transparency
	print("[Player Hitbox] Initialized with base damage: ", base_damage)

func enable_combo(attack_name: String, damage_multiplier: float = 1.0) -> void:
	print("[Player Hitbox] DEBUG - enable_combo called with attack_name: ", attack_name, " and multiplier: ", damage_multiplier)
	current_attack_name = attack_name
	
	# Determine attack type based on name
	var attack_type = "light"  # Default attack type
	
	# Set damage based on attack type
	if attack_name == "fall_attack":
		damage = PlayerStats.get_fall_attack_damage() * damage_multiplier
		print("[Player Hitbox] Using fall attack damage calculation: ", damage)
	elif attack_name.begins_with("air_attack"):
		print("[Player Hitbox] Processing air attack: ", attack_name)
		# Extra debug information for air attack damage calculation
		print("[Player Hitbox] Getting damage from attack_manager for type: light and name: ", attack_name)
		var attack_damage = attack_manager.calculate_attack_damage(get_parent(), "light", attack_name)
		print("[Player Hitbox] Attack manager returned air attack damage: ", attack_damage)
		damage = attack_damage
	else:
		# Extra debug information for attack damage calculation
		print("[Player Hitbox] Getting damage from attack_manager for type: light and name: ", attack_name)
		var attack_damage = attack_manager.calculate_attack_damage(get_parent(), "light", attack_name)
		print("[Player Hitbox] Attack manager returned damage: ", attack_damage)
		damage = attack_damage
	
	combo_enabled = true
	print("[Player Hitbox] Final damage set to: ", damage, " for attack: ", attack_name)

func disable_combo():
	combo_multiplier = 1.0
	is_combo_hit = false
	current_attack_name = ""
	has_hit_enemy = false
	print("[Player Hitbox] Combo disabled")

func enable():
	print("[Player Hitbox] DEBUG - enable called with current_attack_name: ", current_attack_name, " and damage: ", damage)
	is_active = true
	monitoring = true
	monitorable = true
	has_hit_enemy = false  # Reset hit flag when enabling hitbox
	if has_node("CollisionShape2D"):
		get_node("CollisionShape2D").set_deferred("disabled", false)
		# Make hitbox more visible when active
		get_node("CollisionShape2D").debug_color = Color(0, 1, 0, 0.5)  # Green when active
		
		# Add extra debug for air attacks
		if current_attack_name.begins_with("air_attack"):
			print("[Player Hitbox] === AIR ATTACK HITBOX ENABLED ===")
			print("[Player Hitbox] Air attack: ", current_attack_name, " hitbox activated with damage: ", damage)
			print("[Player Hitbox] Collision shape: ", get_node("CollisionShape2D"))
			print("[Player Hitbox] Collision shape disabled: ", get_node("CollisionShape2D").disabled)
			print("[Player Hitbox] Monitoring: ", monitoring)
			print("[Player Hitbox] Monitorable: ", monitorable)
			
	print("[Player Hitbox] Enabled with damage: ", damage, " for attack: ", current_attack_name)

func disable():
	is_active = false
	monitoring = false
	monitorable = false
	if has_node("CollisionShape2D"):
		get_node("CollisionShape2D").set_deferred("disabled", true)
		get_node("CollisionShape2D").debug_color = Color(1, 0, 0, 0.5)  # Red when disabled
		
		# Add extra debug for air attacks
		if current_attack_name.begins_with("air_attack"):
			print("[Player Hitbox] === AIR ATTACK HITBOX DISABLED ===")
			print("[Player Hitbox] Air attack: ", current_attack_name, " hitbox deactivated")
	
	print("[Player Hitbox] Disabled for attack: ", current_attack_name)

func _on_area_entered(area: Area2D) -> void:
	print("[Player Hitbox] _on_area_entered called with area: ", area, " for attack: ", current_attack_name)
	if area.is_in_group("hurtbox"):
		print("[Player Hitbox] Hit detected on hurtbox for attack: ", current_attack_name, " with damage: ", damage)
		
		# Extra debug for air attacks
		if current_attack_name.begins_with("air_attack"):
			print("[Player Hitbox] !!! AIR ATTACK HIT DETECTED !!!")
			print("[Player Hitbox] Area groups: ", area.get_groups())
			print("[Player Hitbox] Target: ", area.get_parent().name if area.get_parent() else "Unknown")
		
		if not has_hit_enemy:
			has_hit_enemy = true
			hit_enemy.emit(area.get_parent())
			print("[Player Hitbox] Hit registered with damage: ", damage, " for attack: ", current_attack_name)
		else:
			print("[Player Hitbox] Hit ignored - already hit during this attack: ", current_attack_name)

func _physics_process(_delta: float) -> void:
	# Safety check - if not active but monitoring is on, disable it
	if not is_active and (monitoring or monitorable or (has_node("CollisionShape2D") and not get_node("CollisionShape2D").disabled)):
		disable()
			
