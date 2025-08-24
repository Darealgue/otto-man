class_name EnemyHurtbox
extends BaseHurtbox

var slam_hit_cooldown := 0.5  # Longer cooldown for slam attacks

func _ready():
	super._ready()
	collision_layer = CollisionLayers.ENEMY_HURTBOX
	collision_mask = CollisionLayers.PLAYER_HITBOX

func _on_area_entered(hitbox: Area2D):
	if not hitbox is PlayerHitbox:
		return
		
	if is_on_cooldown(hitbox):
		return
	
	# Store hit data
	store_hit_data(hitbox)
	
	# Use longer cooldown for slam attacks
	var cooldown = slam_hit_cooldown if hitbox.get_parent().name.contains("HeavyEnemy") else hit_cooldown
	start_cooldown(hitbox, cooldown)
	
	# Debug: log incoming hit
	var enemy_name = get_parent().name if get_parent() != null else name
	var dmg = hitbox.get_damage() if hitbox.has_method("get_damage") else -1
	print("[EnemyHurtbox:", enemy_name, "] hit by=", hitbox.name, " dmg=", dmg, " layer=", hitbox.collision_layer, " mask=", hitbox.collision_mask)
	
	# Emit hurt signal
	hurt.emit(hitbox) 
