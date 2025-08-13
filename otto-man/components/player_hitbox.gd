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
	collision_layer = CollisionLayers.PLAYER_HITBOX
	collision_mask = CollisionLayers.ENEMY_HURTBOX
	# Ensure hitbox starts inactive but visible for debugging
	monitoring = false
	monitorable = false
	is_active = false
	if has_node("CollisionShape2D"):
		var shape = get_node("CollisionShape2D")
		# Keep the shape visible but disabled for debugging
		shape.set_deferred("disabled", true)
		shape.debug_color = Color(1, 0, 0, 0.5)  # Red with 50% transparency

func enable_combo(attack_name: String, damage_multiplier: float = 1.0) -> void:
	current_attack_name = attack_name
	
	# Determine attack type based on name
	var attack_type = "light"  # Default attack type
	
	# Set damage based on attack type
	if attack_name == "fall_attack":
		damage = PlayerStats.get_fall_attack_damage() * damage_multiplier
	elif attack_name.begins_with("air_attack"):
		# Extra debug information for air attack damage calculation
		var attack_damage = attack_manager.calculate_attack_damage(get_parent(), "light", attack_name)
		damage = attack_damage
	else:
		# Extra debug information for attack damage calculation
		var attack_damage = attack_manager.calculate_attack_damage(get_parent(), "light", attack_name)
		damage = attack_damage
	
	combo_enabled = true

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
		

func disable():
	is_active = false
	monitoring = false
	monitorable = false
	if has_node("CollisionShape2D"):
		get_node("CollisionShape2D").set_deferred("disabled", true)
		get_node("CollisionShape2D").debug_color = Color(1, 0, 0, 0.5)  # Red when disabled
		

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("hurtbox"):
		
		
		if not has_hit_enemy:
			has_hit_enemy = true
			hit_enemy.emit(area.get_parent())
			
func _physics_process(_delta: float) -> void:
	# Safety check - if not active but monitoring is on, disable it
	if not is_active and (monitoring or monitorable or (has_node("CollisionShape2D") and not get_node("CollisionShape2D").disabled)):
		disable()
			
