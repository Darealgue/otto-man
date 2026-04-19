extends BaseHitbox
class_name PlayerHitbox

signal hit_enemy(enemy: Node)

# Player-specific properties
var combo_multiplier: float = 1.0
var is_combo_hit: bool = false
var current_attack_name: String = ""
var has_hit_enemy: bool = false  # Track if we've hit during this attack
var max_targets_per_attack: int = 1  # Max enemies per attack (items can set e.g. 2 for fall attack)
var _registered_hit_target_ids: Array = []  # Instance IDs of enemies that can take this hit
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
		knockback_up_force = 110.0  # Reduced from 220.0 (50% of original)
	elif attack_name.begins_with("attack_up"):
		# Up combo attacks - launch enemies upward (stronger than single up_light)
		knockback_force = 120.0
		knockback_up_force = 140.0  # Reduced from 280.0 (50% of original)
	elif attack_name == "down_light":
		knockback_force = 180.0
		knockback_up_force = 40.0
	elif attack_name.begins_with("attack_down"):
		# Down combo attacks - no upward launch, similar to down_light
		knockback_force = 180.0
		knockback_up_force = 40.0
	elif attack_name == "up_heavy":
		knockback_force = 160.0
		knockback_up_force = 190.0  # Reduced from 380.0 (50% of original)
	elif attack_name == "air_attack_up1" or attack_name == "air_attack_up2":
		# Air up attacks - reduced upward force
		knockback_force = 120.0
		knockback_up_force = 110.0  # Same as up_light (50% of what would be default)
	elif attack_name == "down_heavy":
		knockback_force = 260.0
		knockback_up_force = 60.0
	elif attack_name == "air_attack_down1" or attack_name == "air_attack_down2":
		# Air down attacks - apply downward force to enemies (fırlatır)
		knockback_force = 150.0
		knockback_up_force = -200.0  # Negative value for downward force
	elif attack_name == "air_attack1" or attack_name == "air_attack2" or attack_name == "air_attack3":
		# Düz havada vuruş - kombo kilidi, düşman yakında kalsın (uzağa fırlamasın)
		knockback_force = 28.0
		knockback_up_force = 22.0
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

## Decoy için: player hitbox'tan state kopyala (aynı hasar, hedef limiti, knockback, collision shape)
func sync_from_player_hitbox(source: PlayerHitbox) -> void:
	damage = source.damage
	knockback_force = source.knockback_force
	knockback_up_force = source.knockback_up_force
	current_attack_name = source.current_attack_name
	max_targets_per_attack = source.max_targets_per_attack
	combo_enabled = true
	# Collision shape pozisyonunu da kopyala (up/down/normal varyantları için)
	var src_cs = source.get_node_or_null("CollisionShape2D")
	var dst_cs = get_node_or_null("CollisionShape2D")
	if src_cs and dst_cs:
		dst_cs.position = src_cs.position

## Hedeften hasar alırken flank/gorunmezlik çarpanlarını uygula (DamageModifiers merkezi)
## Mirror modunda: damage_source ve attacker_position_override meta ile decoy desteği
func get_damage_for_target(enemy: Node) -> float:
	var player: Node = get_meta("damage_source") if has_meta("damage_source") else get_parent()
	var attacker_pos: Vector2 = get_meta("attacker_position_override") if has_meta("attacker_position_override") else (player.global_position if player else global_position)
	if not player:
		return damage
	if has_node("/root/DamageModifiers"):
		return DamageModifiers.apply_player_modifiers(player, damage, enemy, attacker_pos, false)
	return damage

func enable():
	is_active = true
	monitoring = true
	monitorable = true
	has_hit_enemy = false  # Reset hit flag when enabling hitbox
	_registered_hit_target_ids.clear()
	# Debug prints disabled to reduce console spam
	# print("[PlayerHitbox] ENABLE name=", name, " dmg=", damage)
	# print("[PlayerHitbox]    current_attack=", current_attack_name, " combo_enabled=", combo_enabled)
	if has_node("CollisionShape2D"):
		get_node("CollisionShape2D").set_deferred("disabled", false)
		# Make hitbox more visible when active
		get_node("CollisionShape2D").debug_color = Color(0, 1, 0, 0.5)  # Green when active
		

func _enemy_is_dead(enemy: Node) -> bool:
	if not is_instance_valid(enemy):
		return true
	if enemy.get("current_behavior") == "dead":
		return true
	if enemy.get("health") != null and float(enemy.health) <= 0.0:
		return true
	return false


## Oyuncuya göre yakınlık (vuruş alanı çoğu zaman önde; "bana yakın" hissi için karakter merkezi).
func _hit_priority_anchor() -> Vector2:
	var p := get_parent()
	if p is Node2D:
		return (p as Node2D).global_position
	return global_position


func _distance_squared_to_anchor(hb: Area2D) -> float:
	return hb.global_position.distance_squared_to(_hit_priority_anchor())


func _is_enemy_hurtbox_candidate(a: Area2D) -> bool:
	if a.is_in_group("hurtbox"):
		return true
	var p := a.get_parent()
	return is_instance_valid(p) and p.is_in_group("enemies")


func _living_hurtboxes_nearest_first(overlapping: Array) -> Array[Area2D]:
	var living: Array[Area2D] = []
	for a in overlapping:
		if not a is Area2D:
			continue
		var area2d := a as Area2D
		if not _is_enemy_hurtbox_candidate(area2d):
			continue
		var en: Node = area2d.get_parent()
		if not is_instance_valid(en):
			continue
		if _enemy_is_dead(en):
			continue
		living.append(area2d)
	living.sort_custom(func(a: Area2D, b: Area2D) -> bool:
		return _distance_squared_to_anchor(a) < _distance_squared_to_anchor(b)
	)
	return living


## Returns true if this hurtbox/enemy is allowed to take the hit (up to max_targets_per_attack).
## Ölü düşmanlar kotaya sayılmaz. Yaşayanlarda area_entered sırası önemsiz: örtüşenler arasından
## oyuncuya en yakın (max_targets kadar) hedef kabul edilir; uzaktaki yanlışlıkla önce sinyal verse bile reddedilir.
func try_register_hit(hurtbox: Area2D) -> bool:
	var enemy = hurtbox.get_parent() if hurtbox else null
	if not is_instance_valid(enemy):
		return false
	if _enemy_is_dead(enemy):
		return true
	# Aynı frame'de hurtbox sinyali geldiğinde hitbox tarafında overlap listesi bazen henüz dolmuyor;
	# çağıran hurtbox'ı mutlaka aday listesine ekle (aksi halde hasar hiç uygulanmıyordu).
	var areas: Array[Area2D] = []
	for x in get_overlapping_areas():
		if x is Area2D:
			areas.append(x as Area2D)
	var caller_included := false
	for x in areas:
		if x == hurtbox:
			caller_included = true
			break
	if not caller_included:
		areas.append(hurtbox)
	var living_sorted := _living_hurtboxes_nearest_first(areas)
	if living_sorted.is_empty():
		return false
	var take_n: int = mini(max_targets_per_attack, living_sorted.size())
	var in_topk := false
	for i in range(take_n):
		if living_sorted[i] == hurtbox:
			in_topk = true
			break
	if not in_topk:
		return false
	var eid = enemy.get_instance_id()
	if eid in _registered_hit_target_ids:
		return true  # Already registered this attack
	if _registered_hit_target_ids.size() >= max_targets_per_attack:
		return false
	_registered_hit_target_ids.append(eid)
	return true

func disable():
	is_active = false
	monitoring = false
	monitorable = false
	# Debug print disabled to reduce console spam
	# print("[PlayerHitbox] DISABLE name=", name)
	if has_node("CollisionShape2D"):
		get_node("CollisionShape2D").set_deferred("disabled", true)
		get_node("CollisionShape2D").debug_color = Color(1, 0, 0, 0.5)  # Red when disabled
		

func _nearest_hurtbox_in(candidates: Array[Area2D]) -> Area2D:
	if candidates.is_empty():
		return null
	var best: Area2D = candidates[0]
	var best_d2: float = _distance_squared_to_anchor(best)
	for i in range(1, candidates.size()):
		var hb: Area2D = candidates[i]
		var d2 := _distance_squared_to_anchor(hb)
		if d2 < best_d2:
			best_d2 = d2
			best = hb
	return best


## Tüm overlap eden hurtbox'lardan en iyi hedefi seç: yaşayan düşman öncelikli, sonra vuruşa en yakın.
func _pick_best_hurtbox_target(overlapping: Array) -> Area2D:
	var hurtboxes: Array[Area2D] = []
	for a in overlapping:
		if not a is Area2D:
			continue
		var area2d := a as Area2D
		if not _is_enemy_hurtbox_candidate(area2d):
			continue
		hurtboxes.append(area2d)
	if hurtboxes.is_empty():
		return null
	var living: Array[Area2D] = []
	var corpses: Array[Area2D] = []
	for hb in hurtboxes:
		var enemy = hb.get_parent() if hb else null
		if not is_instance_valid(enemy):
			continue
		if _enemy_is_dead(enemy):
			corpses.append(hb)
		else:
			living.append(hb)
	if not living.is_empty():
		return _nearest_hurtbox_in(living)
	if not corpses.is_empty():
		return _nearest_hurtbox_in(corpses)
	return null

func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("hurtbox"):
		return
	if has_hit_enemy:
		return
	var overlapping = get_overlapping_areas()
	var best_hurtbox = _pick_best_hurtbox_target(overlapping)
	if not best_hurtbox:
		return
	var enemy = best_hurtbox.get_parent() if best_hurtbox else null
	if not is_instance_valid(enemy):
		return
	if has_method("try_register_hit") and not try_register_hit(best_hurtbox):
		return
	has_hit_enemy = true
	if _enemy_is_dead(enemy):
		# Havada ölü (punching bag): hit stop + screen shake + kısa havada asılı kalma (Street Fighter tarzı)
		if not (enemy.has_method("is_on_floor") and enemy.is_on_floor()):
			if attack_manager:
				attack_manager.apply_hitstop(damage)
			_apply_screen_shake()
			# Fall attack bounce + impact fall_attack_state'te; air_hit_freeze burada velocity'yi sıfırlayıp asılı bırakıyordu
			if current_attack_name != "fall_attack":
				_apply_air_combo_float()
		# Sadece yerde yatan ceset vurulunca tekmelenme animasyonu (frame 5'ten)
		if enemy.has_method("is_on_floor") and enemy.is_on_floor():
			if enemy.has_method("play_corpse_hit_animation"):
				enemy.play_corpse_hit_animation()
			else:
				_play_corpse_death_from_frame(enemy, 5)
		hit_enemy.emit(enemy)
		return
	# Yaşayan düşman: hit stop + screen shake düşman tarafında uygulanıyor (apply_killing_blow_effects)
	var spawn_position = _get_enemy_effect_position(enemy)
	var enemy_hit_fx_scene_path = "res://effects/enemy_hit_effect.tscn"
	if ResourceLoader.exists(enemy_hit_fx_scene_path):
		var fx_scene = load(enemy_hit_fx_scene_path)
		if fx_scene:
			var fx = fx_scene.instantiate()
			get_tree().current_scene.add_child(fx)
			var effect_data = _get_hit_effect_data()
			fx.setup(Vector2.ZERO, effect_data.scale, effect_data.effect_type, spawn_position)
			fx.call_deferred("_adjust_position_to_center", spawn_position)
	if current_attack_name != "fall_attack":
		_apply_air_combo_float()
	hit_enemy.emit(enemy)

func _get_enemy_effect_position(enemy: Node) -> Vector2:
	var spawn_position = global_position
	if not enemy or not is_instance_valid(enemy):
		return spawn_position
	var enemy_sprite = enemy.get_node_or_null("AnimatedSprite2D")
	if not enemy_sprite:
		enemy_sprite = enemy.get_node_or_null("Sprite2D")
	if not enemy_sprite or not is_instance_valid(enemy_sprite):
		return enemy.global_position
	spawn_position = enemy_sprite.global_position
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
		var spr = enemy_sprite as Sprite2D
		is_centered = spr.centered
		if spr.texture:
			texture_size = spr.texture.get_size()
			if spr.hframes > 1:
				texture_size.x = texture_size.x / spr.hframes
			if spr.vframes > 1:
				texture_size.y = texture_size.y / spr.vframes
	if not is_centered and texture_size != Vector2.ZERO:
		spawn_position += Vector2(texture_size.x * 0.5, -texture_size.y * 0.5)
	return spawn_position

## Ceset vurulunca death animasyonunu frame 5'ten oynat (tekmelenme hissi)
func _play_corpse_death_from_frame(enemy: Node, start_frame: int) -> void:
	var spr = enemy.get_node_or_null("AnimatedSprite2D")
	if not spr or not spr is AnimatedSprite2D:
		return
	var anim_sprite = spr as AnimatedSprite2D
	if not anim_sprite.sprite_frames:
		return
	var anim_name = "death" if anim_sprite.sprite_frames.has_animation("death") else ("dead" if anim_sprite.sprite_frames.has_animation("dead") else "")
	if anim_name.is_empty():
		return
	anim_sprite.play(anim_name)
	var frame_count = anim_sprite.sprite_frames.get_frame_count(anim_name)
	anim_sprite.frame = mini(start_frame, frame_count - 1) if frame_count > 0 else 0

## Havada düşmana/cesede vurduğunda: kısa donma + kısa asılı kalma (sadece vuruşlar sırasında, takip vuruşu için).
func _apply_air_combo_float() -> void:
	var player_node = get_meta("damage_source") if has_meta("damage_source") else null
	if not player_node or player_node.get("air_hit_freeze_timer") == null:
		var p = get_parent()
		while p:
			if p.get("air_hit_freeze_timer") != null:
				player_node = p
				break
			p = p.get_parent()
	if not player_node or player_node.get("air_hit_freeze_timer") == null:
		return
	if player_node.has_method("is_on_floor") and player_node.is_on_floor():
		return
	# Vuruş anında kısa donma
	if player_node.get("air_hit_freeze_duration") != null:
		player_node.air_hit_freeze_timer = player_node.air_hit_freeze_duration
	# Hemen sonra kısa asılı kalma (bir vuruş daha atabilsin diye)
	if player_node.get("air_combo_float_timer") != null and player_node.get("air_combo_float_duration") != null:
		player_node.air_combo_float_timer = max(player_node.air_combo_float_timer, player_node.air_combo_float_duration)
	# Enemy Step tarzı: havada vurduğunda hafif yukarı kalkma (DMC/Bayonetta)
	if player_node.get("air_hit_lift_velocity") != null and player_node.get("velocity") != null:
		var lift: float = player_node.air_hit_lift_velocity
		if player_node.velocity.y > lift:
			player_node.velocity.y = lift

## Öldürücü vuruşta çağrılır (düşman tarafında); ceset vurulduğunda çağrılmaz.
func apply_killing_blow_effects(damage_amount: float) -> void:
	if attack_manager:
		attack_manager.apply_hitstop(damage_amount)
	_apply_screen_shake_with_damage(damage_amount)

func _apply_screen_shake():
	_apply_screen_shake_with_damage(damage)

func _apply_screen_shake_with_damage(dmg: float) -> void:
	var screen_fx = get_node_or_null("/root/ScreenEffects")
	if not screen_fx or not screen_fx.has_method("shake"):
		return
	
	# Get hitstop duration based on damage (same logic as AttackManager)
	var hitstop_duration = _get_hitstop_duration(dmg)
	
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
	
	# Apply attack type modifiers for variety (only when we have current_attack_name)
	if current_attack_name != "":
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
		# Down attacks - orta efekt (aşağı saldırı)
		"air_attack_down1", "air_attack_down2":
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
			
