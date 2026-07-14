# RARE - Ağır saldırı vuruşunda tuş hâlâ basılıysa ve stamina varsa, 1 hücre yakılıp
# vuruş noktasında ek "overcharge" alan hasarı patlar (isteğe bağlı — tuşu bırakırsan tetiklenmez).
extends ItemEffect

const OVERCHARGE_RADIUS := 90.0
const OVERCHARGE_DAMAGE_MULT := 1.0  # Ana hasarın 1 katı kadar ek alan hasarı (~×2 toplam his)

var _player: CharacterBody2D = null

func _init():
	item_id = "yikim_muhru"
	item_name = "Yıkım Mührü"
	description = "Ağır saldırı sırasında tuşu basılı tutup 1 stamina hücresi yakarsan ek patlama olur"
	flavor_text = "Fazla güç, fazla bedel ister"
	rarity = ItemRarity.RARE
	category = ItemCategory.STAMINA
	affected_stats = ["heavy_overcharge"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	print("[Yıkım Mührü] ✅ Ağır saldırı overcharge edilebilir")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null
	print("[Yıkım Mührü] ❌ Kaldırıldı")

func _on_heavy_attack_impact(_attack_name: String) -> void:
	if not is_instance_valid(_player):
		return
	if not Input.is_action_pressed("attack_heavy"):
		return
	var stamina_bar: Node = _player.get_tree().get_first_node_in_group("stamina_bar")
	var consumed := false
	if stamina_bar and stamina_bar.has_method("use_charge"):
		consumed = stamina_bar.use_charge()
	if not consumed:
		consumed = _try_kan_bedeli_fallback()
	if not consumed:
		return
	var center: Vector2 = _player.hitbox.global_position if _player.hitbox else _player.global_position
	var base_damage: float = _player.hitbox.damage if _player.hitbox else 15.0
	var bonus_damage := base_damage * OVERCHARGE_DAMAGE_MULT
	var tree = _player.get_tree()
	if not tree:
		return
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		if center.distance_to(node.global_position) <= OVERCHARGE_RADIUS and node.has_method("take_damage"):
			node.take_damage(bonus_damage, 100.0, 40.0, true)

## Kan Bedeli aktifse stamina yerine can harcayarak devam et
func _try_kan_bedeli_fallback() -> bool:
	var im = get_node_or_null("/root/ItemManager")
	if not im or not im.has_active_item("kan_bedeli"):
		return false
	var stats = get_node_or_null("/root/PlayerStats")
	if not stats:
		return false
	var cost = max(1.0, stats.get_max_health() * 0.05)
	stats.set_current_health(stats.get_current_health() - cost, false)
	return true
