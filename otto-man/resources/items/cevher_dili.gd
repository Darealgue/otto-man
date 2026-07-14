# LEGENDARY - Hafif saldırılar staminayla güçlü elemental patlamalara dönüşür
# Her saldırı yarım stamina hücresi yer; stamina yoksa saldırı sıradan kalır.
extends ItemEffect

const AOE_RADIUS := 60.0
const DAMAGE_MULT := 2.5  # Ana hedefe ek çarpan
const STAMINA_COST := 0.5

var _player: CharacterBody2D = null

func _init():
	item_id = "cevher_dili"
	item_name = "Cevher Dili"
	description = "Hafif saldırılar staminayla elemental patlamaya dönüşür (×2.5 + alan hasarı)"
	flavor_text = "Güç, nefesin bedelidir"
	rarity = ItemRarity.LEGENDARY
	category = ItemCategory.STAMINA
	affected_stats = ["stamina_powered_attack"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	print("[Cevher Dili] ✅ Hafif saldırılar stamina ile güçleniyor")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null
	print("[Cevher Dili] ❌ Kaldırıldı")

func _on_player_attack_landed(attack_type: String, damage: float, _targets: Array, position: Vector2, effect_filter: String = "all") -> void:
	if attack_type != "normal" or effect_filter == "physical_only":
		return  # Sadece hafif saldırı; Karagöz'ün fiziksel-only aynası bunu tekrar tetiklemesin
	if not is_instance_valid(_player):
		return
	var stamina_bar: Node = _player.get_tree().get_first_node_in_group("stamina_bar")
	var consumed := false
	if stamina_bar and stamina_bar.has_method("use_partial_charge"):
		consumed = stamina_bar.use_partial_charge(STAMINA_COST)
	if not consumed:
		consumed = _try_kan_bedeli_fallback()
	if not consumed:
		return  # Stamina/can yok, saldırı zaten normal şekilde vurdu
	var extra_damage := damage * (DAMAGE_MULT - 1.0)
	var tree = _player.get_tree()
	if not tree:
		return
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		if position.distance_to(node.global_position) <= AOE_RADIUS and node.has_method("take_damage"):
			node.take_damage(extra_damage, 0.0, 0.0, false)

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
