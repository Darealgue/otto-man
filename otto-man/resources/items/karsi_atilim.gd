# karsi_atilim.gd
# UNCOMMON - Parry sonrası 4 saniye içindeki ilk dodge/dash bedavadır (stamina harcamaz)
# ve 2 kat uzağa gider. Tüketimi dodge_state / dash_state yapar (player.consume_counter_dash).

extends ItemEffect

const WINDOW_MSEC := 4000

var _player: CharacterBody2D = null

func _init():
	item_id = "karsi_atilim"
	item_name = tr("item.karsi_atilim.name")
	description = tr("item.karsi_atilim.description")
	flavor_text = "Parry'den sonra yol açılır"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.PARRY
	affected_stats = ["counter_dash"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	print("[Karşı Atılım] ✅ Parry sonrası ilk atılım bedava ve 2x uzun")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if is_instance_valid(player):
		player.counter_dash_until_msec = 0
	_player = null
	print("[Karşı Atılım] ❌ Kaldırıldı")

func _on_perfect_parry() -> void:
	if is_instance_valid(_player):
		_player.counter_dash_until_msec = Time.get_ticks_msec() + WINDOW_MSEC
