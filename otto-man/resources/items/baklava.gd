# baklava.gd
# COMMON item - Stamina +1

extends ItemEffect

var _applied: bool = false

func _init():
	item_id = "baklava"
	item_name = tr("item.baklava.name")
	description = tr("item.baklava.description")
	flavor_text = "Tatlı ama ağır değil, sadece enerji verir"
	category = ItemCategory.STAMINA
	affected_stats = ["stamina_charges"]

func activate(player: CharacterBody2D):
	super.activate(player)
	
	# +1 stamina: doğrudan PlayerStats'a yazılır. Eskiden stamina bar grubundan geçiyordu; run sonunda
	# sahne değişirken bar ağaçta yoksa geri alma atlanıyor ve +1 kalıcı sızıyordu.
	if player_stats and not _applied:
		player_stats.add_stat_bonus("block_charges", 1.0)
		_applied = true

func deactivate(player: CharacterBody2D):
	super.deactivate(player)

	if player_stats and _applied:
		player_stats.add_stat_bonus("block_charges", -1.0)
		_applied = false
