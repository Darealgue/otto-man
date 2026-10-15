# gulle.gd
# RARE - Darbeyle fırlayan ya da savrulan düşman başka bir düşmana çarparsa ikisi de hasar alır ve çarpılan düşman
# da fırlar. HER knockback'te çalışır (havaya fırlatma, yerdeki savrulma, patlama itmesi) ama SADECE gerçekten
# knockback almış düşmanlar sayılır: base_enemy.take_damage `last_knockback_msec`i işaretler. Kendi kendine
# koşan/zıplayan düşmanlar (peşinden koşup aşağı atlayan askerler) knockback almadığı için gülle OLMAZ.
# Yerdeki savrulmada çarpılan düşman savrulanın gittiği yönde olmalı.
# Uçan düşmanlar (sürekli havada) gülle sayılmaz. Çarpışan çift kısa süre tekrar çarpışmaz.

extends ItemEffect

const HIT_RADIUS := 65.0   # düşman gövdesi ~60 px: savrulan düşman komşunun üstünden geçerken de çarpsın
const MIN_SPEED := 140.0
const VICTIM_DAMAGE := 10.0
const SELF_DAMAGE := 5.0
const VICTIM_LAUNCH_UP := 180.0
const VICTIM_KNOCKBACK := 120.0
const COOLDOWN_MSEC := 600
const KNOCK_WINDOW_MSEC := 900        # knockback'ten sonra düşman bu süre savrulmuş (gülle) sayılır
const COOLDOWN_META := "gulle_until"

func _init():
	item_id = "gulle"
	item_name = tr("item.gulle.name")
	description = tr("item.gulle.description")
	flavor_text = "Düşman da gülle olur"
	category = ItemCategory.HEAVY_ATTACK
	affected_stats = ["enemy_cannonball"]
func process(_player_node: CharacterBody2D, _delta: float) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var now := Time.get_ticks_msec()
	var enemies: Array = tree.get_nodes_in_group("enemies")
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

## Gülle: gerçekten knockback almış (son KNOCK_WINDOW_MSEC içinde) ve yeterince hızlı düşman.
func _is_cannonball(node: Node, now: int) -> bool:
	if not is_live_enemy(node):
		return false
	if node.has_method("_is_flying_enemy_runtime") and node._is_flying_enemy_runtime():
		return false
	if node.get("velocity") == null or (node.velocity as Vector2).length() < MIN_SPEED:
		return false
	if int(node.get_meta(COOLDOWN_META, 0)) > now:
		return false
	var kb = node.get("last_knockback_msec")
	return kb != null and now - int(kb) <= KNOCK_WINDOW_MSEC