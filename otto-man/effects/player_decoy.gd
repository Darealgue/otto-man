# player_decoy.gd - Gölge kopya: Ortaoyunu, Gölge Hasadı, Kukla Oyunu, Gölge Dönüşü, Gölge Sahnesi, Hayalet Adım.
# Varsayılan davranış (item gerektirmez): sabit durur, düşman agrosunu çeker, oyuncunun
# saldırılarını ve mermilerini en yakın düşmana doğru (sadece sol/sağ) taklit eder.
# Taklit hasarı oyuncunun vuruşunun ItemManager.get_shadow_damage_ratio() kadarıdır.
# Oyuncunun vuruş etkilerini taşır: uzun_menzil, flank_avantaji, lav_cekici, physical_damage_mult vb.

extends Node2D

const FireballScript = preload("res://effects/fireball_projectile.gd")
const LIFETIME := 4.0  # Varsayılan gölge ömrü (saniye); kaynak item'lar lifetime_override ile 3-5 arası verir
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
## Saldırı yönü için en yakın düşmanı aradığımız yatay/dikey tarama menzili. Gölge uzaktaki bir
## düşmana bakıp ona doğru vurabilsin diye hitbox menzilinden (~105px) çok daha geniş.
const DECOY_DIRECTION_SCAN_RANGE := 450.0

var _timer: float = 0.0
var _total_lifetime: float = 0.0
const EXPIRE_EVENT_MIN_LIFETIME := 1.0   # Hayalet Adım gibi çok kısa gölgeler "söndü" olayı yaymaz
var _anim_time: float = 0.0
var _sprite: Sprite2D
var _hurtbox: Area2D
var _decoy_hitbox: Area2D
var _attack_timer: float = 0.0
var _player: CharacterBody2D = null  # Oyuncu referansı - etki taşıma için
var lifetime_override: float = -1.0  # >0 ise LIFETIME yerine bu kullanılır (Hayalet Adım: 0.4s)

func is_decoy() -> bool:
	return true

func take_damage(_amount: float = 0.0, _knockback_force: float = 0.0, _knockback_up_force: float = -1.0, _apply_knockback: bool = true) -> void:
	# Decoy hasar almaz (no-op).
	pass

## Bir düşman saldırısı gölgenin hurtbox'ına değdiğinde EnemyHitbox çağırır (Zehirli Yem vb. dinler).
func on_enemy_hit(enemy_hitbox: Node) -> void:
	_notify_items("_on_decoy_hit_by_enemy", [global_position, enemy_hitbox])

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

	# Oyuncunun her saldırısını taklit et (item gerektirmez). Gölge silinince bağlantı kendiliğinden kopar.
	if is_instance_valid(_player) and _player.has_signal("player_attack_performed"):
		if not _player.is_connected("player_attack_performed", _on_player_attack_performed):
			_player.connect("player_attack_performed", _on_player_attack_performed)

	_timer = (LIFETIME if lifetime_override <= 0.0 else lifetime_override) * _shadow_lifetime_mult()
	_total_lifetime = _timer

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0:
		if _total_lifetime >= EXPIRE_EVENT_MIN_LIFETIME:
			_notify_items("_on_decoy_expired", [global_position, _total_lifetime])
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

## Aktif item'lara gölge olayı bildirir (Gölge Bağı, Sönen Gölge vb. dinler).
func _notify_items(method: String, args: Array) -> void:
	var im := get_node_or_null("/root/ItemManager")
	if im and im.has_method("notify_item_event"):
		im.notify_item_event(method, args)

func _shadow_damage_ratio() -> float:
	var im := get_node_or_null("/root/ItemManager")
	if im and im.has_method("get_shadow_damage_ratio"):
		return im.get_shadow_damage_ratio()
	return 0.5

func _shadow_lifetime_mult() -> float:
	var im := get_node_or_null("/root/ItemManager")
	if im and im.has_method("get_shadow_lifetime_mult"):
		return im.get_shadow_lifetime_mult()
	return 1.0

func _on_decoy_hitbox_hit_enemy(enemy: Node) -> void:
	_notify_items("_on_decoy_hit_enemy", [enemy, global_position])
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
	# Gölge vuruşu oyuncu vuruşu SAYILIR ("all"): kombo/sayaç item'ları, element item'ları ve
	# ikincil etki item'ları gölgenin isabetini de görür. ItemManager.shadow_hit_origin/facing
	# yayın süresince dolu kalır; ikincil etkiyi oyuncunun değil gölgenin konumunda çıkaran ve
	# kaynak harcatan/kazandıran item'lar buna bakar (bkz. ItemManager.is_shadow_hit()).
	var im := get_node_or_null("/root/ItemManager")
	if im:
		im.shadow_hit_origin = global_position
		im.shadow_hit_facing = -1.0 if _sprite and _sprite.flip_h else 1.0
	_player.emit_signal("player_attack_landed", attack_type, damage, [enemy], global_position, "all")
	if im:
		im.shadow_hit_origin = null

## Sadece sol/sağ: en yakın düşmanın tarafına bakar; hiç düşman yoksa gölgenin mevcut yönünde kalır.
func _get_attack_direction() -> float:
	var nearest = _get_nearest_enemy()
	if nearest and is_instance_valid(nearest):
		return 1.0 if nearest.global_position.x >= global_position.x else -1.0
	return -1.0 if _sprite and _sprite.flip_h else 1.0

func _get_nearest_enemy() -> Node:
	var tree = get_tree()
	if not tree:
		return null
	var enemies = tree.get_nodes_in_group("enemies")
	var nearest: Node = null
	var nearest_dist := DECOY_DIRECTION_SCAN_RANGE
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
		_sprite.flip_h = _get_attack_direction() < 0.0
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

func _has_active_item(item_id: String) -> bool:
	var im := get_node_or_null("/root/ItemManager")
	return im != null and im.has_active_item(item_id)

func _has_uzun_menzil() -> bool:
	return _has_active_item("uzun_menzil")

func _has_lav_cekici() -> bool:
	return _has_active_item("lav_cekici")

func _spawn_fireball(dir: Vector2) -> void:
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return
	var ball = Node2D.new()
	ball.set_script(FireballScript)
	tree.current_scene.add_child(ball)
	var nudge := dir * 14.0
	ball.setup(global_position + dir * 32.0 + nudge, dir)

## Oyuncu bir saldırı yaptığında (vursa da vurmasa da) gölge de aynısını yapar.
func _on_player_attack_performed(attack_name: String, damage: float) -> void:
	# Fall attack: gölge melee yapmasın, sadece fall-attack efektleri (zehir bulutu vb.) taklit edilir
	# (decoy_fall_attack_impacted, fall_attack_state.gd).
	if attack_name == "fall_attack":
		return
	mimic_attack(damage, attack_name)

## Oyuncunun mermisini (Uzun Menzil / Ok Yağmuru ve yükseltmeleri) aynı türde, gölgenin konumundan
## en yakın düşmana doğru tekrarlar. ItemManager.spawn_upgraded_projectile çağırır.
func mimic_projectile(direction: Vector2, damage: float, max_distance_override: float, kind: String, double_strike: bool) -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if not tree or not tree.current_scene:
		return
	var im := get_node_or_null("/root/ItemManager")
	if not im or not im.has_method("spawn_upgraded_projectile"):
		return
	var dir_x: float = _get_attack_direction()
	var dir := Vector2(dir_x * maxf(absf(direction.x), 0.05), direction.y).normalized()
	var origin := global_position + Vector2(dir.x * 20.0, -22.0)
	im.spawn_upgraded_projectile(tree.current_scene, origin, dir, damage * _shadow_damage_ratio(), max_distance_override, kind, double_strike, false)

## Oyuncunun saldırısını gölgenin konumunda taklit eder: fiziksel hasar (oyuncunun hasarının
## get_shadow_damage_ratio() kadarı) + oyuncunun element/on-hit item'ları (isabet sinyali üzerinden).
func mimic_attack(damage: float, attack_name: String = "attack_1.2") -> void:
	if not is_inside_tree():
		return
	var dir: float = _get_attack_direction()
	var variant := _get_attack_variant(attack_name)
	# Uzun Menzil: light attack melee açmaz; mermi ItemManager.spawn_upgraded_projectile üzerinden
	# gölgeye de yansıtılır (mimic_projectile), burada sadece animasyon oynar.
	if _is_light_attack(attack_name) and _has_uzun_menzil():
		_play_attack_sprite(attack_name)
		_attack_timer = DECOY_ATTACK_DURATION
		return
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
		_decoy_hitbox.damage *= _shadow_damage_ratio()
		_decoy_hitbox.set_meta("damage_source", _player)
		_decoy_hitbox.set_meta("attacker_position_override", global_position)
		_apply_hitbox_variant(variant, dir)
		_decoy_hitbox.enable()
	else:
		# Eski sahne / fallback: sadece pozisyon + monitoring
		_apply_hitbox_variant(variant, dir)
		if _decoy_hitbox.get("damage") != null:
			_decoy_hitbox.damage = damage * _shadow_damage_ratio()
		_decoy_hitbox.monitoring = true
		_decoy_hitbox.monitorable = false
	_attack_timer = DECOY_ATTACK_DURATION
	_play_attack_sprite(attack_name)
	var dir_vec := Vector2(dir, 0.0)
	if not _is_light_attack(attack_name):
		# Heavy attack: zehirli dev vb. gölge konumunda tetikle
		if _player and is_instance_valid(_player) and _player.has_signal("decoy_heavy_attack_impact"):
			var spawn_pos: Vector2 = global_position + Vector2(dir * 24, -12)
			_player.emit_signal("decoy_heavy_attack_impact", spawn_pos, attack_name, dir)
		# Lav çekici: heavy fire projectile
		if _has_lav_cekici():
			if attack_name == "up_heavy":
				dir_vec = Vector2(dir, -1.0).normalized()
			elif attack_name == "down_heavy":
				dir_vec = Vector2(dir, 1.0).normalized()
			_spawn_fireball(dir_vec)
