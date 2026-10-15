# kesintisiz_zincir.gd
# RARE - Artan Güç'ün streak penceresini 2 katına çıkarır (kontrol artan_guc.gd
# içinde `_get_streak_timeout()`) — art arda vurman daha kolay hale gelir,
# zincir daha zor kırılır. Artan Güç olmadan tek başına etkisi yok, ikisi
# birlikte alınmak üzere tasarlandı (bkz. docs/ITEM_PIPELINE_DESIGN.md §2.1).

extends ItemEffect

func _init():
	item_id = "kesintisiz_zincir"
	item_name = tr("item.kesintisiz_zincir.name")
	description = tr("item.kesintisiz_zincir.description")
	flavor_text = "Zincir hiç kopmaz"
	category = ItemCategory.LIGHT_ATTACK
	affected_stats = ["light_attack_streak_window"]

func activate(player: CharacterBody2D):
	super.activate(player)

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
