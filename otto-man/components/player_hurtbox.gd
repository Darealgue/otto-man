class_name PlayerHurtbox
extends BaseHurtbox

var invincibility_timer := 0.0
var can_be_parried := true

func _ready():
	super._ready()
	collision_layer = CollisionLayers.PLAYER_HURTBOX
	collision_mask = CollisionLayers.ENEMY_HITBOX

func _on_area_entered(hitbox: Area2D):
	if not hitbox is EnemyHitbox:
		return
		
	if is_on_cooldown(hitbox):
		return
	
	# Store hit data
	store_hit_data(hitbox)
	
	# Check if parent is in block state
	var parent = get_parent()
	if parent.has_node("StateMachine") and parent.state_machine.current_state.name == "Block":
		# Let block state handle the damage value
		await parent.state_machine.current_state._on_hurtbox_hurt(hitbox)
	
	# Start cooldown and emit signal
	start_cooldown(hitbox)
	hurt.emit(hitbox)

func set_invincible(duration: float):
	invincibility_timer = duration

func is_invincible() -> bool:
	return invincibility_timer > 0.0

func _process(delta: float):
	super._process(delta)
	if invincibility_timer > 0:
		invincibility_timer -= delta 
