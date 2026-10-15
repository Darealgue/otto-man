# kazik_darbesi.gd
# RARE - Havada dövülen (fırlatılmış) düşmana aşağı saldırı (düşme vuruşu) ile vurursan düşman yere
# çakılır; indiği yerde alan hasarı olur ve aktif elementlerini taşır. Uçan düşmanlar çakılamaz.
# Havaya Fırlatma hattının barut payoff'u: Zıplatan Yumruk, Bulaşıcı Darbe, Zehir Havuzu ile birleşir.

extends ItemEffect

const _AoeBurstRingScript = preload("res://effects/aoe_burst_ring.gd")
const SLAM_SPEED := 1100.0
const SLAM_WINDOW_FRAMES := 150   # ~2.5 sn (fizik karesi: başsız/yavaş çalışmada gerçek saat penceresi erken doluyordu)
const BLAST_RADIUS := 110.0
const BLAST_DAMAGE_RATIO := 1.5   # düşme vuruşu hasarının katı (eskiden 0.8: görünmeyecek kadar zayıftı)
const BLAST_MIN_DAMAGE := 15.0
const BLAST_KNOCKBACK := 200.0
const BLAST_LAUNCH_UP := 150.0   # yakındakiler havaya kalkar: Gülle/hava kombolarına köprü
const SLAM_META := "kazik_darbesi_slam"
const RING_COLOR := Color(1.0, 0.55, 0.2, 0.85)

func _init():
	item_id = "kazik_darbesi"
	item_name = tr("item.kazik_darbesi.name")
	description = tr("item.kazik_darbesi.description")
	flavor_text = "Kazık gibi çak"
	category = ItemCategory.FALL_ATTACK
	affected_stats = ["air_slam"]

var _player: CharacterBody2D = null

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null

## Havada AŞAĞI + SALDIR = AirAttackDown (hafif aşağı vuruş, attack_type 'normal'); AŞAĞI + ZIPLA = FallAttack
## ('fall'). İkisi de çakar: oyuncu hangisini kullanırsa kullansın item çalışır.
func _is_down_attack_hit(attack_type: String) -> bool:
	if attack_type == "fall":
		return true
	if attack_type != "normal" or not is_instance_valid(_player):
		return false
	var sm = _player.get("state_machine")
	return sm != null and sm.get("current_state") != null and sm.current_state.name == "AirAttackDown"

func _on_player_attack_landed(attack_type: String, damage: float, targets: Array, _position: Vector2, _effect_filter: String = "all") -> void:
	if not _is_down_attack_hit(attack_type):
		return
	var now := Engine.get_physics_frames()
	for target in targets:
		var enemy := resolve_enemy_target(target)
		if enemy == null or not enemy.has_method("is_on_floor") or enemy.is_on_floor():
			continue  # havada değil: normal düşme vuruşu
		if enemy.has_method("_is_flying_enemy_runtime") and enemy._is_flying_enemy_runtime():
			continue
		if enemy.get("velocity") == null:
			continue
		enemy.velocity.y = SLAM_SPEED
		if enemy.get("air_float_timer") != null:
			enemy.air_float_timer = 0.0
		enemy.set_meta(SLAM_META, {"until": now + SLAM_WINDOW_FRAMES, "damage": damage})

## Çakma HER KARE uygulanır (düşman yere inene kadar): düşme vuruşunun düşmana kendi yukarı knockback'i de
## (ATTACK_UP_FORCE) vuruş anında uygulanır ve hangisinin sonra geleceği sinyal sırasına bağlı; tek seferlik
## hız atamak bazen ezilip düşmanı YUKARI uçuruyordu.
func process(_player_node: CharacterBody2D, _delta: float) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var now := Engine.get_physics_frames()
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or not node.has_meta(SLAM_META):
			continue
		var info: Dictionary = node.get_meta(SLAM_META)
		if node.get("current_behavior") == "dead" or int(info["until"]) < now:
			node.remove_meta(SLAM_META)
			continue
		if node.has_method("is_on_floor") and node.is_on_floor():
			node.remove_meta(SLAM_META)
			_detonate(node.global_position, float(info["damage"]), tree)
		elif node.get("velocity") != null:
			node.velocity.y = maxf(node.velocity.y, SLAM_SPEED)
			if node.get("air_float_timer") != null:
				node.air_float_timer = 0.0

func _detonate(pos: Vector2, fall_damage: float, tree: SceneTree) -> void:
	var im := get_node_or_null("/root/ItemManager")
	var radius: float = BLAST_RADIUS * ExplosionModifiers.radius_mult()
	var dmg: float = maxf(fall_damage * BLAST_DAMAGE_RATIO, BLAST_MIN_DAMAGE) * ExplosionModifiers.damage_mult()
	var elements: Array = im.get_active_elements() if im else []
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead" or not node.has_method("take_damage"):
			continue
		if pos.distance_to(node.global_position) > radius:
			continue
		if im:
			im.launch_enemy(node, dmg, BLAST_KNOCKBACK, BLAST_LAUNCH_UP)
		else:
			node.take_damage(dmg, BLAST_KNOCKBACK, BLAST_LAUNCH_UP, true)
		for element in elements:
			im.apply_element_to_enemy(node, element)
	if tree.current_scene:
		var ring := Node2D.new()
		ring.set_script(_AoeBurstRingScript)
		tree.current_scene.add_child(ring)
		ring.setup(pos, radius, RING_COLOR)
	ExplosionModifiers.announce(pos, radius)
