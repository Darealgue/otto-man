# gulle.gd
# RARE - Darbeyle fırlayan ya da savrulan (knockback alan) düşman başka bir düşmana çarparsa ikisi de hasar
# alır ve çarpılan düşman da fırlar. Sadece havaya fırlatmalarda değil, HER knockback'te çalışır: düşman
# "hurt" durumunda, havada ya da ani bir hız sıçramasıyla savruluyorsa (hafif vuruşların yerdeki itmesi dahil)
# ve yeterince hızlıysa gülle sayılır. Yerdeki savrulmada çarpılan düşman savrulanın gittiği yönde olmalı.
# Uçan düşmanlar (sürekli havada) gülle sayılmaz. Çarpışan çift kısa süre tekrar çarpışmaz.

extends ItemEffect

const HIT_RADIUS := 65.0   # düşman gövdesi ~60 px: savrulan düşman komşunun üstünden geçerken de çarpsın
const MIN_SPEED := 140.0
const VICTIM_DAMAGE := 10.0
const SELF_DAMAGE := 5.0
const VICTIM_LAUNCH_UP := 180.0
const VICTIM_KNOCKBACK := 120.0
const COOLDOWN_MSEC := 600
const KNOCK_WINDOW_MSEC := 500        # ani hız sıçramasından sonra düşman bu süre savrulmuş sayılır
const SPIKE_FROM_SPEED := 80.0        # önceki karede bundan yavaştı...
const COOLDOWN_META := "gulle_until"
const KNOCK_META := "gulle_knock_until"
const LAST_VX_META := "gulle_last_vx"

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
	# 1) Ani yatay hız sıçraması = knockback yedi (hafif vuruşun yerdeki itmesi "hurt" durumuna girmez)
	for e in enemies:
		if not is_live_enemy(e) or e.get("velocity") == null:
			continue
		var vx: float = absf((e.velocity as Vector2).x)
		if float(e.get_meta(LAST_VX_META, 0.0)) < SPIKE_FROM_SPEED and vx >= MIN_SPEED:
			e.set_meta(KNOCK_META, now + KNOCK_WINDOW_MSEC)
		e.set_meta(LAST_VX_META, vx)
	# 2) Savrulan düşman komşuya çarptı mı?
	for ball in enemies:
		if not _is_cannonball(ball, now):
			continue
		var grounded: bool = ball.has_method("is_on_floor") and ball.is_on_floor()
		var victim: Node2D = null
		var best := HIT_RADIUS
		for other in enemies:
			if other == ball or not is_live_enemy(other) or not (other is Node2D):
				continue
			if not other.has_method("take_damage"):
				continue
			if int(other.get_meta(COOLDOWN_META, 0)) > now:
				continue
			var offset: Vector2 = (other as Node2D).global_position - ball.global_position
			# Yerde savrulan düşman, gittiği yöndeki komşuya çarpar (havadakiler komşunun üstünden de geçebilir)
			if grounded and offset.dot(ball.velocity) <= 0.0:
				continue
			var d: float = offset.length()
			if d < best:
				best = d
				victim = other as Node2D
		if victim == null:
			continue
		var mult: float = ExplosionModifiers.damage_mult()
		ball.set_meta(COOLDOWN_META, now + COOLDOWN_MSEC)
		victim.set_meta(COOLDOWN_META, now + COOLDOWN_MSEC)
		# Çarpılan düşman savrulanın gittiği yöne itilsin (take_damage: velocity.x = -direction * kuvvet)
		if victim.get("direction") != null and absf((ball.velocity as Vector2).x) > 20.0:
			victim.direction = -1 if ball.velocity.x > 0.0 else 1
		var im := get_node_or_null("/root/ItemManager")
		if im:
			im.launch_enemy(victim, VICTIM_DAMAGE * mult, VICTIM_KNOCKBACK, VICTIM_LAUNCH_UP)   # her düşman tipini havaya kaldırır
		else:
			victim.take_damage(VICTIM_DAMAGE * mult, VICTIM_KNOCKBACK, VICTIM_LAUNCH_UP, true)
		ball.take_damage(SELF_DAMAGE * mult, 0.0, 0.0, true)

func _is_cannonball(node: Node, now: int) -> bool:
	if not is_live_enemy(node):
		return false
	if node.has_method("_is_flying_enemy_runtime") and node._is_flying_enemy_runtime():
		return false
	if node.get("velocity") == null or (node.velocity as Vector2).length() < MIN_SPEED:
		return false
	if int(node.get_meta(COOLDOWN_META, 0)) > now:
		return false
	var airborne: bool = node.has_method("is_on_floor") and not node.is_on_floor()
	var hurt: bool = node.get("current_behavior") == "hurt"
	var spiked: bool = int(node.get_meta(KNOCK_META, 0)) > now
	return airborne or hurt or spiked
