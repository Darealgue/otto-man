# yansiyan_irade.gd
# LEGENDARY - Perfect parry başarılı olunca 1 tam stamina segmenti iade edilir.

extends ItemEffect

const REFUND_AMOUNT := 1.0

func _init():
	item_id = "yansiyan_irade"
	item_name = tr("item.yansiyan_irade.name")
	description = tr("item.yansiyan_irade.description")
	flavor_text = "İrade kırılmaz, yansır"
	rarity = ItemRarity.LEGENDARY
	category = ItemCategory.PARRY
	affected_stats = ["parry_stamina_refund"]

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Yansıyan İrade] ✅ Perfect parry stamina iade eder")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Yansıyan İrade] ❌ Kaldırıldı")

func _on_perfect_parry() -> void:
	var stamina_bar = get_tree().get_first_node_in_group("stamina_bar")
	if stamina_bar and stamina_bar.has_method("restore_partial_charge"):
		stamina_bar.restore_partial_charge(REFUND_AMOUNT)
