# parry_zirhi.gd
# UNCOMMON - Doğru zamanlı parry, canının önünde hasar emen bir kalkan verir (+10, en fazla 30).
# Kalkan player.guard_shield üzerinde tutulur, take_damage içinde canından önce harcanır.

extends ItemEffect

const SHIELD_PER_PARRY := 10.0
const SHIELD_CAP := 30.0

var _player: CharacterBody2D = null

func _init():
	item_id = "parry_zirhi"
	item_name = tr("item.parry_zirhi.name")
	description = tr("item.parry_zirhi.description")
	flavor_text = "Her parry bir zırh katmanı"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.PARRY
	affected_stats = ["parry_shield"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	print("[Parry Zırhı] ✅ Parry kalkan veriyor (+%d, max %d)" % [int(SHIELD_PER_PARRY), int(SHIELD_CAP)])

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	# guard_shield, Taşan Kaynak ile ortak havuz; sıfırlamıyoruz (çeşme fazlalığı silinmesin).
	_player = null
	print("[Parry Zırhı] ❌ Kaldırıldı")

# ItemManager perfect_parry sinyalini bu metoda otomatik bağlar
func _on_perfect_parry() -> void:
	if is_instance_valid(_player) and _player.has_method("add_guard_shield"):
		_player.add_guard_shield(SHIELD_PER_PARRY, SHIELD_CAP)
