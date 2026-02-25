# dikenli_kalkan.gd
# UNCOMMON - Yediğin hasarı saldırgana yansıtır (blok yapmasan da çalışır)

extends ItemEffect

func _init():
	item_id = "dikenli_kalkan"
	item_name = "Dikenli Kalkan"
	description = "Yediğin hasar saldırgana yansır (blok şart değil)"
	flavor_text = "Dikenli savunma"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.BLOCK
	affected_stats = ["damage_reflect"]

var _player: CharacterBody2D = null

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	if player.has_signal("player_took_damage"):
		if not player.is_connected("player_took_damage", _on_player_took_damage):
			player.connect("player_took_damage", _on_player_took_damage)
		print("[Dikenli Kalkan] ✅ Yediğin hasar saldırgana yansır")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player and _player.has_signal("player_took_damage"):
		if _player.is_connected("player_took_damage", _on_player_took_damage):
			_player.disconnect("player_took_damage", _on_player_took_damage)
	_player = null
	print("[Dikenli Kalkan] ❌ Kaldırıldı")

func _on_player_took_damage(amount: float, attacker: Node2D):
	if amount <= 0 or not is_instance_valid(attacker):
		return
	if attacker.has_method("take_damage"):
		attacker.take_damage(amount, 0.0, 0.0, false)  # Knockback yok, sadece hasar
