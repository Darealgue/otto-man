class_name EnemyHurtbox
extends BaseHurtbox

var slam_hit_cooldown := 0.5  # Longer cooldown for slam attacks

func _ready():
	super._ready()
	collision_layer = CollisionLayers.ENEMY_HURTBOX
	collision_mask = CollisionLayers.PLAYER_HITBOX

func _on_area_entered(hitbox: Area2D):
	# Only accept hits from the player
	if not hitbox is PlayerHitbox:
		return
		
	if is_on_cooldown(hitbox):
		return
	
	# Ignore self damage: compare owner_id meta
	var my_owner = get_parent().get_instance_id() if is_instance_valid(get_parent()) else -1
	var hb_owner = hitbox.get_meta("owner_id") if hitbox.has_meta("owner_id") else null
	
	if hb_owner != null and hb_owner == my_owner:
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
	print("[EnemyHurtbox] Emitting hurt signal for: ", enemy_name)
	hurt.emit(hitbox) 
