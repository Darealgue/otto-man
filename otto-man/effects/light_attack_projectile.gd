# Uzun Menzil itemi: light attack ile fırlayan projectile (yatay / 45° yukarı / 45° aşağı)
# Mermi TÜRLERİ bu script'ten türer (bkz. cannon_projectile.gd = Top, player_fire_bomb_projectile.gd
# = Ateş Bombası); ItemManager.spawn_upgraded_projectile(kind) seçer, tüm yükseltmeler (Sürü Oku,
# Yansıyan Ok, Ruh Mermisi, element...) türden bağımsız aynı alanlar üzerinden çalışır.
# Opsiyonel özellikler (item'lar setup() sonrası set eder):
#   bounce_remaining  - Yansıyan Ok: ilk çarpışta bounce_range içindeki 2. düşmana sekme
#   element           - Rüzgârın Nişanı: "poison"/"fire"/"frost" ise çarpışta ilgili stack uygulanır
#   echo              - Yankı Oku: çarpışma noktasında 1sn sonra %60 hasarlık ikinci patlama
#   unlimited_range / crit_range / crit_mult - Kartal Bakışı: menzil sınırı kalkar, uzak mesafe kritik
#   knockback_force / knockback_up_force - Ağır Mermi: >0 ise isabette fırlatma da uygulanır
#   homing_strength   - Peşine Düşen: >0 ise en yakın düşmana doğru saniyede bu oranda döner
#   soul_chain        - Ruh Mermisi: isabet öldürürse en yakın başka düşmana yönelip devam eder
extends Node2D

const SPEED := 1100.0
const MAX_DISTANCE := 250.0  # Yarı mesafe (önceki 500)
const HIT_RADIUS := 56.0
const BALL_RADIUS := 10.0
const PROJECTILE_COLOR := Color(0.9, 0.85, 0.5)
const BOUNCE_RANGE := 140.0
const CHAIN_RANGE := 200.0
const HOMING_RANGE := 220.0
const ECHO_DELAY := 1.0
const ECHO_DAMAGE_RATIO := 0.6
const ECHO_RADIUS := 60.0

var _direction: Vector2 = Vector2.RIGHT
var _traveled: float = 0.0
var _damage: float = 15.0

# Türler bunları setup() içinde değiştirir (Ok varsayılanları const'larla aynı).
var _speed: float = SPEED
var _hit_radius: float = HIT_RADIUS
var _ball_radius: float = BALL_RADIUS
var _ball_color: Color = PROJECTILE_COLOR
# Sekme/zincir sonrası az önce vurulan düşmana hemen tekrar çarpmamak için.
var _recent_hit_id: int = 0

# Uzun Menzil/Ok Yağmuru'nun kendi çağrılarını bozmamak için varsayılan -1 (item set etmezse kapalı)
var max_distance: float = MAX_DISTANCE
var bounce_remaining: int = 0
var element: String = ""
var echo: bool = false
var unlimited_range: bool = false
var crit_range: float = 300.0
var crit_mult: float = 1.75
var knockback_force: float = 0.0
var knockback_up_force: float = 0.0
var homing_strength: float = 0.0
var soul_chain: bool = false

func setup(origin: Vector2, direction: Vector2, damage: float) -> void:
	global_position = origin
	_direction = direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
	rotation = _direction.angle()  # Çıkış açısına uygun ilerle (hitbox doğrultusu)
	_damage = max(1.0, damage)
	# z_index hiç ayarlanmıyordu (varsayılan 0) — zindan dekorları 1-3, düşmanlar 4, oyuncu
	# 5 kullanıyor, bu yüzden bu projectile hepsinin ARKASINDA çiziliyordu. Tuzak/düşman
	# projectile'larının zaten kullandığı değerle (bkz. arrow_projectile.tscn, z_index=10,
	# z_as_relative=false) eşleştirdik; current_scene'e eklendiği için ata z_index'inden
	# bağımsız, mutlak bir değer olması gerekiyor.
	z_as_relative = false
	z_index = 10

func _physics_process(delta: float) -> void:
	if homing_strength > 0.0:
		var homing_target := _find_nearest_enemy(null, global_position, HOMING_RANGE)
		if homing_target:
			var desired: Vector2 = (homing_target.global_position - global_position).normalized()
			_direction = _direction.lerp(desired, clampf(homing_strength * delta, 0.0, 1.0)).normalized()
			rotation = _direction.angle()
	var move := _direction * _speed * delta
	_traveled += move.length()
	if not unlimited_range and _traveled >= max_distance:
		queue_free()
		return
	global_position += move
	var world_pos := global_position
	var space = get_world_2d().direct_space_state
	var params = PhysicsPointQueryParameters2D.new()
	params.position = world_pos
	params.collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM
	params.collide_with_bodies = true
	params.collide_with_areas = false
	if space.intersect_point(params).size() > 0:
		queue_free()
		return
	if _check_enemy_hits(world_pos):
		return
	queue_redraw()

## Menzildeki ilk canlı düşmana _on_hit uygular. Sekme/zincirle yeni hedefe yönelen mermi,
## az önce vurduğu düşmandan uzaklaşana kadar onu tekrar vurmaz (eskiden birkaç kare içinde
## aynı düşmana tekrar çarpabiliyordu). Dönüş: bu karede bir isabet işlendi mi.
func _check_enemy_hits(world_pos: Vector2) -> bool:
	var tree = get_tree()
	if not tree:
		return false
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		var d := world_pos.distance_to(node.global_position)
		if node.get_instance_id() == _recent_hit_id:
			if d > _hit_radius * 1.5:
				_recent_hit_id = 0
			else:
				continue
		if d <= _hit_radius:
			_on_hit(node, world_pos)
			return true
	return false

func _on_hit(node: Node, world_pos: Vector2) -> void:
	var killed_by_this_hit := false
	var proj_tree := get_tree()
	var proj_player = proj_tree.get_first_node_in_group("player") if proj_tree else null
	if node.has_method("take_damage"):
		var dmg := _damage
		if unlimited_range and _traveled > crit_range:
			dmg *= crit_mult
		# Flank/Stealth arkadan vuruş: melee player_hitbox.gd'nin get_damage_for_target()
		# üzerinden geçtiği DamageModifiers zincirinden mermiler bypass ediyordu (kullanıcı
		# geri bildirimi, 2026-09-30) — gizlice yaklaşıp okla arkadan vurmak da aynı bonusu
		# almalı.
		var dm = get_node_or_null("/root/DamageModifiers")
		if dm and dm.has_method("apply_player_modifiers") and proj_player:
			proj_player.set("_last_attack_name_for_modifiers", "")
			dmg = dm.apply_player_modifiers(proj_player, dmg, node, global_position, false)
		if knockback_force > 0.0:
			# Ağır Mermi: fırlatma da uygulanır (hurt animasyonu tetiklenir)
			node.take_damage(dmg, knockback_force, knockback_up_force, true)
		else:
			# Varsayılan: sadece hasar; knockback ve hurt animasyonu yok
			node.take_damage(dmg, 0.0, 0.0, false)
		killed_by_this_hit = node.get("current_behavior") == "dead"
		# player_attack_landed: Uzun Menzil/Ok Yağmuru bir light attack'ı TAMAMEN
		# mermiye çevirdiğinde (bkz. attack_state.gd use_ranged_only), melee hitbox
		# hiç ateşlenmiyor ve bu sinyal hiç yayınlanmıyordu — zehirli_tirnak/atesli_yumruk/
		# buzlu_kilic/simsek_parmagi (element kaynakları), cevher_dili, genis_darbe,
		# koruk, cuppe_degil_zirh gibi "soyut duruma bakan" item'lar ranged'de tamamen
		# ölü kalıyordu (kullanıcı geri bildirimi, 2026-09-30). attack_type="ranged"
		# (düz "normal" değil) kasıtlı: kesme_yayi/sirt_darbesi/yere_cakis (combo
		# pozisyonuna bağlı) ve daire_darbesi (attack_type=="heavy" ister) ve
		# cift_vurus (zaten spawn_upgraded_projectile'da volley ile ayrı çözüldü,
		# tekrar tetiklenmemeli) kendi `!= "normal"` filtreleriyle bunu otomatik
		# eliyor; sadece attack_type'ı hiç kontrol etmeyen ya da özellikle "ranged"i
		# de kabul eden item'lar buna tepki veriyor.
		if proj_player and proj_player.has_signal("player_attack_landed"):
			proj_player.emit_signal("player_attack_landed", "ranged", dmg, [node], world_pos, "all")
	_apply_element(node)
	if echo:
		_spawn_echo(world_pos)
	_recent_hit_id = node.get_instance_id()
	if soul_chain and killed_by_this_hit:
		var chain_target := _find_nearest_enemy(node, world_pos, CHAIN_RANGE)
		if chain_target:
			_traveled = 0.0
			_direction = (chain_target.global_position - world_pos).normalized()
			rotation = _direction.angle()
			return
	if bounce_remaining > 0:
		var next_target := _find_nearest_enemy(node, world_pos, BOUNCE_RANGE)
		if next_target:
			bounce_remaining -= 1
			_traveled = 0.0
			_direction = (next_target.global_position - world_pos).normalized()
			rotation = _direction.angle()
			return
	queue_free()

func _apply_element(node: Node) -> void:
	if element == "" or not is_instance_valid(node):
		return
	match element:
		"poison":
			if node.has_method("add_poison_stack"):
				node.add_poison_stack(5, 1.0, 2.0)
		"fire":
			if node.has_method("add_burn_stack"):
				node.add_burn_stack()
		"frost":
			if node.has_method("add_frost_stack"):
				node.add_frost_stack(1)

## Yansıyan Ok (bounce), Ruh Mermisi (soul_chain) ve homing için paylaşılan
## "en yakın canlı düşman" arayıcısı. exclude null olabilir (homing'de kendi
## dışında hariç tutulacak bir düşman yok).
func _find_nearest_enemy(exclude: Node, from_pos: Vector2, max_range: float) -> Node:
	var tree = get_tree()
	if not tree:
		return null
	var best: Node = null
	var best_dist := max_range
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node == exclude:
			continue
		if node.get("current_behavior") == "dead":
			continue
		var d := from_pos.distance_to(node.global_position)
		if d <= best_dist:
			best_dist = d
			best = node
	return best

func _spawn_echo(world_pos: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if not tree or not tree.current_scene:
		return
	var timer := get_tree().create_timer(ECHO_DELAY)
	var echo_damage := _damage * ECHO_DAMAGE_RATIO
	var scene_root: Node = tree.current_scene
	timer.timeout.connect(func():
		if not is_instance_valid(scene_root):
			return
		for node in scene_root.get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(node) or node.get("current_behavior") == "dead":
				continue
			if world_pos.distance_to(node.global_position) <= ECHO_RADIUS:
				if node.has_method("take_damage"):
					node.take_damage(echo_damage, 0.0, 0.0, false)
	)

func _draw() -> void:
	draw_circle(Vector2.ZERO, _ball_radius, _ball_color)
