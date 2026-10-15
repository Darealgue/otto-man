# ruzgar_toplama.gd
# UNCOMMON - Her ayrı parkur eylemi (duvar zıplama, kenar tutunma, slide,
# çift zıplama) küçük bir kesirli stamina şarjı iade eder. Davranış
# wall_slide_state.gd / ledge_grab_state.gd / slide_state.gd /
# jump_state.gd içinde ItemManager.apply_parkour_momentum_tick() çağrılarak
# kontrol edilir — bu item pasif bir işarettir.

extends ItemEffect

func _init():
	item_id = "ruzgar_toplama"
	item_name = tr("item.ruzgar_toplama.name")
	description = tr("item.ruzgar_toplama.description")
	flavor_text = "Durmadan hareket eden asla yorulmaz"
	category = ItemCategory.SPECIAL
	affected_stats = ["parkour_momentum"]

func activate(player: CharacterBody2D):
	super.activate(player)

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
