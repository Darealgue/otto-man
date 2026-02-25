# player_decoy.gd - Ortaoyunu item: dodge/dash basıldığı anda bırakılan gölge kopya.
# Karagöz/Hacivat ile senkron saldırı yapabilir.
# Oyuncunun vuruş etkilerini taşır: uzun_menzil, flank_avantaji, lav_cekici, physical_damage_mult vb.

extends Node2D

const LightAttackProjectileScript = preload("res://effects/light_attack_projectile.gd")
const FireballScript = preload("res://effects/fireball_projectile.gd")
const LIFETIME := 3.0
const SHADOW_MODULATE := Color(0.14, 0.08, 0.22, 0.95)
const IDLE_COMBAT_TEXTURE = preload("res://assets/player/sprite/otto_idle_combat_border.png")
# Normal light attack textures (4-5 varyant)
const ATTACK_1_1_TEXTURE = preload("res://assets/player/sprite/otto_lightattack4.png")
const ATTACK_1_2_TEXTURE = preload("res://assets/player/sprite/otto_lightattack5_border.png")
const ATTACK_1_3_TEXTURE = preload("res://assets/player/sprite/otto_lightattack6_border.png")
const ATTACK_UP_TEXTURE = preload("res://assets/player/sprite/otto_light_up_border.png")
const ATTACK_DOWN_TEXTURE = preload("res://assets/player/sprite/otto_light_down_border.png")
# Heavy attack textures
const ATTACK_HEAVY_NEUTRAL_TEXTURE = preload("res://assets/player/sprite/otto_heavy_attack_border.png")
const ATTACK_HEAVY_UP_TEXTURE = preload("res://assets/player/sprite/otto_heavy_up_border.png")
const IDLE_COMBAT_DURATION := 1.4
const IDLE_COMBAT_FRAMES := 18
const DECOY_ATTACK_DURATION := 0.2
const PLAYER_Z_INDEX := 5
const DECOY_HITBOX_OFFSET := 55.0
const DECOY_ATTACK_RANGE := 120.0

var _timer: float = 0.0
var _anim_time: float = 0.0
var _sprite: Sprite2D
var _hurtbox: Area2D
var _decoy_hitbox: Area2D
var _attack_timer: float = 0.0
var _player: CharacterBody2D = null  # Oyuncu referansı - etki taşıma için
var _attack_effect_filter: String = "all"  # "physical_only" = Karagöz (sadece Çift Vuruş vb.), "elemental_only" = Hacivat (sadece zehir/ateş vb.)

func is_decoy() -> bool:
	return true

func take_damage(_amount: float = 0.0, _knockback_force: float = 0.0, _knockback_up_force: float = -1.0, _apply_knockback: bool = true) -> void:
	# Decoy hasar almaz (no-op).
	pass

func setup(world_pos: Vector2, flip_h: bool, player: CharacterBody2D) -> void:
	_player = player
	global_position = world_pos
	z_index = PLAYER_Z_INDEX
	add_to_group("player")
	add_to_group("player_decoy")

	# Görsel: idle combat animasyonu (gölge gibi karanlık)
	_sprite = get_node_or_null("Sprite2D")
	if _sprite:
		_sprite.texture = IDLE_COMBAT_TEXTURE
		_sprite.hframes = 18
		_sprite.vframes = 1
		_sprite.frame = 0
		_sprite.flip_h = flip_h
		_sprite.modulate = SHADOW_MODULATE

	# Hurtbox: düşman vurduğunda "isabet" sayılsın ama hasar gitmesin (take_damage no-op)
	_hurtbox = get_node_or_null("Hurtbox")
	if _hurtbox:
		_hurtbox.collision_layer = 8  # PLAYER_HURTBOX
		_hurtbox.collision_mask = 0
		_hurtbox.add_to_group("player_hurtbox")

	# DecoyHitbox: PlayerHitbox script ile - player'dan sync edilir (aynı hasar, hedef limiti, knockback)
	_decoy_hitbox = get_node_or_null("DecoyHitbox")
	if _decoy_hitbox:
		_decoy_hitbox.monitoring = false
		_decoy_hitbox.monitorable = false
		# Gölge vurduğunda player_attack_landed emit et ki Çift Vuruş, Ateşli Yumruk vb. aynı hedeflere uygulansın
		if _decoy_hitbox.has_signal("hit_enemy") and not _decoy_hitbox.hit_enemy.is_connected(_on_decoy_hitbox_hit_enemy):
			_decoy_hitbox.hit_enemy.connect(_on_decoy_hitbox_hit_enemy)

	_timer = LIFETIME

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0:
		queue_free()
		return
	# idle_combat animasyonunu döngüde oynat
	_anim_time += delta
	if _anim_time > IDLE_COMBAT_DURATION:
		_anim_time = fmod(_anim_time, IDLE_COMBAT_DURATION)
	if _sprite and _sprite.hframes >= IDLE_COMBAT_FRAMES:
		_sprite.frame = int((_anim_time / IDLE_COMBAT_DURATION) * IDLE_COMBAT_FRAMES) % IDLE_COMBAT_FRAMES

	# Decoy saldırı hitbox süresi + animasyon
	if _attack_timer > 0:
		_attack_timer -= delta
		if _attack_timer <= 0 and _decoy_hitbox:
			if _decoy_hitbox.has_method("disable"):
				_decoy_hitbox.disable()
			else:
				_decoy_hitbox.monitoring = false
				_decoy_hitbox.monitorable = false
			# Saldırı bitince idle'a dön
			_restore_idle_sprite()

func _on_decoy_hitbox_hit_enemy(enemy: Node) -> void:
	# Gölge vurduğunda oyuncunun player_attack_landed sinyalini emit et; Çift Vuruş, Ateşli Yumruk vb. aynı hedeflere uygulanır
	if not _player or not is_instance_valid(_player) or not _player.has_signal("player_attack_landed"):
		return
	if not _decoy_hitbox:
		return
	var damage: float = _decoy_hitbox.damage
	if _decoy_hitbox.has_method("get_damage_for_target"):
		damage = _decoy_hitbox.get_damage_for_target(enemy)
	elif _decoy_hitbox.has_method("get_damage"):
		damage = _decoy_hitbox.get_damage()
	var attack_type := "normal"
	var aname = _decoy_hitbox.get("current_attack_name")
	if aname != null:
		if str(aname).find("heavy") != -1:
			attack_type = "heavy"
		elif aname == "fall_attack":
			attack_type = "fall"
	# else attack_type stays "normal"
	_player.emit_signal("player_attack_landed", attack_type, damage, [enemy], global_position, _attack_effect_filter)

func _get_attack_direction() -> float:
	var nearest = _get_nearest_enemy()
	if nearest and is_instance_valid(nearest):
		var to_enemy = (nearest.global_position - global_position).normalized()
		return 1.0 if to_enemy.x >= 0 else -1.0
	return -1.0 if _sprite and _sprite.flip_h else 1.0

func _get_nearest_enemy() -> Node:
	var tree = get_tree()
	if not tree:
		return null
	var enemies = tree.get_nodes_in_group("enemies")
	var nearest: Node = null
	var nearest_dist := DECOY_ATTACK_RANGE
	for e in enemies:
		if not is_instance_valid(e) or e.get("current_behavior") == "dead":
			continue
		var d = global_position.distance_to(e.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e
	return nearest

func _restore_idle_sprite() -> void:
	if _sprite:
		_sprite.texture = IDLE_COMBAT_TEXTURE
		_sprite.hframes = 18
		_sprite.vframes = 1
		_sprite.frame = 0

func _get_attack_variant(attack_name: String) -> String:
	if attack_name.begins_with("up_") or attack_name.begins_with("attack_up") or attack_name.begins_with("air_attack_up"):
		return "up"
	if attack_name.begins_with("down_") or attack_name.begins_with("attack_down") or attack_name.begins_with("air_attack_down"):
		return "down"
	if attack_name == "fall_attack":
		return "down"  # Fall attack = aşağı vuruş gibi
	return "normal"

func _get_attack_sprite_data(attack_name: String) -> Dictionary:
	# Heavy ataklar: vuruş anı frame'leri (hazırlık değil, impact karesi)
	if attack_name == "heavy_neutral" or attack_name == "air_heavy" or attack_name == "counter_heavy":
		return {"texture": ATTACK_HEAVY_NEUTRAL_TEXTURE, "hframes": 12, "frame": 8}  # Frame 8-9 = impact
	if attack_name == "up_heavy":
		return {"texture": ATTACK_HEAVY_UP_TEXTURE, "hframes": 13, "frame": 8}  # Frame 8-9 = impact
	# down_heavy: heavy_down texture yok, light_down kullan
	if attack_name == "down_heavy":
		return {"texture": ATTACK_DOWN_TEXTURE, "hframes": 5, "frame": 3}  # Frame 2-3 = impact
	# Normal light vuruşlar: attack_name'e göre farklı animasyonlar
	if attack_name == "attack_1.1":
		return {"texture": ATTACK_1_1_TEXTURE, "hframes": 12, "frame": 4}
	if attack_name == "attack_1.2":
		return {"texture": ATTACK_1_2_TEXTURE, "hframes": 7, "frame": 3}
	if attack_name == "attack_1.3":
		return {"texture": ATTACK_1_3_TEXTURE, "hframes": 7, "frame": 3}
	if attack_name == "attack_1.4":
		return {"texture": ATTACK_1_1_TEXTURE, "hframes": 12, "frame": 4}
	# Up/down varyantları (up_light, attack_up1-3, down_light, attack_down1-2, fall_attack, air_attack_up/down)
	var variant := _get_attack_variant(attack_name)
	if variant == "up":
		return {"texture": ATTACK_UP_TEXTURE, "hframes": 9, "frame": 4}
	if variant == "down":
		return {"texture": ATTACK_DOWN_TEXTURE, "hframes": 5, "frame": 2}
	# Varsayılan normal (air_attack1-3 vb.)
	return {"texture": ATTACK_1_2_TEXTURE, "hframes": 7, "frame": 3}

func _play_attack_sprite(attack_name: String) -> void:
	var data = _get_attack_sprite_data(attack_name)
	if _sprite:
		_sprite.texture = data.texture
		_sprite.hframes = data.hframes
		_sprite.vframes = 1
		_sprite.frame = data.frame

func _apply_hitbox_variant(variant: String, dir: float) -> void:
	if not _decoy_hitbox:
		return
	match variant:
		"up":
			_decoy_hitbox.position = Vector2(dir * 70.0, -25.0)
			_decoy_hitbox.rotation = deg_to_rad(-45.0 * dir)
		"down":
			_decoy_hitbox.position = Vector2(dir * 55.0, -18.0)
			_decoy_hitbox.rotation = deg_to_rad(45.0 * dir)
		_:
			_decoy_hitbox.position = Vector2(dir * DECOY_HITBOX_OFFSET, -22)
			_decoy_hitbox.rotation = 0.0

func _is_light_attack(attack_name: String) -> bool:
	return attack_name.find("heavy") == -1 and attack_name != "fall_attack"

func _has_uzun_menzil() -> bool:
	return has_node("/root/ItemManager") and ItemManager.has_active_item("uzun_menzil")

func _has_lav_cekici() -> bool:
	return has_node("/root/ItemManager") and ItemManager.has_active_item("lav_cekici")

func _get_projectile_direction(attack_name: String) -> Vector2:
	var dir: float = _get_attack_direction()
	if attack_name == "up_light" or attack_name.begins_with("attack_up") or attack_name.begins_with("air_attack_up"):
		return Vector2(dir, -1.0).normalized()
	if attack_name == "down_light" or attack_name.begins_with("attack_down") or attack_name.begins_with("air_attack_down"):
		return Vector2(dir, 1.0).normalized()
	return Vector2(dir, 0.0)

func _spawn_light_projectile(dir: Vector2, damage: float) -> void:
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return
	var proj = Node2D.new()
	proj.set_script(LightAttackProjectileScript)
	tree.current_scene.add_child(proj)
	var spawn_offset := dir * 10.0
	proj.setup(global_position + spawn_offset, dir, damage * 0.7)  # Uzun menzil 0.7 scale

func _spawn_fireball(dir: Vector2) -> void:
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return
	var ball = Node2D.new()
	ball.set_script(FireballScript)
	tree.current_scene.add_child(ball)
	var nudge := dir * 14.0
	ball.setup(global_position + dir * 32.0 + nudge, dir)

func attack_physical(damage: float, attack_name: String = "attack_1.2") -> void:
	_attack_effect_filter = "physical_only"  # Karagöz: sadece Çift Vuruş vb. fiziksel itemler uygulansın
	if not is_inside_tree():
		return
	var dir: float = _get_attack_direction()
	var dir_vec := Vector2(dir, 0.0)
	var variant := _get_attack_variant(attack_name)
	# Uzun menzil: light attack için projectile, melee yok
	if _is_light_attack(attack_name) and _has_uzun_menzil():
		var dmg := damage
		if has_node("/root/DamageModifiers") and _player and is_instance_valid(_player):
			dmg = DamageModifiers.apply_player_modifiers(_player, damage, null, global_position, false)
		dir_vec = _get_projectile_direction(attack_name)
		_spawn_light_projectile(dir_vec, dmg)
		_play_attack_sprite(attack_name)
		_attack_timer = DECOY_ATTACK_DURATION
		return
	# Normal melee: PlayerHitbox sync (aynı hasar, hedef limiti, knockback, collision)
	if not _decoy_hitbox:
		return
	if _decoy_hitbox.has_method("sync_from_player_hitbox"):
		var player_hb = _player.get_node_or_null("Hitbox") if _player and is_instance_valid(_player) else null
		if player_hb and player_hb.has_method("sync_from_player_hitbox"):
			_decoy_hitbox.sync_from_player_hitbox(player_hb)
		else:
			_decoy_hitbox.damage = damage
			_decoy_hitbox.knockback_force = 120.0
			_decoy_hitbox.knockback_up_force = 60.0
		_decoy_hitbox.set_meta("damage_source", _player)
		_decoy_hitbox.set_meta("attacker_position_override", global_position)
		_decoy_hitbox.set_meta("element", "")
		if _decoy_hitbox.has_meta("elemental_only_no_physical"):
			_decoy_hitbox.remove_meta("elemental_only_no_physical")
		_apply_hitbox_variant(variant, dir)
		_decoy_hitbox.enable()
	else:
		# Eski sahne / fallback: sadece pozisyon + monitoring
		_apply_hitbox_variant(variant, dir)
		if _decoy_hitbox.get("damage") != null:
			_decoy_hitbox.damage = damage
		_decoy_hitbox.monitoring = true
		_decoy_hitbox.monitorable = false
	_attack_timer = DECOY_ATTACK_DURATION
	_play_attack_sprite(attack_name)
	# Lav çekici: heavy attack fireball
	if not _is_light_attack(attack_name) and _has_lav_cekici():
		if attack_name == "up_heavy":
			dir_vec = Vector2(dir, -1.0).normalized()
		elif attack_name == "down_heavy":
			dir_vec = Vector2(dir, 1.0).normalized()
		_spawn_fireball(dir_vec)

func attack_elemental(damage: float, element: String, attack_name: String = "attack_1.2") -> void:
	_attack_effect_filter = "elemental_only"  # Hacivat: sadece zehir/ateş/buz/şimşek stack'leri uygulansın
	if not is_inside_tree():
		return
	var dir: float = _get_attack_direction()
	var dir_vec := Vector2(dir, 0.0)
	var variant := _get_attack_variant(attack_name)
	# Uzun menzil: light attack için projectile (projectile fiziksel hasar, element yok)
	if _is_light_attack(attack_name) and _has_uzun_menzil():
		var dmg := damage
		if has_node("/root/DamageModifiers") and _player and is_instance_valid(_player):
			dmg = DamageModifiers.apply_player_modifiers(_player, damage, null, global_position, false)
		dir_vec = _get_projectile_direction(attack_name)
		_spawn_light_projectile(dir_vec, dmg)
		_play_attack_sprite(attack_name)
		_attack_timer = DECOY_ATTACK_DURATION
		return
	# Normal melee: PlayerHitbox sync + element meta (base_enemy uygular)
	if not _decoy_hitbox:
		return
	if _decoy_hitbox.has_method("sync_from_player_hitbox"):
		var player_hb = _player.get_node_or_null("Hitbox") if _player and is_instance_valid(_player) else null
		if player_hb and player_hb.has_method("sync_from_player_hitbox"):
			_decoy_hitbox.sync_from_player_hitbox(player_hb)
		else:
			_decoy_hitbox.damage = damage
			_decoy_hitbox.knockback_force = 120.0
			_decoy_hitbox.knockback_up_force = 60.0
		_decoy_hitbox.set_meta("damage_source", _player)
		_decoy_hitbox.set_meta("attacker_position_override", global_position)
		_decoy_hitbox.set_meta("element", element)
		_decoy_hitbox.set_meta("elemental_only_no_physical", true)  # Hacivat: sadece zehir/ateş vb., fiziksel hasar yok
		_apply_hitbox_variant(variant, dir)
		_decoy_hitbox.enable()
	else:
		# Eski sahne / fallback
		_apply_hitbox_variant(variant, dir)
		if _decoy_hitbox.get("damage") != null:
			_decoy_hitbox.damage = damage
		_decoy_hitbox.set_meta("element", element)
		_decoy_hitbox.set_meta("elemental_only_no_physical", true)
		_decoy_hitbox.monitoring = true
		_decoy_hitbox.monitorable = false
	_attack_timer = DECOY_ATTACK_DURATION
	_play_attack_sprite(attack_name)
	# Heavy attack: zehirli dev vb. gölge konumunda tetikle
	if attack_name.find("heavy") != -1 and _player and _player.has_signal("decoy_heavy_attack_impact"):
		var spawn_pos: Vector2 = global_position + Vector2(dir * 24, -12)
		_player.emit_signal("decoy_heavy_attack_impact", spawn_pos, attack_name, dir)
	# Lav çekici: heavy fire projectile
	if not _is_light_attack(attack_name) and _has_lav_cekici():
		if attack_name == "up_heavy":
			dir_vec = Vector2(dir, -1.0).normalized()
		elif attack_name == "down_heavy":
			dir_vec = Vector2(dir, 1.0).normalized()
		_spawn_fireball(dir_vec)

