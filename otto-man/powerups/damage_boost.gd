extends Resource

@export var rarity: int = 0  # Common by default
@export var damage_amount: int = 5  # Base damage boost amount

func _init():
	pass

func apply_to_player(player: Node) -> void:
	if !player:
		return
	
	var boost_amount = damage_amount
	match rarity:
		0:  # Common
			boost_amount = 5
		1:  # Rare
			boost_amount = 10
		2:  # Epic
			boost_amount = 15
		3:  # Legendary
			boost_amount = 20
	
	print("[Damage Boost] Applied +", boost_amount, " damage [", get_rarity_name(), "]")
	player.modify_damage(boost_amount)

func get_description() -> String:
	var boost_amount = damage_amount
	match rarity:
		0:  # Common
			boost_amount = 5
		1:  # Rare
			boost_amount = 10
		2:  # Epic
			boost_amount = 15
		3:  # Legendary
			boost_amount = 20
	
	return "+%d damage\n[%s]" % [boost_amount, get_rarity_name()]

func get_rarity_name() -> String:
	match rarity:
		0: return "Common"
		1: return "Rare"
		2: return "Epic"
		3: return "Legendary"
		_: return "Unknown" 