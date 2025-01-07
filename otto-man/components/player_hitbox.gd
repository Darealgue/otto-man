class_name PlayerHitbox
extends BaseHitbox

signal hit_enemy(enemy: Node)

# Player-specific properties
var combo_multiplier: float = 1.0
var is_combo_hit: bool = false
var current_attack_name: String = ""
var has_hit_enemy: bool = false  # Track if we've hit during this attack
var base_damage: float = 15.0  # Base damage value

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

func enable_combo(attack_name: String, multiplier: float):
	print("\n[DEBUG] Player Hitbox - Enabling combo attack:", attack_name)
	print("   Raw Combo Multiplier:", multiplier)
	
	combo_multiplier = multiplier
	is_combo_hit = true
	current_attack_name = attack_name
	
	# Set damage based on attack type
	if attack_name == "fall_attack":
		damage = 20.0  # Fall attack has fixed damage
		print("   Fall Attack - Fixed damage:", damage)
	else:
		# Use AttackManager for normal attacks
		damage = attack_manager.calculate_attack_damage(get_parent(), "light", attack_name)
		print("   Final Hitbox Damage:", damage)
	
	has_hit_enemy = false  # Reset hit flag when enabling combo

func disable_combo():
	combo_multiplier = 1.0
	is_combo_hit = false
	current_attack_name = ""
	has_hit_enemy = false

func enable():
	is_active = true
	monitoring = true
	monitorable = true
	has_hit_enemy = false  # Reset hit flag when enabling hitbox
	if has_node("CollisionShape2D"):
		get_node("CollisionShape2D").set_deferred("disabled", false)
		# Make hitbox more visible when active
		get_node("CollisionShape2D").debug_color = Color(0, 1, 0, 0.5)  # Green when active
		
	print("[DEBUG] Player Hitbox - Enabled with damage:", damage)

func disable():
	is_active = false
	monitoring = false
	monitorable = false
	has_hit_enemy = false
	if has_node("CollisionShape2D"):
		var shape = get_node("CollisionShape2D")
		shape.set_deferred("disabled", true)
		# Reset color to red when inactive
		shape.debug_color = Color(1, 0, 0, 0.5)

# Called when hitting an enemy
func _on_area_entered(area: Area2D) -> void:
	if not is_active or not monitoring or has_hit_enemy:
		return
		
	if area.is_in_group("enemy_hurtbox"):
		var enemy = area.get_parent()
		if enemy:
			has_hit_enemy = true  # Mark that we've hit during this attack
			print("[DEBUG] Player Hitbox - Hit enemy with damage:", damage)
			hit_enemy.emit(enemy)
			
func _physics_process(_delta: float) -> void:
	# Safety check - if not active but monitoring is on, disable it
	if not is_active and (monitoring or monitorable or (has_node("CollisionShape2D") and not get_node("CollisionShape2D").disabled)):
		disable()
	
