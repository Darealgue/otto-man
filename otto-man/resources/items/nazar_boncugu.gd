# nazar_boncugu.gd
# RARE - 10 saniyede bir yenilenen kalkan; ilk gelen hasarı tamamen bloklar.

extends ItemEffect

const COOLDOWN := 10.0

var _player: CharacterBody2D = null
var _cooldown_timer: float = 0.0

func _init():
	item_id = "nazar_boncugu"
	item_name = "Nazar Boncuğu"
	description = "10 saniyede bir yenilenen kalkan. İlk gelen hasarı tamamen durdurur."
	flavor_text = "Kötü nazara karşı"
	rarity = ItemRarity.RARE
	category = ItemCategory.BLOCK
	affected_stats = ["nazar_shield"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_player.nazar_shield_active = true
	if player.has_signal("nazar_shield_consumed"):
		if not player.is_connected("nazar_shield_consumed", _on_nazar_shield_consumed):
			player.connect("nazar_shield_consumed", _on_nazar_shield_consumed)
	print("[Nazar Boncuğu] Kalkan aktif, 10 sn cooldown")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player:
		_player.nazar_shield_active = false
		if _player.has_signal("nazar_shield_consumed") and _player.is_connected("nazar_shield_consumed", _on_nazar_shield_consumed):
			_player.disconnect("nazar_shield_consumed", _on_nazar_shield_consumed)
	_player = null
	_cooldown_timer = 0.0

func _on_nazar_shield_consumed():
	_cooldown_timer = COOLDOWN

func process(player: CharacterBody2D, delta: float) -> void:
	if _cooldown_timer <= 0:
		return
	_cooldown_timer -= delta
	if _cooldown_timer <= 0 and _player and is_instance_valid(_player):
		_player.nazar_shield_active = true
