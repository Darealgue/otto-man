# parry_ruhu.gd
# UNCOMMON item - Perfect parry sonrası stamina restore +1

extends ItemEffect

func _init():
	item_id = "parry_ruhu"
	item_name = "Parry Ruhu"
	description = "Perfect parry sonrası stamina restore +1"
	flavor_text = "Parry ile enerji"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.PARRY
	affected_stats = ["stamina_restore"]

var _player: CharacterBody2D = null

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	# Connect to perfect_parry signal
	if player.has_signal("perfect_parry"):
		if not player.is_connected("perfect_parry", _on_perfect_parry):
			player.connect("perfect_parry", _on_perfect_parry)
		print("[Parry Ruhu] ✅ Perfect parry sonrası stamina restore +1")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	# Disconnect signal
	if _player and _player.has_signal("perfect_parry"):
		if _player.is_connected("perfect_parry", _on_perfect_parry):
			_player.disconnect("perfect_parry", _on_perfect_parry)
	_player = null
	print("[Parry Ruhu] ❌ Parry Ruhu kaldırıldı")

func _on_perfect_parry():
	if not _player:
		return
	
	# Restore 1 stamina charge
	var stamina_bar = get_tree().get_first_node_in_group("stamina_bar")
	if stamina_bar:
		# Use restore_partial_charge with 1.0 to restore a full charge
		stamina_bar.restore_partial_charge(1.0)
		print("[Parry Ruhu] Stamina restore +1")
