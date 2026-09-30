# cellat_nefesi.gd
# LEGENDARY - Zamanla pasif stamina yenilenmesi tamamen durur; bunun yerine her
# isabetli saldırı (hedef sayısından bağımsız, saldırı başına 1 kez) stamina'nın
# %25'ini geri kazandırır. Zamanlı regen'in durdurulması ui/stamina_bar.gd
# _process() içinde bu item_id'ye özel bir guard ile yapılır (bkz. o dosya).

extends ItemEffect

const ATTACK_REFUND_AMOUNT := 0.25

func _init():
	item_id = "cellat_nefesi"
	item_name = tr("item.cellat_nefesi.name")
	description = tr("item.cellat_nefesi.description")
	flavor_text = "Durursan, nefesin de durur"
	rarity = ItemRarity.LEGENDARY
	category = ItemCategory.STAMINA
	affected_stats = ["stamina_passive_regen", "stamina_attack_refund"]

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Cellat Nefesi] ✅ Pasif stamina yenilenmesi durdu, isabetli vuruş besliyor")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Cellat Nefesi] ❌ Kaldırıldı")

func _on_player_attack_landed(_attack_type: String, _damage: float, _targets: Array, _position: Vector2, _effect_filter: String = "all") -> void:
	var stamina_bar = get_tree().get_first_node_in_group("stamina_bar")
	if stamina_bar and stamina_bar.has_method("restore_partial_charge"):
		stamina_bar.restore_partial_charge(ATTACK_REFUND_AMOUNT)
