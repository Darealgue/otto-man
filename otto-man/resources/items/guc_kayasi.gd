# guc_kayasi.gd  (Kor Patlatma)
# UNCOMMON - Yanan düşmana ağır vuruş, üzerindeki yanma katmanlarını tüketip kalan yanma hasarının
# 1.5 katını anında vurur. Eski "ağır vuruş +%30" düz stat'ı bu fiille değiştirildi (id aynı kaldı).
# Ateşli Yumruk / Lav Çekici / Koruk gibi yakan item'larla birleşir. Gölgenin ağır vuruşu da tüketir.

extends ItemEffect

const DAMAGE_PER_TICK := 1.0
const PAYOFF_MULT := 1.5
const RING_COLOR := Color(1.0, 0.5, 0.15, 0.8)
const _AoeBurstRingScript = preload("res://effects/aoe_burst_ring.gd")

func _init():
	item_id = "guc_kayasi"
	item_name = tr("item.guc_kayasi.name")
	description = tr("item.guc_kayasi.description")
	flavor_text = "Kor, taşı da patlatır"
	category = ItemCategory.HEAVY_ATTACK
	affected_stats = ["heavy_burn_payoff"]

func _on_player_attack_landed(attack_type: String, _damage: float, targets: Array, _position: Vector2, _effect_filter: String = "all") -> void:
	if attack_type != "heavy":
		return
	var im := get_node_or_null("/root/ItemManager")
	for target in targets:
		var enemy := resolve_enemy_target(target)
		if enemy == null or enemy.get("burn_remaining_ticks") == null:
			continue
		var ticks: int = int(enemy.burn_remaining_ticks)
		if ticks <= 0:
			continue
		enemy.burn_remaining_ticks = 0
		enemy.set("burn_tick_timer", 0.0)
		enemy.take_damage(float(ticks) * DAMAGE_PER_TICK * PAYOFF_MULT, 0.0, 0.0, true)
		if im:
			im.spawn_element_hit_flash(enemy, "fire")
		var tree := get_tree()
		if tree and tree.current_scene:
			var ring := Node2D.new()
			ring.set_script(_AoeBurstRingScript)
			tree.current_scene.add_child(ring)
			ring.setup(enemy.global_position, 45.0, RING_COLOR)
