# UNCOMMON - Her düşman öldürüşünde yarım stamina hücresi geri gelir
extends ItemEffect

const RESTORE_AMOUNT := 0.5

func _init():
	item_id = "ruh_akisi"
	item_name = "Ruh Akışı"
	description = "Her düşman öldürüşünde yarım stamina hücresi geri gelir"
	flavor_text = "Düşen her can, sana nefes olur"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.STAMINA
	affected_stats = ["on_kill_stamina"]

func on_enemy_killed(_enemy: Node2D) -> void:
	var bar = get_tree().get_first_node_in_group("stamina_bar")
	if bar and bar.has_method("restore_partial_charge"):
		bar.restore_partial_charge(RESTORE_AMOUNT)
