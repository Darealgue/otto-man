# baklava.gd
# COMMON item - Stamina +1

extends ItemEffect

func _init():
	item_id = "baklava"
	item_name = "Baklava"
	description = "+1 Stamina Bar"
	flavor_text = "Tatlı ama ağır değil, sadece enerji verir"
	rarity = ItemRarity.COMMON
	category = ItemCategory.STAMINA
	affected_stats = ["stamina_charges"]

func activate(player: CharacterBody2D):
	super.activate(player)
	
	# Add +1 stamina charge
	if player_stats:
		# Get stamina bar and add charge
		var stamina_bar = get_tree().get_first_node_in_group("stamina_bar")
		if stamina_bar and stamina_bar.has_method("add_max_charge"):
			stamina_bar.add_max_charge(1)
			print("[Baklava] ✅ +1 Stamina added")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	
	# Remove stamina charge
	var stamina_bar = get_tree().get_first_node_in_group("stamina_bar")
	if stamina_bar and stamina_bar.has_method("remove_max_charge"):
		stamina_bar.remove_max_charge(1)
		print("[Baklava] ❌ Stamina removed")
