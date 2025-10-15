class_name EnemyHitbox
extends BaseHitbox

signal hit_player(player: Node)

# Enemy-specific properties
var attack_type: String = ""
var can_be_parried: bool = true
var stun_duration: float = 0.0
var is_parried: bool = false  # Track if the hitbox has been parried

func _ready():
	super._ready()
	collision_layer = CollisionLayers.ENEMY_HITBOX
	collision_mask = CollisionLayers.PLAYER_HURTBOX
	
	# Connect the area_entered signal
	area_entered.connect(_on_area_entered)

func setup_attack(type: String, parryable: bool = true, stun: float = 0.0):
	attack_type = type
	can_be_parried = parryable
	stun_duration = stun

# Override to include stun information
func get_knockback_data() -> Dictionary:
	var data = super.get_knockback_data()
	data["stun_duration"] = stun_duration
	return data

# Called when hitting the player
func _on_area_entered(area: Area2D) -> void:
	# Debug prints disabled to reduce console spam
	# print("[EnemyHitbox] Area entered: " + str(area.name) + " (groups: " + str(area.get_groups()) + ")")

	if area.is_in_group("player_hurtbox"):
		# print("[EnemyHitbox] ✅ Player hurtbox detected!")
		var player = area.get_parent()
		if player:
			# print("[EnemyHitbox] 🎯 Player found: " + str(player.name))
			# print("[EnemyHitbox] 📊 Enemy damage: " + str(damage))
			# Apply hitstop based on enemy damage
			var attack_manager = get_node("/root/AttackManager")
			if attack_manager:
				attack_manager.apply_hitstop(damage)
			else:
				print("[EnemyHitbox] ❌ ERROR: attack_manager is null!")
			# Apply screen shake when player gets hit
			_apply_enemy_screen_shake()
			# Only emit when not parried
			if not is_parried:
				hit_player.emit(player)
		else:
			print("[EnemyHitbox] ❌ ERROR: Player parent is null!")
	# else:
		# print("[EnemyHitbox] ❌ Area is not in player_hurtbox group")

func _apply_enemy_screen_shake():
	var screen_fx = get_node_or_null("/root/ScreenEffects")
	if not screen_fx or not screen_fx.has_method("shake"):
		return
	
	# Use same hitstop logic as player attacks for consistency
	var hitstop_duration = _get_hitstop_duration_enemy(damage)
	
	# Enemy attacks get slightly stronger shake to emphasize getting hit
	var shake_duration: float
	var shake_strength: float
	
	if hitstop_duration >= 0.08:  # Level 3 (61+ damage)
		shake_duration = 0.3
		shake_strength = 8.0
	elif hitstop_duration >= 0.04:  # Level 2 (31-60 damage)  
		shake_duration = 0.18
		shake_strength = 5.0
	else:  # Level 1 (0-30 damage)
		shake_duration = 0.1
		shake_strength = 3.0
	
	screen_fx.shake(shake_duration, shake_strength)

# Helper function to get hitstop duration for enemy attacks
func _get_hitstop_duration_enemy(dmg: float) -> float:
	if dmg >= 61:
		return 0.08  # Level 3
	elif dmg >= 31:
		return 0.04  # Level 2
	else:
		return 0.02  # Level 1
