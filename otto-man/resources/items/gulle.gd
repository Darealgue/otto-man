# gulle.gd
# RARE - Havaya fırlatılmış (hızla uçan) düşman başka bir düşmana çarparsa ikisi de hasar alır ve çarpılan
# düşman da havaya fırlar. Kalabalıkta bilardo etkisi; Toplu Kaldırma ile bütün grup uçuşur.
# Uçan düşmanlar (sürekli havada) gülle sayılmaz. Çarpışan çift kısa süre tekrar çarpışmaz.

extends ItemEffect

const HIT_RADIUS := 65.0   # düşman gövdesi ~60 px: fırlatılan düşman komşunun üstünden geçerken de çarpsın
const MIN_SPEED := 180.0
const VICTIM_DAMAGE := 10.0
const SELF_DAMAGE := 5.0
const VICTIM_LAUNCH_UP := 180.0
const VICTIM_KNOCKBACK := 120.0
const COOLDOWN_MSEC := 600
const COOLDOWN_META := "gulle_until"

func _init():
	item_id = "gulle"
	item_name = tr("item.gulle.name")
	description = tr("item.gulle.description")
	flavor_text = "Düşman da gülle olur"
	rarity = ItemRarity.RARE
	category = ItemCategory.HEAVY_ATTACK
	affected_stats = ["enemy_cannonball"]

func process(_player_node: CharacterBody2D, _delta: float) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var now := Time.get_ticks_msec()
	var enemies: Array = tree.get_nodes_in_group("enemies")
	for ball in enemies:
		if not _is_cannonball(ball, now):
			continue
		var victim: Node2D = null
		var best := HIT_RADIUS
		for other in enemies:
			if other == ball or not is_live_enemy(other) or not (other is Node2D):
				continue
			if not other.has_method("take_damage"):
				continue
			if int(other.get_meta(COOLDOWN_META, 0)) > now:
				continue
			var d: float = ball.global_position.distance_to((other as Node2D).global_position)
			if d < best:
				best = d
				victim = other as Node2D
		if victim == null:
			continue
		var mult: float = ExplosionModifiers.damage_mult()
		ball.set_meta(COOLDOWN_META, now + COOLDOWN_MSEC)
		victim.set_meta(COOLDOWN_META, now + COOLDOWN_MSEC)
		victim.take_damage(VICTIM_DAMAGE * mult, VICTIM_KNOCKBACK, VICTIM_LAUNCH_UP, true)
		ball.take_damage(SELF_DAMAGE * mult, 0.0, 0.0, true)

func _is_cannonball(node: Node, now: int) -> bool:
	if not is_live_enemy(node):
		return false
	if not node.has_method("is_on_floor") or node.is_on_floor():
		return false
	if node.has_method("_is_flying_enemy_runtime") and node._is_flying_enemy_runtime():
		return false
	if node.get("velocity") == null or (node.velocity as Vector2).length() < MIN_SPEED:
		return false
	return int(node.get_meta(COOLDOWN_META, 0)) <= now
