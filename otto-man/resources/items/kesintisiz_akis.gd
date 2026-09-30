# kesintisiz_akis.gd
# LEGENDARY - Dodge veya dash sırasında bir düşman ölürse, harcanan stamina segmenti anında iade edilir.
# Ön koşul: zehirli_sekme (item_manager.gd ITEM_REQUIREMENTS).

extends ItemEffect

const REFUND_AMOUNT := 1.0
const MOVING_STATE_NAMES := ["Dodge", "Dash"]

var _player: CharacterBody2D = null

func _init():
	item_id = "kesintisiz_akis"
	item_name = tr("item.kesintisiz_akis.name")
	description = tr("item.kesintisiz_akis.description")
	flavor_text = "Akış hiç durmaz"
	rarity = ItemRarity.LEGENDARY
	category = ItemCategory.DODGE
	affected_stats = ["dodge_kill_stamina_refund"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	print("[Kesintisiz Akış] ✅ Dodge/dash sırasında öldürme stamina iade eder")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null
	print("[Kesintisiz Akış] ❌ Kaldırıldı")

func on_enemy_killed(_enemy: Node2D) -> void:
	if not is_instance_valid(_player):
		return
	var sm = _player.get("state_machine")
	if sm == null or sm.current_state == null:
		return
	if not MOVING_STATE_NAMES.has(String(sm.current_state.name)):
		return
	var stamina_bar = get_tree().get_first_node_in_group("stamina_bar")
	if stamina_bar and stamina_bar.has_method("restore_partial_charge"):
		stamina_bar.restore_partial_charge(REFUND_AMOUNT)
