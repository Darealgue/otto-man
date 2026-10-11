# duvar_carpmasi.gd
# RARE - Bir düşmanı duvara doğru savurursan (knockback yönünde 60 px içinde duvar varsa ya da savrulurken duvara
# yaslanırsa) düşman patlar: çevresindekiler ve kendisi hasar alır. Duvarın dibine sıkıştırmak ödüllenir.
# Knockback tespiti: base_enemy.last_knockback_msec (gerçek knockback). Aynı düşman 1 sn içinde tekrar patlamaz.
# Uçan düşmanlar etkilenmez.

extends ItemEffect

const _AoeBurstRingScript = preload("res://effects/aoe_burst_ring.gd")
## Gerçek knockback hızları (arena testiyle ölçüldü): ağır vuruş ~260 px/s, hafif vuruş ~90 px/s ve düşman
## sürtünmeyle birkaç karede durur (~16 px kayar). Eşik buna göre düşük tutulur; "knockback almış" şartı
## kendi başına yürüyen düşmanı eler.
const MIN_IMPACT_SPEED := 60.0
const MIN_KNOCK_SPEED := 40.0   # knockback anındaki yatay hız (hafif vuruş ~90, ağır ~230-260)
const WALL_REACH := 60.0        # savrulduğu yönde bu mesafede duvar varsa "duvara çarptı" sayılır
const KB_SEEN_META := "duvar_carpmasi_kb_seen"
const KNOCK_WINDOW_MSEC := 700
const BLAST_RADIUS := 80.0
const BLAST_DAMAGE := 12.0
const COOLDOWN_MSEC := 1000
const SPEED_META := "duvar_carpmasi_vx"
const COOLDOWN_META := "duvar_carpmasi_until"
const RING_COLOR := Color(1.0, 0.6, 0.2, 0.85)

func _init():
	item_id = "duvar_carpmasi"
	item_name = tr("item.duvar_carpmasi.name")
	description = tr("item.duvar_carpmasi.description")
	flavor_text = "Duvar da barut gibi patlar"
	rarity = ItemRarity.RARE
	category = ItemCategory.HEAVY_ATTACK
	affected_stats = ["wall_slam_blast"]

func process(_player_node: CharacterBody2D, _delta: float) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var now := Time.get_ticks_msec()
	for node in tree.get_nodes_in_group("enemies"):
		if not is_live_enemy(node):
			continue
		if not node.has_method("is_on_wall") or node.get("velocity") == null:
			continue
		if node.has_method("_is_flying_enemy_runtime") and node._is_flying_enemy_runtime():
			continue
		var prev_speed: float = absf(float(node.get_meta(SPEED_META, 0.0)))
		node.set_meta(SPEED_META, node.velocity.x)
		# Gerçekten knockback almış olmalı (kendi başına duvara yürüyen düşman patlamasın)
		var kb = node.get("last_knockback_msec")
		if kb == null or now - int(kb) > KNOCK_WINDOW_MSEC:
			continue
		if int(node.get_meta(COOLDOWN_META, 0)) > now:
			continue
		var slam := false
		# 1) Yeni knockback anında savrulduğu yönde yakında (<= WALL_REACH) duvar var mı? Gerçek ağır vuruş
		#    düşmanı yalnızca ~13 px kaydırır; fiziksel temas beklemek item'ı fiilen tetiklenmez yapıyordu.
		if int(node.get_meta(KB_SEEN_META, 0)) != int(kb):
			node.set_meta(KB_SEEN_META, int(kb))
			if absf(node.velocity.x) >= MIN_KNOCK_SPEED and _wall_ahead(node, signf(node.velocity.x)):
				slam = true
		# 2) Ya da savrulurken gerçekten duvara yaslandı
		if not slam and prev_speed >= MIN_IMPACT_SPEED and node.is_on_wall():
			slam = true
		if slam:
			node.set_meta(COOLDOWN_META, now + COOLDOWN_MSEC)
			_detonate(node.global_position, tree)

## Düşmanın savrulduğu yönde WALL_REACH içinde WORLD (duvar/zemin bloğu) var mı?
func _wall_ahead(node: Node2D, dir: float) -> bool:
	if dir == 0.0 or not node.has_method("get_world_2d"):
		return false
	var space: PhysicsDirectSpaceState2D = node.get_world_2d().direct_space_state
	var from: Vector2 = node.global_position + Vector2(0.0, -10.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(dir * WALL_REACH, 0.0))
	query.collision_mask = CollisionLayers.WORLD
	return not space.intersect_ray(query).is_empty()

func _detonate(pos: Vector2, tree: SceneTree) -> void:
	var radius: float = BLAST_RADIUS * ExplosionModifiers.radius_mult()
	var dmg: float = BLAST_DAMAGE * ExplosionModifiers.damage_mult()
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead" or not node.has_method("take_damage"):
			continue
		if pos.distance_to(node.global_position) <= radius:
			node.take_damage(dmg, 100.0, 40.0, true)
	if tree.current_scene:
		var ring := Node2D.new()
		ring.set_script(_AoeBurstRingScript)
		tree.current_scene.add_child(ring)
		ring.setup(pos, radius, RING_COLOR)
	ExplosionModifiers.announce(pos, radius)
