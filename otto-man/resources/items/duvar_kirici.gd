# duvar_kirici.gd
# COMMON - Duvardan zıplarken (wall jump) 90px içindeki düşmanlara hafif hasar
# + fırlatma verir. Davranış wall_slide_state.gd'nin _perform_wall_jump()'ında
# ItemManager.apply_wall_jump_burst() çağrılarak kontrol edilir — bu item
# pasif bir işarettir.

extends ItemEffect

func _init():
	item_id = "duvar_kirici"
	item_name = tr("item.duvar_kirici.name")
	description = tr("item.duvar_kirici.description")
	flavor_text = "Duvarı iterken düşmanı da iter"
	category = ItemCategory.WALL_SLIDE
	affected_stats = ["wall_jump_burst"]

func activate(player: CharacterBody2D):
	super.activate(player)

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
