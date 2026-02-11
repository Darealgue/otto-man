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
	
	# Connect the area_entered signal
	area_entered.connect(_on_area_entered)
	
	# Ensure hitbox starts inactive but visible for debugging
	monitoring = false
	monitorable = false
	is_active = false
	if has_node("CollisionShape2D"):
		var shape = get_node("CollisionShape2D")
		# Keep the shape visible but disabled for debugging
		shape.set_deferred("disabled", true)
		shape.debug_color = Color(1, 0, 0, 0.5)  # Red with 50% transparency

func enable_combo(attack_name: String, damage_multiplier: float = 1.0, kb_multiplier: float = 1.0, kb_up_multiplier: float = 1.0) -> void:
	current_attack_name = attack_name
	
	# Determine attack type based on name
	var attack_type = "light"  # Default attack type
	if attack_name.find("heavy") != -1:
		attack_type = "heavy"
	
	# Set damage based on attack type
	if attack_name == "fall_attack":
		damage = PlayerStats.get_fall_attack_damage()
	elif attack_name.begins_with("air_attack"):
		# Extra debug information for air attack damage calculation
		var attack_damage = attack_manager.calculate_attack_damage(get_parent(), attack_type, attack_name)
		damage = attack_damage
	else:
		# Extra debug information for attack damage calculation
		var attack_damage = attack_manager.calculate_attack_damage(get_parent(), attack_type, attack_name)
		damage = attack_damage
	
	# Apply damage multiplier (used by heavy or just timing bonus)
	damage *= max(0.0, damage_multiplier)
	
	# Base knockback from AttackManager (then override per variant)
	if attack_manager and attack_manager.has_method("calculate_knockback"):
		var kb: Dictionary = attack_manager.calculate_knockback(get_parent(), attack_type, attack_name)
		if kb and kb.has("force") and kb.has("up_force"):
			knockback_force = kb["force"]
			knockback_up_force = kb["up_force"]

	# Knockback tuning per attack
	if attack_name == "up_light":
		knockback_force = 120.0
		knockback_up_force = 220.0
	elif attack_name.begins_with("attack_up"):
		# Up combo attacks - launch enemies upward (stronger than single up_light)
		knockback_force = 120.0
		knockback_up_force = 280.0  # Increased from 220.0 for better combo launching
	elif attack_name == "down_light":
		knockback_force = 180.0
		knockback_up_force = 40.0
	elif attack_name.begins_with("attack_down"):
		# Down combo attacks - no upward launch, similar to down_light
		knockback_force = 180.0
		knockback_up_force = 40.0
	elif attack_name == "up_heavy":
		knockback_force = 160.0
		knockback_up_force = 380.0
	elif attack_name == "down_heavy":
		knockback_force = 260.0
		knockback_up_force = 60.0
	else:
		# default light/heavy derived from AttackManager if needed later
		pass
	
	# Apply knockback multipliers (for perfect timing window)
	knockback_force *= max(0.0, kb_multiplier)
	knockback_up_force *= max(0.0, kb_up_multiplier)
	combo_enabled = true
	# Debug print disabled to reduce console spam
	# print("[PlayerHitbox] COMBO SET | type=", attack_type, " name=", attack_name, " dmg=", damage, " kb=", knockback_force, "/", knockback_up_force)

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
	# Debug prints disabled to reduce console spam
	# print("[PlayerHitbox] ENABLE name=", name, " dmg=", damage)
	# print("[PlayerHitbox]    current_attack=", current_attack_name, " combo_enabled=", combo_enabled)
	if has_node("CollisionShape2D"):
		get_node("CollisionShape2D").set_deferred("disabled", false)
		# Make hitbox more visible when active
		get_node("CollisionShape2D").debug_color = Color(0, 1, 0, 0.5)  # Green when active
		

func disable():
	is_active = false
	monitoring = false
	monitorable = false
	# Debug print disabled to reduce console spam
	# print("[PlayerHitbox] DISABLE name=", name)
	if has_node("CollisionShape2D"):
		get_node("CollisionShape2D").set_deferred("disabled", true)
		get_node("CollisionShape2D").debug_color = Color(1, 0, 0, 0.5)  # Red when disabled
		

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("hurtbox"):
		# Debug print disabled to reduce console spam
		# print("[PlayerHitbox] overlapped with hurtbox area=", area.name)
		if not has_hit_enemy:
			has_hit_enemy = true
			
			# Debug prints disabled to reduce console spam
			# print("[PlayerHitbox] 🥊 HIT CONFIRMED! Damage: " + str(damage))
			# print("[PlayerHitbox] DEBUG | attack=", current_attack_name, " kb=", knockback_force, "/", knockback_up_force)
			
			# Apply hitstop based on damage
			if attack_manager:
				# print("[PlayerHitbox] Calling attack_manager.apply_hitstop(" + str(damage) + ")")
				attack_manager.apply_hitstop(damage)
			else:
				print("[PlayerHitbox] ❌ ERROR: attack_manager is null!")
			# Spawn enemy hit VFX
			var enemy_hit_fx_scene_path := "res://effects/enemy_hit_effect.tscn"
			if ResourceLoader.exists(enemy_hit_fx_scene_path):
				var fx_scene := load(enemy_hit_fx_scene_path)
				if fx_scene:
					var fx = fx_scene.instantiate()
					
					# Düşmanın merkezinde spawnla
					var enemy = area.get_parent()
					var spawn_position = global_position  # Fallback
					
					if enemy and is_instance_valid(enemy):
						# Düşmanın sprite'ını bul ve merkezini hesapla
						var enemy_sprite = enemy.get_node_or_null("AnimatedSprite2D")
						if not enemy_sprite:
							enemy_sprite = enemy.get_node_or_null("Sprite2D")
						
						if enemy_sprite and is_instance_valid(enemy_sprite):
							# Sprite'ın global pozisyonunu al
							spawn_position = enemy_sprite.global_position
							
							# Sprite'ın görsel merkezini hesapla (centered = false ise offset ekle)
							var texture_size = Vector2.ZERO
							var is_centered = true
							
							if enemy_sprite is AnimatedSprite2D:
								var anim_sprite = enemy_sprite as AnimatedSprite2D
								is_centered = anim_sprite.centered
								if anim_sprite.sprite_frames and anim_sprite.animation:
									var current_texture = anim_sprite.sprite_frames.get_frame_texture(anim_sprite.animation, anim_sprite.frame)
									if current_texture:
										texture_size = current_texture.get_size()
							elif enemy_sprite is Sprite2D:
								var sprite = enemy_sprite as Sprite2D
								is_centered = sprite.centered
								if sprite.texture:
									texture_size = sprite.texture.get_size()
									if sprite.hframes > 1:
										texture_size.x = texture_size.x / sprite.hframes
									if sprite.vframes > 1:
										texture_size.y = texture_size.y / sprite.vframes
							
							# Eğer sprite centered değilse, görsel merkeze getirmek için offset ekle
							if not is_centered and texture_size != Vector2.ZERO:
								# Sprite'ın local position'ı zaten global_position'a dahil
								# Texture boyutunun yarısını ekleyerek merkeze getir
								spawn_position += Vector2(texture_size.x * 0.5, -texture_size.y * 0.5)
							
						else:
							# Sprite bulunamazsa düşmanın global_position'ını kullan
							spawn_position = enemy.global_position
					else:
						# Enemy is null or invalid, use fallback position
						spawn_position = global_position
					
					# Efektin sprite'ının da merkezini dikkate al (centered = false olduğu için)
					# Efektin sprite'ı _ready()'de yüklenecek, bu yüzden texture boyutunu tahmin ediyoruz
					# Hit efektleri genellikle 64x64 veya 128x128 boyutunda
					# _ready() tamamlandıktan sonra efektin sprite'ının texture boyutunu alıp merkeze getireceğiz
					
					
					# Saldırı türüne göre efekt ve boyut ayarla
					var effect_data = _get_hit_effect_data()
					
					# Sahneye ekle (add_child çağrıldığında _ready() otomatik çağrılır)
					get_tree().current_scene.add_child(fx)
					
					# Setup'ı çağır ve pozisyonu direkt parametre olarak geç
					fx.setup(Vector2.ZERO, effect_data.scale, effect_data.effect_type, spawn_position)
					
					# Pozisyonu _ready() tamamlandıktan sonra ayarla ve efektin sprite merkezini dikkate al
					fx.call_deferred("_adjust_position_to_center", spawn_position)
			# Camera shake based on attack type and damage
			_apply_screen_shake()
			# Apply player air-combo float on successful hit while airborne
			var player_node = get_parent()
			if player_node:
				# Refresh or extend float duration on each hit
				player_node.air_combo_float_timer = max(player_node.air_combo_float_timer, player_node.air_combo_float_duration)
				
				# Recoil disabled - player no longer gets knockback from hitting enemies
				# _apply_player_hit_recoil(player_node, area)
			
			hit_enemy.emit(area.get_parent())
			
func _apply_screen_shake():
	var screen_fx = get_node_or_null("/root/ScreenEffects")
	if not screen_fx or not screen_fx.has_method("shake"):
		return
	
	# Get hitstop duration based on damage (same logic as AttackManager)
	var hitstop_duration = _get_hitstop_duration(damage)
	
	# Scale shake duration and strength based on hitstop level
	var shake_duration: float
	var shake_strength: float
	
	# Map hitstop duration to shake parameters
	if hitstop_duration >= 0.08:  # Level 3 (61+ damage)
		shake_duration = 0.25
		shake_strength = 6.0
	elif hitstop_duration >= 0.04:  # Level 2 (31-60 damage)  
		shake_duration = 0.15
		shake_strength = 4.0
	else:  # Level 1 (0-30 damage)
		shake_duration = 0.08
		shake_strength = 2.0
	
	# Apply attack type modifiers for variety
	var attack_modifier = _get_attack_type_modifier()
	shake_duration *= attack_modifier.duration
	shake_strength *= attack_modifier.strength
	
	screen_fx.shake(shake_duration, shake_strength)

# Helper function to get hitstop duration (mirrors AttackManager logic)
func _get_hitstop_duration(dmg: float) -> float:
	if dmg >= 61:
		return 0.08  # Level 3
	elif dmg >= 31:
		return 0.04  # Level 2
	else:
		return 0.02  # Level 1

# Helper function for attack-specific modifiers
func _get_attack_type_modifier() -> Dictionary:
	match current_attack_name:
		# Heavy attacks get stronger shake
		"heavy_neutral", "up_heavy", "down_heavy", "counter_heavy", "air_heavy":
			return {"duration": 1.3, "strength": 1.4}
		# Counter attacks get extra impact
		"counter_light", "counter_heavy":
			return {"duration": 1.2, "strength": 1.3}
		# Air combo finishers get more impact
		"air_attack3", "fall_attack":
			return {"duration": 1.1, "strength": 1.2}
		# Light combo finishers get slight boost
		"attack_1.4":
			return {"duration": 1.1, "strength": 1.1}
		_:
			return {"duration": 1.0, "strength": 1.0}

# Helper function for hit effect data based on attack type
func _get_hit_effect_data() -> Dictionary:
	match current_attack_name:
		# Heavy attacks - büyük efekt (hit3), büyük boyut
		"heavy_neutral", "up_heavy", "down_heavy", "counter_heavy", "air_heavy":
			return {"effect_type": 2, "scale": 1.5}  # hit3, 1.5x boyut
		# Counter attacks - orta efekt (hit2), orta boyut
		"counter_light", "counter_heavy":
			return {"effect_type": 1, "scale": 1.2}  # hit2, 1.2x boyut
		# Air combo finishers - büyük efekt
		"air_attack3", "fall_attack":
			return {"effect_type": 2, "scale": 1.3}  # hit3, 1.3x boyut
		# Up attacks - orta efekt (yukarı saldırı)
		"air_attack_up1", "air_attack_up2", "attack_up1", "attack_up2", "attack_up3":
			return {"effect_type": 1, "scale": 1.1}  # hit2, 1.1x boyut
		# Light attacks - küçük efekt (hit1), normal boyut
		"attack_1", "attack_1.2", "attack_1.3", "attack_1.4", "air_attack1", "air_attack2", "attack_down1", "attack_down2":
			return {"effect_type": 0, "scale": 1.0}  # hit1, normal boyut
		# Default - rastgele efekt
		_:
			return {"effect_type": -1, "scale": 1.0}  # rastgele, normal boyut

func _apply_player_hit_recoil(player: Node, enemy_hurtbox: Area2D) -> void:
	"""Apply slight knockback to player when hitting an enemy for better hit feedback.
	Player stays facing the enemy but moves backward slightly (like Hollow Knight Silksong)."""
	if not player or not enemy_hurtbox:
		return
	
	# Player must be CharacterBody2D to have velocity
	if not player is CharacterBody2D:
		return
	
	var player_body: CharacterBody2D = player as CharacterBody2D
	
	# Get enemy position to ensure player faces the enemy
	var enemy = enemy_hurtbox.get_parent()
	if not enemy:
		return
	
	var player_pos: Vector2 = player_body.global_position
	
	# Get current facing direction (don't change it)
	var current_facing: float = 1.0
	if "facing_direction" in player:
		current_facing = player.facing_direction
	else:
		# Fallback: use sprite flip
		if "sprite" in player and player.sprite:
			current_facing = -1.0 if player.sprite.flip_h else 1.0
	
	# Recoil direction is opposite of current facing direction (backward)
	var recoil_direction: Vector2 = Vector2(-current_facing, 0.0)
	
	# Calculate recoil force based on attack type
	# Pure horizontal recoil - no vertical component to keep player grounded for combos
	var recoil_force: float = 80.0  # Base recoil force (horizontal only)
	var recoil_up: float = 0.0      # No upward component - keep player grounded
	
	# Heavy attacks have more recoil
	if current_attack_name.find("heavy") != -1:
		recoil_force = 120.0  # Stronger horizontal recoil
		recoil_up = 0.0       # Still no vertical component
	# Down attacks have more recoil (still horizontal)
	elif current_attack_name.find("down") != -1:
		recoil_force = 100.0
		recoil_up = 0.0       # No vertical component
	# Up attacks have more recoil (still horizontal)
	elif current_attack_name.find("up") != -1:
		recoil_force = 90.0
		recoil_up = 0.0       # No vertical component
	
	# Apply recoil to player velocity (backward relative to facing direction)
	# Only apply horizontal recoil, preserve vertical velocity (gravity, jump, etc.)
	var current_velocity: Vector2 = player_body.velocity
	var recoil_velocity: Vector2 = recoil_direction * recoil_force
	player_body.velocity.x = current_velocity.x + recoil_velocity.x
	# Don't modify vertical velocity - let gravity and other systems handle it
	
	# Clamp horizontal recoil to prevent excessive knockback (but preserve vertical velocity)
	var max_horizontal_recoil: float = 150.0
	if abs(player_body.velocity.x) > max_horizontal_recoil:
		player_body.velocity.x = sign(player_body.velocity.x) * max_horizontal_recoil

func _physics_process(_delta: float) -> void:
	# Safety check - if not active but monitoring is on, disable it
	if not is_active and (monitoring or monitorable or (has_node("CollisionShape2D") and not get_node("CollisionShape2D").disabled)):
		disable()
			
