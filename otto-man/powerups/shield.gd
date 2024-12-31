extends Resource

@export var rarity: int = 0  # Common by default
@export var block_amount: int = 20  # Amount of damage the shield can block

func _init():
	pass

func apply_to_player(player: Node) -> void:
	if !player:
		return
	
	print("[Shield] Applying shield with block amount: ", block_amount)
	player.enable_shield(15.0)  # 15 second cooldown

func get_description() -> String:
	return "Blocks %d damage from a single hit\nRecharges after each enemy kill\n[%s]" % [block_amount, get_rarity_name()]

func get_rarity_name() -> String:
	match rarity:
		0: return "Common"
		1: return "Rare"
		2: return "Epic"
		3: return "Legendary"
		_: return "Unknown" 