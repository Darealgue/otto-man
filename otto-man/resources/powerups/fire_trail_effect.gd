extends Area2D

const LAYERS = {
	WORLD = 1,                
	PLAYER = 2,
	ENEMY = 4,                        
	PLAYER_HITBOX = 16,        
	PLAYER_HURTBOX = 8,       
	ENEMY_HITBOX = 64,       
	ENEMY_HURTBOX = 32,      
	ENEMY_PROJECTILE = 256    
}

var damage_per_second: float = 0
var duration: float = 0
var enemies_in_fire: Array[CharacterBody2D] = []
var damage_timer: float = 0
const DAMAGE_INTERVAL = 0.2  # Apply damage every 0.2 seconds

@onready var particles = $GPUParticles2D
@onready var collision = $CollisionShape2D

func initialize(damage: float, lifetime: float) -> void:
	damage_per_second = damage
	duration = lifetime

func _ready() -> void:
	collision_layer = 0
	collision_mask = LAYERS.ENEMY_HURTBOX
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	
	# Start animation
	if particles:
		particles.emitting = true
	
	# Start fade out timer if duration is set
	if duration > 0:
		await get_tree().create_timer(duration).timeout
		queue_free()

func _physics_process(delta: float) -> void:
	if duration <= 0:
		queue_free()
		return
		
	duration -= delta
	
	# Apply damage at regular intervals
	damage_timer -= delta
	if damage_timer <= 0 and not enemies_in_fire.is_empty():
		damage_timer = DAMAGE_INTERVAL
		apply_damage()

func apply_damage() -> void:
	var damage = damage_per_second * DAMAGE_INTERVAL
	for enemy in enemies_in_fire:
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			enemy.take_damage(damage, Vector2.ZERO)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("hurtbox") and area.get_parent().is_in_group("enemy"):
		var enemy = area.get_parent()
		if not enemies_in_fire.has(enemy):
			enemies_in_fire.append(enemy)

func _on_area_exited(area: Area2D) -> void:
	if area.is_in_group("hurtbox") and area.get_parent().is_in_group("enemy"):
		var enemy = area.get_parent()
		enemies_in_fire.erase(enemy) 