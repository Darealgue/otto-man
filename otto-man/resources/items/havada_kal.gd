# havada_kal.gd
# UNCOMMON - Zıplama sonrası jump basılı tutunca havada süzülürsün (glide)

extends ItemEffect

var _player: CharacterBody2D = null

func _init():
	item_id = "havada_kal"
	item_name = "Havada Kal"
	description = "Jump basılı tutunca düşerken süzülürsün"
	flavor_text = "Havada süzülme"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.JUMP
	affected_stats = ["glide"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	print("[Havada Kal] ✅ Süzülme aktif")

func deactivate(_p: CharacterBody2D):
	super.deactivate(_p)
	_player = null
	print("[Havada Kal] ❌ Kaldırıldı")
